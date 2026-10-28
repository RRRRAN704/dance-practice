package com.dancepractice.auth;

/**
 * @param expiresIn access token lifetime in seconds
 */
public record TokenResponse(String accessToken, String refreshToken, long expiresIn, String tokenType) {
}
