package com.dancepractice.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.dancepractice.TestcontainersConfiguration;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

@SpringBootTest
@AutoConfigureMockMvc
@Import(TestcontainersConfiguration.class)
class AuthFlowTests {

    private static final String PASSWORD = "correct-horse";

    @Autowired
    private MockMvc mvc;

    @Autowired
    private ObjectMapper json;

    @Test
    void registerThenReadProfile() throws Exception {
        String email = uniqueEmail();
        JsonNode tokens = jsonOf(register(email).andExpect(status().isCreated()));

        assertThat(tokens.get("tokenType").asText()).isEqualTo("Bearer");
        assertThat(tokens.get("expiresIn").asLong()).isEqualTo(900);

        mvc.perform(get("/api/me").header("Authorization", "Bearer " + tokens.get("accessToken").asText()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value(email));
    }

    @Test
    void emailIsCaseInsensitive() throws Exception {
        String email = uniqueEmail();
        register(email).andExpect(status().isCreated());

        register(email.toUpperCase())
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.detail").value("This email is already registered"));
        login(email.toUpperCase(), PASSWORD).andExpect(status().isOk());
    }

    @Test
    void invalidRegistrationListsFieldErrors() throws Exception {
        post("/api/auth/register", """
                {"email": "not-an-email", "password": "short"}
                """)
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.errors.email").exists())
                .andExpect(jsonPath("$.errors.password").exists());
    }

    @Test
    void wrongPasswordAndUnknownEmailLookTheSame() throws Exception {
        String email = uniqueEmail();
        register(email);

        login(email, "wrong-password")
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Wrong email or password"));
        login(uniqueEmail(), PASSWORD)
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.detail").value("Wrong email or password"));
    }

    @Test
    void protectedEndpointsNeedAToken() throws Exception {
        mvc.perform(get("/api/me")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/me").header("Authorization", "Bearer garbage")).andExpect(status().isUnauthorized());
    }

    @Test
    void refreshRotatesTokens() throws Exception {
        String first = jsonOf(register(uniqueEmail())).get("refreshToken").asText();

        String second = jsonOf(refresh(first).andExpect(status().isOk())).get("refreshToken").asText();

        assertThat(second).isNotEqualTo(first);
        refresh(second).andExpect(status().isOk());
    }

    @Test
    void reusingARotatedTokenRevokesTheWholeFamily() throws Exception {
        String stolen = jsonOf(register(uniqueEmail())).get("refreshToken").asText();
        String current = jsonOf(refresh(stolen)).get("refreshToken").asText();

        refresh(stolen).andExpect(status().isUnauthorized());

        // The legitimate client's newer token is gone too, forcing a fresh login.
        refresh(current).andExpect(status().isUnauthorized());
    }

    @Test
    void logoutRevokesTheRefreshToken() throws Exception {
        String refreshToken = jsonOf(register(uniqueEmail())).get("refreshToken").asText();

        post("/api/auth/logout", body("refreshToken", refreshToken)).andExpect(status().isNoContent());
        post("/api/auth/logout", body("refreshToken", refreshToken)).andExpect(status().isNoContent());

        refresh(refreshToken).andExpect(status().isUnauthorized());
    }

    private JsonNode jsonOf(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }

    private ResultActions register(String email) throws Exception {
        return post("/api/auth/register", credentials(email, PASSWORD));
    }

    private ResultActions login(String email, String password) throws Exception {
        return post("/api/auth/login", credentials(email, password));
    }

    private ResultActions refresh(String refreshToken) throws Exception {
        return post("/api/auth/refresh", body("refreshToken", refreshToken));
    }

    private ResultActions post(String path, String body) throws Exception {
        return mvc.perform(
                MockMvcRequestBuilders.post(path)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(body));
    }

    private String credentials(String email, String password) throws Exception {
        return json.writeValueAsString(new LoginRequest(email, password));
    }

    private String body(String key, String value) throws Exception {
        return json.writeValueAsString(Map.of(key, value));
    }

    private static String uniqueEmail() {
        return "dancer-" + UUID.randomUUID() + "@example.com";
    }
}
