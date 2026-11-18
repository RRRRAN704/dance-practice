package com.dancepractice.ratelimit;

import static com.dancepractice.TestApi.uniqueEmail;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.dancepractice.TestcontainersConfiguration;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/**
 * The auth endpoints with small limits. Every test uses its own client IP (via X-Forwarded-For, as
 * Caddy sends it in production) so the tests don't share buckets.
 */
@SpringBootTest(properties = {
        "server.forward-headers-strategy=framework",
        "app.rate-limit.login-per-ip.capacity=3",
        "app.rate-limit.login-per-email.capacity=2",
        "app.rate-limit.register-per-ip.capacity=2",
        "app.rate-limit.refresh-per-ip.capacity=2",
})
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class RateLimitTests {

    private static final AtomicInteger nextIp = new AtomicInteger(1);

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Test
    void registerIsLimitedPerIp() throws Exception {
        String ip = uniqueIp();
        register(ip, uniqueEmail()).andExpect(status().isCreated());
        register(ip, uniqueEmail()).andExpect(status().isCreated());

        register(ip, uniqueEmail())
                .andExpect(status().isTooManyRequests())
                .andExpect(header().exists("Retry-After"))
                .andExpect(jsonPath("$.detail").value("Too many attempts, please try again later"))
                .andExpect(jsonPath("$.retryAfterSeconds").isNumber());

        register(uniqueIp(), uniqueEmail()).andExpect(status().isCreated());
    }

    @Test
    void loginIsLimitedPerEmailAcrossIps() throws Exception {
        String email = uniqueEmail();
        login(uniqueIp(), email).andExpect(status().isUnauthorized());
        login(uniqueIp(), email).andExpect(status().isUnauthorized());

        // A new IP doesn't help: the account itself is being guessed at.
        login(uniqueIp(), email).andExpect(status().isTooManyRequests());
        login(uniqueIp(), "Other-" + email).andExpect(status().isUnauthorized());
    }

    @Test
    void loginEmailKeyIgnoresCase() throws Exception {
        String email = uniqueEmail();
        login(uniqueIp(), email).andExpect(status().isUnauthorized());
        login(uniqueIp(), email.toUpperCase()).andExpect(status().isUnauthorized());

        login(uniqueIp(), "  " + email + " ").andExpect(status().isTooManyRequests());
    }

    @Test
    void loginIsLimitedPerIpAcrossEmails() throws Exception {
        String ip = uniqueIp();
        for (int i = 0; i < 3; i++) {
            login(ip, uniqueEmail()).andExpect(status().isUnauthorized());
        }
        login(ip, uniqueEmail()).andExpect(status().isTooManyRequests());
    }

    @Test
    void refreshIsLimitedPerIp() throws Exception {
        String ip = uniqueIp();
        refresh(ip).andExpect(status().isUnauthorized());
        refresh(ip).andExpect(status().isUnauthorized());
        refresh(ip).andExpect(status().isTooManyRequests());
    }

    private ResultActions register(String ip, String email) throws Exception {
        return postFrom(ip, "/api/auth/register", Map.of("email", email, "password", "correct-horse"));
    }

    private ResultActions login(String ip, String email) throws Exception {
        return postFrom(ip, "/api/auth/login", Map.of("email", email, "password", "wrong-password"));
    }

    private ResultActions refresh(String ip) throws Exception {
        return postFrom(ip, "/api/auth/refresh", Map.of("refreshToken", "not-a-real-token"));
    }

    private ResultActions postFrom(String ip, String path, Map<String, String> body) throws Exception {
        return mvc.perform(post(path)
                .header("X-Forwarded-For", ip)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json.writeValueAsString(body)));
    }

    private static String uniqueIp() {
        int n = nextIp.getAndIncrement();
        return "10.0." + (n / 256) + "." + (n % 256);
    }
}
