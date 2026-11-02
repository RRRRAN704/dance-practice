-- Every write to synced data takes a number from this sequence. A client remembers the highest
-- number it has seen (its cursor) and next time asks only for rows above it.
CREATE SEQUENCE sync_change_seq;

-- Ids are generated on the device, so rows created offline keep the same id everywhere.
CREATE TABLE practice_rooms (
    id              UUID PRIMARY KEY,
    user_id         UUID          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name            VARCHAR(200)  NOT NULL,
    artist          VARCHAR(200),
    -- Free text rather than an enum so the app can add genres without a backend release.
    genre           VARCHAR(50),
    note            VARCHAR(2000),
    -- Name of the file on the device that imported it; videos themselves are never uploaded.
    video_file_name VARCHAR(255)  NOT NULL,
    created_at      TIMESTAMPTZ   NOT NULL,
    last_opened_at  TIMESTAMPTZ,
    -- Device time of the last edit; decides conflicts (last write wins).
    updated_at      TIMESTAMPTZ   NOT NULL,
    -- Tombstone: deleted rooms stay so other devices learn about the deletion.
    deleted_at      TIMESTAMPTZ,
    change_seq      BIGINT        NOT NULL
);

CREATE INDEX practice_rooms_user_change_idx ON practice_rooms (user_id, change_seq);

-- Append-only. room_name and genre are snapshots, so history survives the room being deleted.
CREATE TABLE practice_sessions (
    id               UUID PRIMARY KEY,
    user_id          UUID             NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    room_id          UUID             REFERENCES practice_rooms (id) ON DELETE SET NULL,
    room_name        VARCHAR(200)     NOT NULL,
    genre            VARCHAR(50),
    started_at       TIMESTAMPTZ      NOT NULL,
    duration_seconds DOUBLE PRECISION NOT NULL,
    change_seq       BIGINT           NOT NULL
);

CREATE INDEX practice_sessions_user_change_idx ON practice_sessions (user_id, change_seq);
CREATE INDEX practice_sessions_user_started_idx ON practice_sessions (user_id, started_at);
