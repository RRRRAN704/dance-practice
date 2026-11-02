package com.dancepractice.config;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param secret base64-encoded HMAC key, at least 32 bytes
 */
@ConfigurationProperties("app.jwt")
public record JwtProperties(String secret, Duration accessTokenTtl, Duration refreshTokenTtl) {
}
