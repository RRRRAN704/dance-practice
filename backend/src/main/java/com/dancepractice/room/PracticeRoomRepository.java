package com.dancepractice.room;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface PracticeRoomRepository extends JpaRepository<PracticeRoom, UUID> {

    List<PracticeRoom> findByUserIdAndDeletedAtIsNullOrderByUpdatedAtDesc(UUID userId);

    /** Rooms changed after {@code cursor}, leaving out the ones written with {@code excludeSeq}. */
    @Query("""
            select r from PracticeRoom r
            where r.userId = :userId and r.changeSeq > :cursor and r.changeSeq <> :excludeSeq
            order by r.changeSeq""")
    List<PracticeRoom> findChanges(UUID userId, long cursor, long excludeSeq);
}
