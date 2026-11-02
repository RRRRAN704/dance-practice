package com.dancepractice;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.client.TestRestTemplate;
import org.springframework.context.annotation.Import;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Import(TestcontainersConfiguration.class)
class DancePracticeApplicationTests {

    @Autowired
    private TestRestTemplate rest;

    @Autowired
    private JdbcTemplate jdbc;

    @Test
    void flywayCreatesUsersTable() {
        Integer count = jdbc.queryForObject("SELECT count(*) FROM users", Integer.class);
        assertThat(count).isZero();
    }

    @Test
    void healthEndpointIsUp() {
        String body = rest.getForObject("/actuator/health", String.class);
        assertThat(body).contains("\"status\":\"UP\"");
    }
}
