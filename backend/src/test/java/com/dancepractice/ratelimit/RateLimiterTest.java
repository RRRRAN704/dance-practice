package com.dancepractice.ratelimit;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;

/** The token bucket on its own, with a clock the test moves by hand. */
class RateLimiterTest {

    private static final RateLimit TEN_PER_MINUTE = new RateLimit(10, Duration.ofMinutes(1));

    private final MutableClock clock = new MutableClock();
    private final RateLimiter limiter = new RateLimiter(clock);

    @Test
    void allowsABurstUpToCapacityThenRejects() {
        for (int i = 0; i < 10; i++) {
            assertThat(limiter.tryConsume("k", TEN_PER_MINUTE)).isZero();
        }
        assertThat(limiter.tryConsume("k", TEN_PER_MINUTE)).isEqualTo(Duration.ofSeconds(6));
    }

    @Test
    void refillsAtTheAverageRate() {
        drain("k");

        clock.advance(Duration.ofSeconds(5));
        assertThat(limiter.tryConsume("k", TEN_PER_MINUTE)).isEqualTo(Duration.ofSeconds(1));

        clock.advance(Duration.ofSeconds(1));
        assertThat(limiter.tryConsume("k", TEN_PER_MINUTE)).isZero();
        assertThat(limiter.tryConsume("k", TEN_PER_MINUTE)).isEqualTo(Duration.ofSeconds(6));
    }

    @Test
    void neverRefillsBeyondCapacity() {
        limiter.tryConsume("k", TEN_PER_MINUTE);
        clock.advance(Duration.ofHours(1));

        drain("k");
        assertThat(limiter.tryConsume("k", TEN_PER_MINUTE)).isPositive();
    }

    @Test
    void keysAreIndependent() {
        drain("a");
        assertThat(limiter.tryConsume("b", TEN_PER_MINUTE)).isZero();
    }

    @Test
    void evictsOnlyBucketsThatHaveRefilled() {
        drain("busy");
        clock.advance(Duration.ofSeconds(30));
        limiter.tryConsume("fresh", TEN_PER_MINUTE);
        clock.advance(Duration.ofSeconds(30));

        limiter.evictIdle();

        // "busy" refilled after 60 s; "fresh" took one token 30 s ago and is full again too.
        assertThat(limiter.size()).isZero();

        drain("busy");
        limiter.evictIdle();
        assertThat(limiter.size()).isEqualTo(1);
    }

    @Test
    void concurrentRequestsNeverExceedCapacity() throws Exception {
        AtomicInteger allowed = new AtomicInteger();
        try (ExecutorService pool = Executors.newFixedThreadPool(16)) {
            for (int i = 0; i < 1000; i++) {
                pool.submit(() -> {
                    if (limiter.tryConsume("k", TEN_PER_MINUTE).isZero()) {
                        allowed.incrementAndGet();
                    }
                });
            }
        }
        assertThat(allowed).hasValue(10);
    }

    @Test
    void rejectsNonsenseLimits() {
        assertThatThrownBy(() -> new RateLimit(0, Duration.ofMinutes(1))).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new RateLimit(5, Duration.ZERO)).isInstanceOf(IllegalArgumentException.class);
    }

    private void drain(String key) {
        while (limiter.tryConsume(key, TEN_PER_MINUTE).isZero()) {
            // keep taking tokens
        }
    }

    private static final class MutableClock extends Clock {
        private Instant now = Instant.parse("2026-11-17T10:00:00Z");

        void advance(Duration duration) {
            now = now.plus(duration);
        }

        @Override
        public Instant instant() {
            return now;
        }

        @Override
        public ZoneId getZone() {
            return ZoneOffset.UTC;
        }

        @Override
        public Clock withZone(ZoneId zone) {
            return this;
        }
    }
}
