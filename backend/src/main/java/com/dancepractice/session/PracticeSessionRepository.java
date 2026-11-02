package com.dancepractice.session;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PracticeSessionRepository extends JpaRepository<PracticeSession, UUID> {

    /** Sessions added after {@code cursor}, leaving out the ones written with {@code excludeSeq}. */
    @Query("""
            select s from PracticeSession s
            where s.userId = :userId and s.changeSeq > :cursor and s.changeSeq <> :excludeSeq
            order by s.changeSeq""")
    List<PracticeSession> findChanges(UUID userId, long cursor, long excludeSeq);
}
