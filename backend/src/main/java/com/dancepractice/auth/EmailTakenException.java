package com.dancepractice.auth;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.ErrorResponseException;

class EmailTakenException extends ErrorResponseException {

    EmailTakenException() {
        super(HttpStatus.CONFLICT, ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, "This email is already registered"), null);
    }
}
