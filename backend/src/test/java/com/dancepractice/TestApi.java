package com.dancepractice;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.dancepractice.room.RoomDto;
import com.dancepractice.session.SessionDto;
import com.dancepractice.sync.SyncRequest;
import com.dancepractice.sync.SyncResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** Shared request helpers for the integration tests. */
public record TestApi(MockMvc mvc, ObjectMapper json) {

    public static final String PASSWORD = "correct-horse";

    /** Signs up a fresh user and returns the response body (tokens). */
    public Map<String, Object> register(String email) throws Exception {
        String body = mvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", email, "password", PASSWORD))))
                .andExpect(status().isCreated())
                .andReturn().getResponse().getContentAsString();
        return json.readValue(body, Map.class);
    }

    /** Signs up a fresh user and returns their access token. */
    public String registerUser() throws Exception {
        return (String) register(uniqueEmail()).get("accessToken");
    }

    public ResultActions postSync(String accessToken, SyncRequest request) throws Exception {
        return mvc.perform(post("/api/sync")
                .header("Authorization", "Bearer " + accessToken)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(request)));
    }

    public SyncResponse sync(String accessToken, long cursor, List<RoomDto> rooms, List<SessionDto> sessions)
            throws Exception {
        String body = postSync(accessToken, new SyncRequest(cursor, rooms, sessions))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return json.readValue(body, SyncResponse.class);
    }

    public static String uniqueEmail() {
        return "dancer-" + UUID.randomUUID() + "@example.com";
    }

    public static RoomDto room(String name, Instant at) {
        return new RoomDto(UUID.randomUUID(), name, "IVE", "kpop", null, UUID.randomUUID() + ".mov", at, null, at,
                null);
    }

    public static SessionDto session(RoomDto room, Instant startedAt, double seconds) {
        return new SessionDto(UUID.randomUUID(), room.id(), room.name(), room.genre(), startedAt, seconds);
    }
}
