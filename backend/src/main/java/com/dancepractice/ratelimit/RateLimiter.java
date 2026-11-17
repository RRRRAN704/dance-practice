package com.dancepractice.ratelimit;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.TimeUnit;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * In-memory token buckets, one per key (e.g. "login-ip:1.2.3.4").
 *
 * <p>A bucket holds up to {@code capacity} tokens and refills continuously at {@code capacity} per
 * {@code period}. Each request takes one token; with none left it is rejected. So a client can burst
 * up to the capacity, and after that is held to the average rate.
 *
 * <p>Buckets are immutable values swapped atomically with {@link ConcurrentMap#compute}, so
 * concurrent requests on the same key never lose an update, and {@link #evictIdle} can't remove a
 * bucket that was changed after it looked at it.
 *
 * <p>State lives in this JVM only: fine for the single API instance we run. Several instances would
 * need a shared store such as Redis.
 */
@Component
public class RateLimiter {

    /** Refills are fractional doubles; treat 0.9999999999 tokens as 1 so the maths stays exact enough. */
    private static final double EPSILON = 1e-9;

    private final ConcurrentMap<String, Bucket> buckets = new ConcurrentHashMap<>();
    private final Clock clock;

    public RateLimiter(Clock clock) {
        this.clock = clock;
    }

    /**
     * Takes one token from the key's bucket.
     *
     * @return {@link Duration#ZERO} if allowed, otherwise how long until a token is available
     */
    public Duration tryConsume(String key, RateLimit limit) {
        Instant now = clock.instant();
        Duration[] wait = {Duration.ZERO};
        buckets.compute(key, (k, bucket) -> {
            double tokens = bucket == null ? limit.capacity() : bucket.tokensAt(now, limit);
            if (tokens >= 1 - EPSILON) {
                tokens = Math.max(1, tokens);
                return new Bucket(tokens - 1, now, limit);
            }
            double secondsUntilOneToken = (1 - tokens) / limit.tokensPerSecond();
            wait[0] = Duration.ofMillis((long) Math.ceil(secondsUntilOneToken * 1000 - EPSILON * 1000));
            return new Bucket(tokens, now, limit);
        });
        return wait[0];
    }

    /** Drops buckets that have refilled completely: they behave exactly like a missing bucket. */
    @Scheduled(fixedDelay = 10, timeUnit = TimeUnit.MINUTES)
    void evictIdle() {
        Instant now = clock.instant();
        buckets.entrySet().removeIf(entry -> entry.getValue().isFullAt(now));
    }

    int size() {
        return buckets.size();
    }

    private record Bucket(double tokens, Instant updatedAt, RateLimit limit) {

        double tokensAt(Instant now, RateLimit current) {
            double elapsedSeconds = Math.max(0, Duration.between(updatedAt, now).toNanos() / 1e9);
            return Math.min(current.capacity(), tokens + elapsedSeconds * current.tokensPerSecond());
        }

        boolean isFullAt(Instant now) {
            return tokensAt(now, limit) >= limit.capacity() - EPSILON;
        }
    }
}
