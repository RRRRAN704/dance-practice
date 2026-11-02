package com.dancepractice.auth;

import com.dancepractice.user.User;
import com.dancepractice.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.Optional;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository users;
    private final RefreshTokenRepository refreshTokens;
    private final TokenService tokens;
    private final PasswordEncoder passwordEncoder;
    private final Clock clock;
    /** Checked when the email is unknown, so a miss takes as long as a wrong password. */
    private final String dummyHash;

    AuthService(UserRepository users, RefreshTokenRepository refreshTokens, TokenService tokens,
            PasswordEncoder passwordEncoder, Clock clock) {
        this.users = users;
        this.refreshTokens = refreshTokens;
        this.tokens = tokens;
        this.passwordEncoder = passwordEncoder;
        this.clock = clock;
        this.dummyHash = passwordEncoder.encode("dummy-password");
    }

    @Transactional
    public TokenResponse register(RegisterRequest request) {
        String email = User.normalizeEmail(request.email());
        if (users.existsByEmail(email)) {
            throw new EmailTakenException();
        }
        User user;
        try {
            // Flush now so a concurrent sign-up with the same email hits the unique index here.
            user = users.saveAndFlush(new User(email, passwordEncoder.encode(request.password()), clock.instant()));
        } catch (DataIntegrityViolationException e) {
            throw new EmailTakenException();
        }
        return tokens.issue(user);
    }

    @Transactional
    public TokenResponse login(LoginRequest request) {
        Optional<User> user = users.findByEmail(User.normalizeEmail(request.email()));
        boolean passwordMatches = passwordEncoder.matches(
                request.password(), user.map(User::getPasswordHash).orElse(dummyHash));
        if (user.isEmpty() || !passwordMatches) {
            throw new InvalidCredentialsException();
        }
        return tokens.issue(user.get());
    }

    /**
     * Rotates the refresh token: the old one is revoked and a new pair is issued. Presenting an
     * already-revoked token means it was stolen or replayed, so every session of that user ends.
     * noRollbackFor keeps that mass revocation even though the call fails.
     */
    @Transactional(noRollbackFor = InvalidRefreshTokenException.class)
    public TokenResponse refresh(String rawRefreshToken) {
        RefreshToken token = refreshTokens.findByTokenHash(TokenService.hash(rawRefreshToken))
                .orElseThrow(InvalidRefreshTokenException::new);
        Instant now = clock.instant();
        if (token.isRevoked()) {
            refreshTokens.revokeAllForUser(token.getUser().getId(), now);
            throw new InvalidRefreshTokenException();
        }
        if (token.isExpired(now)) {
            throw new InvalidRefreshTokenException();
        }
        token.revoke(now);
        return tokens.issue(token.getUser());
    }

    /** Idempotent: an unknown or already-revoked token is not an error. */
    @Transactional
    public void logout(String rawRefreshToken) {
        refreshTokens.findByTokenHash(TokenService.hash(rawRefreshToken))
                .ifPresent(token -> token.revoke(clock.instant()));
    }
}
