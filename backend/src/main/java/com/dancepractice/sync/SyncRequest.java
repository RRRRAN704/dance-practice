package com.dancepractice.sync;

import com.dancepractice.room.RoomDto;
import com.dancepractice.session.SessionDto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.util.List;

/**
 * @param cursor   the cursor from the previous response, or 0 on a device's first sync
 * @param rooms    rooms created, edited or deleted on the device since its last sync
 * @param sessions sessions logged on the device since its last sync
 */
public record SyncRequest(
        @PositiveOrZero long cursor,
        @Size(max = 500) List<@Valid RoomDto> rooms,
        @Size(max = 2000) List<@Valid SessionDto> sessions) {

    public SyncRequest {
        rooms = rooms == null ? List.of() : rooms;
        sessions = sessions == null ? List.of() : sessions;
    }
}
