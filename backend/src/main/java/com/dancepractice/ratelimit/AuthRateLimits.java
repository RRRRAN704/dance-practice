package com.dancepractice.ratelimit;

import com.dancepractice.user.User;
import java.time.Duration;
import org.springframework.stereotype.Component;

/**
 * Which limits apply to which auth endpoint. Throws {@link TooManyRequestsException} when one is hit.
 *
 * <p>The client IP is {@code request.getRemoteAddr()}. In production Caddy sits in front and
 * replaces any X-Forwarded-For sent by the client with the real peer address; Spring
 * ({@code server.forward-headers-strategy=framework}) then reports that as the remote address. The
 * API port is not published, so nobody can reach it without going through Caddy.
 */
@Component
public class AuthRateLimits {

    private final RateLimiter limiter;
    private final RateLimitProperties limits;

    public AuthRateLimits(RateLimiter limiter, RateLimitProperties limits) {
        this.limiter = limiter;
        this.limits = limits;
    }

    /**
     * Per IP stops one client hammering the API; per email stops a password-guessing attack on one
     * account spread over many IPs. The trade-off: someone could lock a known account out for a few
     * minutes by failing on purpose, which is milder than letting its password be guessed.
     */
    public void checkLogin(String ip, String email) {
        check("login-ip:" + ip, limits.loginPerIp());
        check("login-email:" + User.normalizeEmail(email), limits.loginPerEmail());
    }

    public void checkRegister(String ip) {
        check("register-ip:" + ip, limits.registerPerIp());
    }

    public void checkRefresh(String ip) {
        check("refresh-ip:" + ip, limits.refreshPerIp());
    }

    private void check(String key, RateLimit limit) {
        Duration wait = limiter.tryConsume(key, limit);
        if (!wait.isZero()) {
            throw new TooManyRequestsException(wait);
        }
    }
}
