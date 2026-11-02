package com.dancepractice.sync;

import com.dancepractice.common.NotFoundException;
import com.dancepractice.room.PracticeRoom;
import com.dancepractice.room.PracticeRoomRepository;
import com.dancepractice.room.RoomDto;
import com.dancepractice.session.PracticeSession;
import com.dancepractice.session.PracticeSessionRepository;
import com.dancepractice.session.SessionDto;
import com.dancepractice.user.UserRepository;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * One round trip that pushes a device's local changes and pulls everything it hasn't seen.
 *
 * <p>Cursor safety: change numbers come from one sequence, but transactions can commit out of
 * order, so a device could read number 11 before number 10 commits and then skip 10 forever. Each
 * sync therefore locks the user's row first, which runs one user's syncs one at a time; other
 * users are unaffected.
 */
@Service
public class SyncService {

    /** Sequence values start at 1, so this never matches a real write. */
    private static final long NO_WRITES = -1;

    private final UserRepository users;
    private final PracticeRoomRepository rooms;
    private final PracticeSessionRepository sessions;
    private final JdbcTemplate jdbc;

    SyncService(UserRepository users, PracticeRoomRepository rooms, PracticeSessionRepository sessions,
            JdbcTemplate jdbc) {
        this.users = users;
        this.rooms = rooms;
        this.sessions = sessions;
        this.jdbc = jdbc;
    }

    @Transactional
    public SyncResponse sync(UUID userId, SyncRequest request) {
        users.lockById(userId).orElseThrow(() -> new NotFoundException("User no longer exists"));

        // One number for everything this request writes, taken only if something is written.
        long writeSeq = request.rooms().isEmpty() && request.sessions().isEmpty() ? NO_WRITES : nextChangeSeq();

        List<PracticeRoom> lostConflicts = pushRooms(userId, request.rooms(), writeSeq);
        pushSessions(userId, request.sessions(), writeSeq);

        // Rows written by this request are left out: the device already has them.
        List<PracticeRoom> changedRooms = rooms.findChanges(userId, request.cursor(), writeSeq);
        List<PracticeSession> changedSessions = sessions.findChanges(userId, request.cursor(), writeSeq);

        Map<UUID, RoomDto> roomsOut = new LinkedHashMap<>();
        changedRooms.forEach(room -> roomsOut.put(room.getId(), RoomDto.from(room)));
        lostConflicts.forEach(room -> roomsOut.putIfAbsent(room.getId(), RoomDto.from(room)));

        long cursor = Math.max(request.cursor(), writeSeq);
        for (PracticeRoom room : changedRooms) {
            cursor = Math.max(cursor, room.getChangeSeq());
        }
        for (PracticeSession session : changedSessions) {
            cursor = Math.max(cursor, session.getChangeSeq());
        }

        return new SyncResponse(
                cursor,
                List.copyOf(roomsOut.values()),
                changedSessions.stream().map(SessionDto::from).toList());
    }

    /** @return the server's rows for pushed rooms that lost a conflict */
    private List<PracticeRoom> pushRooms(UUID userId, List<RoomDto> incoming, long writeSeq) {
        Map<UUID, PracticeRoom> existing = findOwned(userId, rooms.findAllById(ids(incoming, RoomDto::id)),
                PracticeRoom::getId, PracticeRoom::getUserId);

        List<PracticeRoom> lost = new ArrayList<>();
        for (RoomDto dto : incoming) {
            PracticeRoom room = existing.get(dto.id());
            if (room == null) {
                room = rooms.save(new PracticeRoom(userId, dto, writeSeq));
                existing.put(room.getId(), room);
            } else if (!room.merge(dto, writeSeq)) {
                lost.add(room);
            }
        }
        return lost;
    }

    private void pushSessions(UUID userId, List<SessionDto> incoming, long writeSeq) {
        Set<UUID> stored = new HashSet<>(findOwned(userId, sessions.findAllById(ids(incoming, SessionDto::id)),
                PracticeSession::getId, PracticeSession::getUserId).keySet());
        // A session pointing at a room this user doesn't own is kept, just unlinked.
        Set<UUID> ownRoomIds = rooms.findAllById(ids(incoming, SessionDto::roomId)).stream()
                .filter(room -> room.getUserId().equals(userId))
                .map(PracticeRoom::getId)
                .collect(Collectors.toSet());

        for (SessionDto dto : incoming) {
            // Sessions never change, so a repeat (e.g. a retried request) is simply skipped.
            if (stored.add(dto.id())) {
                UUID roomId = ownRoomIds.contains(dto.roomId()) ? dto.roomId() : null;
                sessions.save(new PracticeSession(userId, dto, roomId, writeSeq));
            }
        }
    }

    /** Indexes rows by id, refusing ids that belong to someone else. */
    private static <T> Map<UUID, T> findOwned(UUID userId, List<T> found, Function<T, UUID> id,
            Function<T, UUID> owner) {
        Map<UUID, T> owned = new LinkedHashMap<>();
        for (T row : found) {
            if (!owner.apply(row).equals(userId)) {
                throw new IdConflictException(id.apply(row));
            }
            owned.put(id.apply(row), row);
        }
        return owned;
    }

    private static <T> Set<UUID> ids(List<T> rows, Function<T, UUID> id) {
        return rows.stream().map(id).filter(Objects::nonNull).collect(Collectors.toSet());
    }

    private long nextChangeSeq() {
        return jdbc.queryForObject("SELECT nextval('sync_change_seq')", Long.class);
    }
}
