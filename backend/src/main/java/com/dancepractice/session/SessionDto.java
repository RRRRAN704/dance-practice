package com.dancepractice.session;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/**
 * One logged stretch of practice.
 *
 * @param roomId   null once the room is gone; roomName and genre are snapshots taken when logged
 */
public record SessionDto(
        @NotNull UUID id,
        UUID roomId,
        @NotBlank @Size(max = 200) String roomName,
        @Size(max = 50) String genre,
        @NotNull Instant startedAt,
        @PositiveOrZero double durationSeconds) {

    public static SessionDto from(PracticeSession session) {
        return new SessionDto(session.getId(), session.getRoomId(), session.getRoomName(), session.getGenre(),
                session.getStartedAt(), session.getDurationSeconds());
    }
}
