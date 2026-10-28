package com.dancepractice.room;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "practice_rooms")
public class PracticeRoom {

    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(nullable = false)
    private String name;

    private String artist;

    private String genre;

    private String note;

    @Column(name = "video_file_name", nullable = false)
    private String videoFileName;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "last_opened_at")
    private Instant lastOpenedAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "deleted_at")
    private Instant deletedAt;

    @Column(name = "change_seq", nullable = false)
    private long changeSeq;

    protected PracticeRoom() {
        // for JPA
    }

    /** A room first seen on the server; the id comes from the device. */
    public PracticeRoom(UUID userId, RoomDto incoming, long changeSeq) {
        this.id = incoming.id();
        this.userId = userId;
        apply(incoming, changeSeq);
    }

    /**
     * Merges a version from a device. Deletion is final: once a tombstone exists, later edits are
     * ignored, so a room deleted on one phone can't come back from another phone's stale copy.
     * Otherwise the newer {@code updatedAt} wins.
     *
     * @return whether the incoming version was taken
     */
    public boolean merge(RoomDto incoming, long changeSeq) {
        if (isDeleted() || !incoming.updatedAt().isAfter(updatedAt)) {
            return false;
        }
        apply(incoming, changeSeq);
        return true;
    }

    private void apply(RoomDto incoming, long changeSeq) {
        this.name = incoming.name();
        this.artist = incoming.artist();
        this.genre = incoming.genre();
        this.note = incoming.note();
        this.videoFileName = incoming.videoFileName();
        this.createdAt = incoming.createdAt();
        this.lastOpenedAt = incoming.lastOpenedAt();
        this.updatedAt = incoming.updatedAt();
        this.deletedAt = incoming.deletedAt();
        this.changeSeq = changeSeq;
    }

    public boolean isDeleted() {
        return deletedAt != null;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getName() {
        return name;
    }

    public String getArtist() {
        return artist;
    }

    public String getGenre() {
        return genre;
    }

    public String getNote() {
        return note;
    }

    public String getVideoFileName() {
        return videoFileName;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getLastOpenedAt() {
        return lastOpenedAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public Instant getDeletedAt() {
        return deletedAt;
    }

    public long getChangeSeq() {
        return changeSeq;
    }
}
