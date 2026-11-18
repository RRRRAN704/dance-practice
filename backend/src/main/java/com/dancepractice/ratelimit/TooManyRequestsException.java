package com.dancepractice.ratelimit;

import java.time.Duration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.ErrorResponseException;

/** 429 with a Retry-After header (whole seconds, rounded up) so clients know when to try again. */
public class TooManyRequestsException extends ErrorResponseException {

    public TooManyRequestsException(Duration retryAfter) {
        super(HttpStatus.TOO_MANY_REQUESTS,
                ProblemDetail.forStatusAndDetail(HttpStatus.TOO_MANY_REQUESTS, "Too many attempts, please try again later"),
                null);
        long seconds = Math.max(1, (retryAfter.toMillis() + 999) / 1000);
        getHeaders().set(HttpHeaders.RETRY_AFTER, Long.toString(seconds));
        getBody().setProperty("retryAfterSeconds", seconds);
    }
}
