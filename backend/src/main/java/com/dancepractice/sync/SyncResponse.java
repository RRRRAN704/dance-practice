package com.dancepractice.sync;

import com.dancepractice.room.RoomDto;
import com.dancepractice.session.SessionDto;
import java.util.List;

/**
 * @param cursor   send this back on the next sync
 * @param rooms    rooms changed elsewhere, plus the server's version of any pushed room that lost
 *                 a conflict; the device should overwrite its copy with these
 * @param sessions sessions logged on other devices
 */
public record SyncResponse(long cursor, List<RoomDto> rooms, List<SessionDto> sessions) {
}
