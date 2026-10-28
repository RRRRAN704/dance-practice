package com.dancepractice.stats;

import com.dancepractice.stats.StatsSummary.GenreTotal;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.TemporalAdjusters;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Aggregations are plain SQL through JdbcTemplate: they return numbers rather than entities, and
 * SQL states them more directly than JPQL would. Weeks start on Monday, as in the app.
 */
@Service
public class StatsService {

    private static final String TOTALS_SQL = """
            SELECT coalesce(sum(duration_seconds) FILTER (WHERE started_at >= :today), 0) AS today,
                   coalesce(sum(duration_seconds) FILTER (WHERE started_at >= :week), 0)  AS week,
                   coalesce(sum(duration_seconds) FILTER (WHERE started_at >= :month), 0) AS month,
                   coalesce(sum(duration_seconds), 0)                                     AS total,
                   count(*)                                                               AS sessions
            FROM practice_sessions
            WHERE user_id = :userId""";

    private static final String GENRES_SQL = """
            SELECT genre, sum(duration_seconds) AS seconds
            FROM practice_sessions
            WHERE user_id = :userId
            GROUP BY genre
            ORDER BY seconds DESC""";

    /**
     * "Gaps and islands": numbering the distinct practice days in order and subtracting that number
     * from each date gives the same value for every day of an unbroken run, so grouping by it
     * yields one row per streak.
     */
    private static final String STREAKS_SQL = """
            WITH days AS (
                SELECT DISTINCT (started_at AT TIME ZONE :zone)::date AS day
                FROM practice_sessions
                WHERE user_id = :userId
            ),
            runs AS (
                SELECT day, day - (row_number() OVER (ORDER BY day))::int AS run_id
                FROM days
            )
            SELECT max(day) AS last_day, count(*) AS length
            FROM runs
            GROUP BY run_id""";

    private final NamedParameterJdbcTemplate jdbc;
    private final Clock clock;

    StatsService(NamedParameterJdbcTemplate jdbc, Clock clock) {
        this.jdbc = jdbc;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public StatsSummary summary(UUID userId, ZoneId zone) {
        LocalDate today = LocalDate.now(clock.withZone(zone));
        MapSqlParameterSource params = new MapSqlParameterSource()
                .addValue("userId", userId)
                .addValue("zone", zone.getId())
                .addValue("today", startOf(today, zone))
                .addValue("week", startOf(today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)), zone))
                .addValue("month", startOf(today.withDayOfMonth(1), zone));

        Map<String, Object> totals = jdbc.queryForMap(TOTALS_SQL, params);
        List<GenreTotal> genres = jdbc.query(GENRES_SQL, params,
                (rs, row) -> new GenreTotal(rs.getString("genre"), rs.getDouble("seconds")));
        List<Run> runs = jdbc.query(STREAKS_SQL, params,
                (rs, row) -> new Run(rs.getObject("last_day", LocalDate.class), rs.getInt("length")));

        int longest = runs.stream().mapToInt(Run::length).max().orElse(0);
        int current = runs.stream()
                .filter(run -> run.lastDay().equals(today) || run.lastDay().equals(today.minusDays(1)))
                .mapToInt(Run::length)
                .findFirst()
                .orElse(0);

        return new StatsSummary(
                zone.getId(),
                ((Number) totals.get("today")).doubleValue(),
                ((Number) totals.get("week")).doubleValue(),
                ((Number) totals.get("month")).doubleValue(),
                ((Number) totals.get("total")).doubleValue(),
                ((Number) totals.get("sessions")).longValue(),
                current,
                longest,
                genres);
    }

    private static Timestamp startOf(LocalDate day, ZoneId zone) {
        return Timestamp.from(day.atStartOfDay(zone).toInstant());
    }

    private record Run(LocalDate lastDay, int length) {
    }
}
