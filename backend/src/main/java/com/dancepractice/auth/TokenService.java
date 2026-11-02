package com.dancepractice.auth;

import com.dancepractice.config.JwtProperties;
import com.dancepractice.config.SecurityConfig;
import com.dancepractice.user.User;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.HexFormat;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

/**
 * Issues a short-lived JWT access token plus a long-lived opaque refresh token. Only the refresh
 * token's hash is saved, so the raw value exists solely on the client.
 */
@Service
class TokenService {

    private static final SecureRandom RANDOM = new SecureRandom();

    private final JwtEncoder jwtEncoder;
    private final RefreshTokenRepository refreshTokens;
    private final JwtProperties properties;
    private final Clock clock;

    TokenService(JwtEncoder jwtEncoder, RefreshTokenRepository refreshTokens, JwtProperties properties, Clock clock) {
        this.jwtEncoder = jwtEncoder;
        this.refreshTokens = refreshTokens;
        this.properties = properties;
        this.clock = clock;
    }

    /** Call inside a transaction: it saves the new refresh token. */
    TokenResponse issue(User user) {
        Instant now = clock.instant();
        String refreshToken = randomToken();
        refreshTokens.save(new RefreshToken(user, hash(refreshToken), now, now.plus(properties.refreshTokenTtl())));
        return new TokenResponse(
                accessToken(user, now), refreshToken, properties.accessTokenTtl().toSeconds(), "Bearer");
    }

    private String accessToken(User user, Instant now) {
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(SecurityConfig.ISSUER)
                .subject(user.getId().toString())
                .issuedAt(now)
                .expiresAt(now.plus(properties.accessTokenTtl()))
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }

    private static String randomToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    static String hash(String token) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8));
            return HexFormat.of().formatHex(digest);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException("SHA-256 is always available", e);
        }
    }
}
