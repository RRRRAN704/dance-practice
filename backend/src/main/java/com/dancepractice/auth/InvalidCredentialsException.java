package com.dancepractice.auth;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.ErrorResponseException;

class InvalidCredentialsException extends ErrorResponseException {

    InvalidCredentialsException() {
        super(HttpStatus.UNAUTHORIZED, ProblemDetail.forStatusAndDetail(HttpStatus.UNAUTHORIZED, "Wrong email or password"), null);
    }
}
