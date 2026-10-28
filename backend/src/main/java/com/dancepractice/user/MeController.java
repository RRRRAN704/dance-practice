package com.dancepractice.user;

import com.dancepractice.common.CurrentUser;
import com.dancepractice.common.NotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/me")
public class MeController {

    private final UserRepository users;

    public MeController(UserRepository users) {
        this.users = users;
    }

    @GetMapping
    public UserResponse me(@AuthenticationPrincipal Jwt jwt) {
        return users.findById(CurrentUser.id(jwt))
                .map(UserResponse::from)
                .orElseThrow(() -> new NotFoundException("User no longer exists"));
    }

    /**
     * Deletes the account and all of its cloud data; the database cascades to tokens, rooms and
     * sessions. Access tokens already issued stop working at the next lookup of the user.
     */
    @DeleteMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAccount(@AuthenticationPrincipal Jwt jwt) {
        users.deleteById(CurrentUser.id(jwt));
    }
}
