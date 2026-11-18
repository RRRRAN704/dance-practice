package com.dancepractice.ratelimit;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** Limits for the public auth endpoints; defaults live in application.yml. */
@ConfigurationProperties("app.rate-limit")
public record RateLimitProperties(
        RateLimit loginPerIp,
        RateLimit loginPerEmail,
        RateLimit registerPerIp,
        RateLimit refreshPerIp) {
}
