package com.dancepractice.stats;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.dancepractice.TestApi;
import com.dancepractice.TestcontainersConfiguration;
import com.dancepractice.room.RoomDto;
import com.dancepractice.session.SessionDto;
import com.dancepractice.stats.StatsSummary.GenreTotal;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.bean.override.convention.TestBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class StatsTests {

    /**
     * Wednesday 16 Jan 2030, noon in London (UTC in winter). It lies in the future so the access
     * tokens issued with this clock are still unexpired by the real clock that validates them.
     */
    private static final Instant NOW = Instant.parse("2030-01-16T12:00:00Z");

    @TestBean
    private Clock clock;

    static Clock clock() {
        return Clock.fixed(NOW, ZoneOffset.UTC);
    }

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    private TestApi api;
    private String token;

    @BeforeEach
    void signUp() throws Exception {
        api = new TestApi(mvc, json);
        token = api.registerUser();
    }

    @Test
    void summarisesTotalsStreaksAndGenres() throws Exception {
        RoomDto kpop = room("kpop");
        RoomDto jazz = room("jazz");
        RoomDto hiphop = room("hiphop");
        RoomDto untagged = room(null);
        List<SessionDto> sessions = new ArrayList<>(List.of(
                TestApi.session(kpop, at("2030-01-16T10:00:00Z"), 600),    // today (Wed)
                TestApi.session(kpop, at("2030-01-15T10:00:00Z"), 300),    // Tue
                TestApi.session(jazz, at("2030-01-14T10:00:00Z"), 200),    // Mon, week starts
                // Sunday the 13th has no practice: the streak breaks
                TestApi.session(hiphop, at("2029-12-31T10:00:00Z"), 500))); // last month
        for (int day = 9; day <= 12; day++) {                                // a 4-day run
            sessions.add(TestApi.session(untagged, at("2030-01-%02dT10:00:00Z".formatted(day)), 100));
        }
        api.sync(token, 0, List.of(kpop, jazz, hiphop, untagged), sessions);

        StatsSummary stats = summary("Europe/London");

        assertThat(stats.todaySeconds()).isEqualTo(600);
        assertThat(stats.weekSeconds()).isEqualTo(1100);
        assertThat(stats.monthSeconds()).isEqualTo(1500);
        assertThat(stats.totalSeconds()).isEqualTo(2000);
        assertThat(stats.sessionCount()).isEqualTo(8);
        assertThat(stats.currentStreakDays()).isEqualTo(3);
        assertThat(stats.longestStreakDays()).isEqualTo(4);
        assertThat(stats.genres()).containsExactly(
                new GenreTotal("kpop", 900), new GenreTotal("hiphop", 500),
                new GenreTotal(null, 400), new GenreTotal("jazz", 200));
    }

    @Test
    void streakSurvivesUntilTodayIsPractised() throws Exception {
        RoomDto room = room("kpop");
        api.sync(token, 0, List.of(room), List.of(
                TestApi.session(room, at("2030-01-14T10:00:00Z"), 60),
                TestApi.session(room, at("2030-01-15T10:00:00Z"), 60)));

        StatsSummary stats = summary("Europe/London");

        assertThat(stats.todaySeconds()).isZero();
        assertThat(stats.currentStreakDays()).isEqualTo(2);
    }

    @Test
    void daysFollowTheCallersTimeZone() throws Exception {
        RoomDto room = room("kpop");
        // 01:00 on the 16th in Tokyo, but still the 15th in London.
        api.sync(token, 0, List.of(room), List.of(TestApi.session(room, at("2030-01-15T16:00:00Z"), 60)));

        assertThat(summary("Asia/Tokyo").todaySeconds()).isEqualTo(60);
        assertThat(summary("Europe/London").todaySeconds()).isZero();
    }

    @Test
    void emptyHistoryIsAllZero() throws Exception {
        StatsSummary stats = summary("UTC");

        assertThat(stats.totalSeconds()).isZero();
        assertThat(stats.currentStreakDays()).isZero();
        assertThat(stats.longestStreakDays()).isZero();
        assertThat(stats.genres()).isEmpty();
    }

    @Test
    void unknownZoneIsABadRequest() throws Exception {
        mvc.perform(get("/api/stats/summary").param("zone", "Mars/Olympus")
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isBadRequest());
    }

    private StatsSummary summary(String zone) throws Exception {
        String body = mvc.perform(get("/api/stats/summary").param("zone", zone)
                        .header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andReturn().getResponse().getContentAsString();
        return json.readValue(body, StatsSummary.class);
    }

    private static RoomDto room(String genre) {
        return new RoomDto(UUID.randomUUID(), "Song " + genre, null, genre, null, "v.mov", NOW, null, NOW, null);
    }

    private static Instant at(String iso) {
        return Instant.parse(iso);
    }
}
