package com.dancepractice.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.dancepractice.TestApi;
import com.dancepractice.TestcontainersConfiguration;
import com.dancepractice.room.RoomDto;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import org.hamcrest.Matchers;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;

/** Rooms listing, account deletion and the API docs. */
@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class AccountTests {

    private static final Instant T0 = Instant.parse("2026-10-01T10:00:00Z");

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Autowired
    private JdbcTemplate jdbc;

    private TestApi api;

    @BeforeEach
    void setUp() {
        api = new TestApi(mvc, json);
    }

    @Test
    void roomsListHidesDeletedRoomsAndIsNewestFirst() throws Exception {
        String token = api.registerUser();
        RoomDto older = TestApi.room("Older", T0);
        RoomDto newer = TestApi.room("Newer", T0.plusSeconds(60));
        RoomDto gone = TestApi.room("Gone", T0);
        RoomDto goneTombstone = new RoomDto(gone.id(), gone.name(), null, null, null, gone.videoFileName(),
                T0, null, T0.plusSeconds(5), T0.plusSeconds(5));
        api.sync(token, 0, List.of(older, newer, goneTombstone), List.of());

        mvc.perform(get("/api/rooms").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[*].name", Matchers.contains("Newer", "Older")));
    }

    @Test
    void deletingTheAccountRemovesAllCloudData() throws Exception {
        String email = TestApi.uniqueEmail();
        Map<String, Object> tokens = api.register(email);
        String token = (String) tokens.get("accessToken");
        RoomDto room = TestApi.room("Magnetic", T0);
        api.sync(token, 0, List.of(room), List.of(TestApi.session(room, T0, 60)));

        mvc.perform(delete("/api/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isNoContent());

        mvc.perform(get("/api/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isNotFound());
        mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("email", email, "password", TestApi.PASSWORD))))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                        .content(json.writeValueAsString(Map.of("refreshToken", tokens.get("refreshToken")))))
                .andExpect(status().isUnauthorized());
        assertThat(jdbc.queryForObject(
                "SELECT count(*) FROM practice_rooms WHERE id = ?", Integer.class, room.id())).isZero();
    }

    @Test
    void apiDocsArePublic() throws Exception {
        mvc.perform(get("/v3/api-docs"))
                .andExpect(status().isOk())
                .andExpect(content().string(Matchers.containsString("/api/sync")));
    }
}
