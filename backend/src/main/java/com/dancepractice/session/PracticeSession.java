package com.dancepractice.session;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/** Immutable once stored: sessions are only ever added. */
@Entity
@Table(name = "practice_sessions")
public class PracticeSession {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "room_id")
    private UUID roomId;

    @Column(name = "room_name", nullable = false)
    private String roomName;

    private String genre;

    @Column(name = "started_at", nullable = false)
    private Instant startedAt;

    @Column(name = "duration_seconds", nullable = false)
    private double durationSeconds;

    @Column(name = "change_seq", nullable = false)
    private long changeSeq;

    protected PracticeSession() {
        // for JPA
    }

    /**
     * @param roomId the room to link, or null if it doesn't belong to this user (the snapshot
     *               fields still describe it)
     */
    public PracticeSession(UUID userId, SessionDto incoming, UUID roomId, long changeSeq) {
        this.id = incoming.id();
        this.userId = userId;
        this.roomId = roomId;
        this.roomName = incoming.roomName();
        this.genre = incoming.genre();
        this.startedAt = incoming.startedAt();
        this.durationSeconds = incoming.durationSeconds();
        this.changeSeq = changeSeq;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getRoomId() {
        return roomId;
    }

    public String getRoomName() {
        return roomName;
    }

    public String getGenre() {
        return genre;
    }

    public Instant getStartedAt() {
        return startedAt;
    }

    public double getDurationSeconds() {
        return durationSeconds;
    }

    public long getChangeSeq() {
        return changeSeq;
    }
}
