package com.dancepractice.sync;

import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.ErrorResponseException;

/** A pushed id already belongs to another user's row. */
class IdConflictException extends ErrorResponseException {

    IdConflictException(UUID id) {
        super(HttpStatus.CONFLICT,
                ProblemDetail.forStatusAndDetail(HttpStatus.CONFLICT, "Id " + id + " is already in use"), null);
    }
}
