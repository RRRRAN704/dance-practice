package com.dancepractice.ratelimit;

import java.time.Duration;

/**
 * At most {@code capacity} requests at once, refilled at {@code capacity} per {@code period}.
 * For example (10, 1m) allows a burst of 10, then one more every 6 seconds.
 */
public record RateLimit(int capacity, Duration period) {

    public RateLimit {
        if (capacity < 1 || period == null || period.isZero() || period.isNegative()) {
            throw new IllegalArgumentException("capacity must be >= 1 and period positive");
        }
    }

    double tokensPerSecond() {
        return capacity / (period.toNanos() / 1e9);
    }
}
