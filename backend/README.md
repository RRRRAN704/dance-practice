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

### One command, no Java needed

```bash
docker compose --profile full up -d --build   # Postgres + the API, built from the Dockerfile
curl localhost:8080/actuator/health
docker compose --profile full down            # stop both (data stays in the pgdata volume)
```

The `Dockerfile` is a multi-stage build (JDK compiles, a JRE-only image runs it as a non-root user) and is the same image that production runs.

Database settings can be overridden with `DB_URL`, `DB_USERNAME` and `DB_PASSWORD`.

Swagger UI: http://localhost:8080/swagger-ui.html. `requests.http` walks through the whole API from IntelliJ.

## API

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/auth/register`, `/login` | Returns an access token (JWT, 15 min) and a refresh token (30 days) |
| POST | `/api/auth/refresh` | Rotates the refresh token; reusing an old one revokes all of the user's tokens |
| POST | `/api/auth/logout` | Revokes a refresh token |
| GET / DELETE | `/api/me` | Profile; delete the account and all cloud data |
| POST | `/api/sync` | Push local changes and pull everything after the cursor, in one transaction |
| GET | `/api/rooms` | Current rooms, newest edit first |
| GET | `/api/stats/summary?zone=Europe/London` | Today/week/month/total, streaks, time per genre |

Errors are RFC 9457 `application/problem+json`.

## Sync design

- **Cursor**: every write takes a number from a Postgres sequence; a device sends back the highest number it has seen. Device clocks never decide what is "new".
- **Ordering**: each sync locks the user's row, so one user's syncs run one at a time and a slow transaction can't commit a lower number after a device has already moved past it.
- **Conflicts**: rooms are last-write-wins on the device's `updatedAt`; deletions are final tombstones, so a stale copy can't bring a deleted room back. The losing device gets the winning version in the response.
- **Idempotency**: ids are UUIDs generated on the device, so a retried request changes nothing.
- **Ownership**: every pushed id is checked against the signed-in user.

## Test

```bash
./mvnw verify                 # starts a throwaway Postgres container automatically
```
