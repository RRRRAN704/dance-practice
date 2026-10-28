package com.dancepractice.stats;

import java.util.List;

/**
 * Practice totals in seconds, with days and weeks taken in the caller's time zone.
 *
 * @param currentStreakDays consecutive practice days ending today, or ending yesterday if today
 *                          has no practice yet (so the streak doesn't read 0 every morning)
 */
public record StatsSummary(
        String zone,
        double todaySeconds,
        double weekSeconds,
        double monthSeconds,
        double totalSeconds,
        long sessionCount,
        int currentStreakDays,
        int longestStreakDays,
        List<GenreTotal> genres) {

    /** @param genre null for sessions without a genre */
    public record GenreTotal(String genre, double seconds) {
    }
}
