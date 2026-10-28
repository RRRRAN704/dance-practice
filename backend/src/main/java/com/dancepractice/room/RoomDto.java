package com.dancepractice.room;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.util.UUID;

/**
 * A practice room as it travels between the app and the server.
 *
 * @param updatedAt device time of the last edit; the newer side wins a conflict
 * @param deletedAt set once the room is deleted; the row stays as a tombstone
 */
public record RoomDto(
        @NotNull UUID id,
        @NotBlank @Size(max = 200) String name,
        @Size(max = 200) String artist,
        @Size(max = 50) String genre,
        @Size(max = 2000) String note,
        @NotBlank @Size(max = 255) String videoFileName,
        @NotNull Instant createdAt,
        Instant lastOpenedAt,
        @NotNull Instant updatedAt,
        Instant deletedAt) {

    public static RoomDto from(PracticeRoom room) {
        return new RoomDto(room.getId(), room.getName(), room.getArtist(), room.getGenre(), room.getNote(),
                room.getVideoFileName(), room.getCreatedAt(), room.getLastOpenedAt(), room.getUpdatedAt(),
                room.getDeletedAt());
    }
}
