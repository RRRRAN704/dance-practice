# Dance Practice API

Spring Boot backend for the Dance Practice iOS app: accounts and syncing practice rooms and practice history across devices. Video files stay on the device; only metadata is synced.

## Stack

- Java 21, Spring Boot 3.5, Maven
- PostgreSQL 16, Flyway migrations, Spring Data JPA
- JUnit 5 + Testcontainers (tests run against a real Postgres in Docker)

## Run locally

Requires JDK 21+ and Docker.

```bash
docker compose up -d          # Postgres on localhost:5433
./mvnw spring-boot:run        # API on http://localhost:8080
curl localhost:8080/actuator/health
```

Database settings can be overridden with `DB_URL`, `DB_USERNAME` and `DB_PASSWORD`.

## Test

```bash
./mvnw verify                 # starts a throwaway Postgres container automatically
```
