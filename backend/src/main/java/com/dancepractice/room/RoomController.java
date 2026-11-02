package com.dancepractice.room;

import com.dancepractice.common.CurrentUser;
import java.util.List;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/** Read-only: the app writes rooms through /api/sync. */
@RestController
@RequestMapping("/api/rooms")
public class RoomController {

    private final PracticeRoomRepository rooms;

    public RoomController(PracticeRoomRepository rooms) {
        this.rooms = rooms;
    }

    /** The user's rooms, most recently edited first, without deleted ones. */
    @GetMapping
    public List<RoomDto> list(@AuthenticationPrincipal Jwt jwt) {
        return rooms.findByUserIdAndDeletedAtIsNullOrderByUpdatedAtDesc(CurrentUser.id(jwt)).stream()
                .map(RoomDto::from)
                .toList();
    }
}
