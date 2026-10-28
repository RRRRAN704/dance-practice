package com.dancepractice.user;

import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<User, UUID> {

    /** Pass an email already normalized with {@link User#normalizeEmail}. */
    Optional<User> findByEmail(String email);

    boolean existsByEmail(String email);

    /** SELECT ... FOR UPDATE: holds the user's row until the transaction ends. */
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select u from User u where u.id = :id")
    Optional<User> lockById(UUID id);
}
