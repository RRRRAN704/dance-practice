package com.dancepractice.user;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
public class User {

    @Id
    private UUID id;

    /** Always stored lower-case; see {@link #normalizeEmail}. */
    @Column(nullable = false)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected User() {
        // for JPA
    }

    public User(String email, String passwordHash, Instant createdAt) {
        this.id = UUID.randomUUID();
        this.email = normalizeEmail(email);
        this.passwordHash = passwordHash;
        this.createdAt = createdAt;
    }

    public static String normalizeEmail(String email) {
        return email.trim().toLowerCase();
    }

    public UUID getId() {
        return id;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}
