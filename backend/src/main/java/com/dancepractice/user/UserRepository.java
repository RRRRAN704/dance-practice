package com.dancepractice.user;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, UUID> {

    /** Pass an email already normalized with {@link User#normalizeEmail}. */
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);
}
