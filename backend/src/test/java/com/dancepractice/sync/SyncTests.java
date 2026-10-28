package com.dancepractice.sync;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.dancepractice.TestcontainersConfiguration;
import com.dancepractice.room.RoomDto;
import com.dancepractice.session.SessionDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class SyncTests {

    private static final Instant T0 = Instant.parse("2026-10-01T10:00:00Z");

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    private String token;

    @BeforeEach
    void signUp() throws Exception {
        token = registerUser();
    }

    @Test
    void anotherDevicePullsWhatTheFirstPushed() throws Exception {
        RoomDto room = room("Magnetic", T0);
        SessionDto session = session(room, T0.plusSeconds(60));

        SyncResponse phone = sync(token, 0, List.of(room), List.of(session));
        assertThat(phone.cursor()).isPositive();
        assertThat(phone.rooms()).as("no echo of the device's own writes").isEmpty();
        assertThat(phone.sessions()).isEmpty();

        SyncResponse ipad = sync(token, 0, List.of(), List.of());
        assertThat(ipad.rooms()).containsExactly(room);
        assertThat(ipad.sessions()).containsExactly(session);
        assertThat(ipad.cursor()).isEqualTo(phone.cursor());
    }

    @Test
    void nothingNewAfterTheCursor() throws Exception {
        long cursor = sync(token, 0, List.of(room("Magnetic", T0)), List.of()).cursor();

        SyncResponse again = sync(token, cursor, List.of(), List.of());

        assertThat(again.rooms()).isEmpty();
        assertThat(again.sessions()).isEmpty();
        assertThat(again.cursor()).isEqualTo(cursor);
    }

    @Test
    void newerEditWinsAndReachesTheOtherDevice() throws Exception {
        RoomDto original = room("Magnetic", T0);
        long phoneCursor = sync(token, 0, List.of(original), List.of()).cursor();

        RoomDto renamed = withName(original, "Magnetic (chorus)", T0.plusSeconds(300));
        sync(token, 0, List.of(renamed), List.of());

        assertThat(sync(token, phoneCursor, List.of(), List.of()).rooms()).containsExactly(renamed);
    }

    @Test
    void olderEditLosesAndTheServerVersionComesBack() throws Exception {
        RoomDto original = room("Magnetic", T0);
        RoomDto newer = withName(original, "Newer name", T0.plusSeconds(300));
        long cursor = sync(token, 0, List.of(original), List.of()).cursor();
        sync(token, cursor, List.of(newer), List.of());

        // A device that edited before the newer edit, and has already seen the cursor.
        RoomDto stale = withName(original, "Stale name", T0.plusSeconds(100));
        SyncResponse response = sync(token, cursor, List.of(stale), List.of());

        assertThat(response.rooms()).containsExactly(newer);
    }

    @Test
    void deletionIsFinal() throws Exception {
        RoomDto room = room("Magnetic", T0);
        sync(token, 0, List.of(room), List.of());
        RoomDto tombstone = deleted(room, T0.plusSeconds(100));
        long cursor = sync(token, 0, List.of(tombstone), List.of()).cursor();

        // Another device edits its stale copy later than the deletion happened.
        RoomDto lateEdit = withName(room, "Edited offline", T0.plusSeconds(500));
        SyncResponse response = sync(token, cursor, List.of(lateEdit), List.of());

        assertThat(response.rooms()).containsExactly(tombstone);
    }

    @Test
    void retryingTheSamePushIsHarmless() throws Exception {
        RoomDto room = room("Magnetic", T0);
        SessionDto session = session(room, T0);

        sync(token, 0, List.of(room), List.of(session));
        sync(token, 0, List.of(room), List.of(session));

        SyncResponse fresh = sync(token, 0, List.of(), List.of());
        assertThat(fresh.rooms()).hasSize(1);
        assertThat(fresh.sessions()).hasSize(1);
    }

    @Test
    void usersNeverSeeEachOthersData() throws Exception {
        RoomDto room = room("Magnetic", T0);
        sync(token, 0, List.of(room), List.of(session(room, T0)));

        String otherUser = registerUser();
        SyncResponse response = sync(otherUser, 0, List.of(), List.of());

        assertThat(response.rooms()).isEmpty();
        assertThat(response.sessions()).isEmpty();
    }

    @Test
    void cannotOverwriteAnotherUsersRoom() throws Exception {
        RoomDto room = room("Magnetic", T0);
        sync(token, 0, List.of(room), List.of());

        String attacker = registerUser();
        perform(attacker, new SyncRequest(0, List.of(withName(room, "Hacked", T0.plusSeconds(999))), List.of()))
                .andExpect(status().isConflict());

        assertThat(sync(token, 0, List.of(), List.of()).rooms()).containsExactly(room);
    }

    @Test
    void sessionOfAnUnknownRoomIsKeptUnlinked() throws Exception {
        SessionDto orphan = new SessionDto(UUID.randomUUID(), UUID.randomUUID(), "Deleted song", "jazz", T0, 120);
        sync(token, 0, List.of(), List.of(orphan));

        SessionDto stored = sync(token, 0, List.of(), List.of()).sessions().get(0);

        assertThat(stored.roomId()).isNull();
        assertThat(stored.roomName()).isEqualTo("Deleted song");
    }

    @Test
    void invalidRoomIsRejected() throws Exception {
        RoomDto blankName = new RoomDto(UUID.randomUUID(), " ", null, null, null, "v.mov", T0, null, T0, null);

        perform(token, new SyncRequest(0, List.of(blankName), List.of()))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors['rooms[0].name']").exists());
    }

    @Test
    void requiresLogin() throws Exception {
        mvc.perform(post("/api/sync").contentType(MediaType.APPLICATION_JSON).content("{\"cursor\":0}"))
                .andExpect(status().isUnauthorized());
    }

    // --- helpers ---

    private SyncResponse sync(String accessToken, long cursor, List<RoomDto> rooms, List<SessionDto> sessions)
            throws Exception {
        String body = perform(accessToken, new SyncRequest(cursor, rooms, sessions))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return json.readValue(body, SyncResponse.class);
    }

    private ResultActions perform(String accessToken, SyncRequest request) throws Exception {
        return mvc.perform(post("/api/sync")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(request)));
    }

    private String registerUser() throws Exception {
        String body = mvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of(
                                "email", "dancer-" + UUID.randomUUID() + "@example.com",
                                "password", "correct-horse"))))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readTree(body).get("accessToken").asText();
    }

    private static RoomDto room(String name, Instant at) {
        return new RoomDto(UUID.randomUUID(), name, "IVE", "kpop", null, UUID.randomUUID() + ".mov", at, null, at,
                null);
    }

    private static RoomDto withName(RoomDto room, String name, Instant updatedAt) {
        return new RoomDto(room.id(), name, room.artist(), room.genre(), room.note(), room.videoFileName(),
                room.createdAt(), room.lastOpenedAt(), updatedAt, room.deletedAt());
    }

    private static RoomDto deleted(RoomDto room, Instant at) {
        return new RoomDto(room.id(), room.name(), room.artist(), room.genre(), room.note(), room.videoFileName(),
                room.createdAt(), room.lastOpenedAt(), at, at);
    }

    private static SessionDto session(RoomDto room, Instant startedAt) {
        return new SessionDto(UUID.randomUUID(), room.id(), room.name(), room.genre(), startedAt, 95.5);
    }
}
