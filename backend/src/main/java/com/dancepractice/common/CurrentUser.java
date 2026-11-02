package com.dancepractice.common;

import java.util.UUID;
import org.springframework.security.oauth2.jwt.Jwt;

/** The access token's subject is the user id. */
public final class CurrentUser {

    private CurrentUser() {
    }

    public static UUID id(Jwt jwt) {
        return UUID.fromString(jwt.getSubject());
    }
}
