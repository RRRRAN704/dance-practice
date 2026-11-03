# Multi-stage build: compile with the full JDK, ship only a JRE.
# Used by `docker compose --profile full` locally and by the production deploy.

# ---- Build stage ----
# A jar runs on any CPU, so compile on the builder's native platform (no emulation, much faster)
# even when the final image targets another architecture (e.g. an x86 server from an ARM Mac).
FROM --platform=$BUILDPLATFORM eclipse-temurin:21-jdk AS build
WORKDIR /app

# Download dependencies first, in their own layer, so editing code doesn't re-download them.
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw -B -q dependency:go-offline

COPY src src
# Tests run in CI (they need Docker for Testcontainers), so skip them here.
RUN ./mvnw -B -q package -DskipTests && cp target/*.jar app.jar

# ---- Runtime stage ----
FROM eclipse-temurin:21-jre
WORKDIR /app

# Don't run as root inside the container.
RUN groupadd --system app && useradd --system --gid app app
USER app

COPY --from=build /app/app.jar app.jar

EXPOSE 8080
# MaxRAMPercentage: size the heap from the container's memory limit, not the host's.
ENTRYPOINT ["java", "-XX:MaxRAMPercentage=75", "-jar", "app.jar"]
