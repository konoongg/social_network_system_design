-- =============================================
-- 1. Tables
-- =============================================

CREATE TABLE users (
    id            BIGSERIAL PRIMARY KEY,
    username      VARCHAR(50)  NOT NULL UNIQUE,
    full_name     VARCHAR(200) NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ          DEFAULT NULL  -- soft delete, users are never physically removed
);

CREATE TABLE subscriptions (
    follower_id   BIGINT NOT NULL REFERENCES users(id),
    followee_id   BIGINT NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_subscription UNIQUE (follower_id, followee_id)
);

CREATE TABLE posts (
    id            BIGSERIAL PRIMARY KEY,
    author_id     BIGINT       NOT NULL REFERENCES users(id),
    description   VARCHAR(500) NOT NULL CHECK (char_length(description) <= 500), -- max 500 chars
    latitude      DECIMAL(9,6),
    longitude     DECIMAL(9,6),
    like_count    INT          NOT NULL DEFAULT 0,  -- denormalized counter
    comment_count INT          NOT NULL DEFAULT 0,  -- denormalized counter
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ           DEFAULT NULL -- soft delete, posts are always stored
);

CREATE TABLE likes (
    user_id       BIGINT NOT NULL REFERENCES users(id),
    post_id       BIGINT NOT NULL REFERENCES posts(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_like UNIQUE (post_id, user_id)
);

CREATE TABLE comments (
    id            BIGSERIAL PRIMARY KEY,
    post_id       BIGINT       NOT NULL REFERENCES posts(id),
    author_id     BIGINT       NOT NULL REFERENCES users(id),
    text          VARCHAR(200) NOT NULL CHECK (char_length(text) <= 200), -- max 200 chars
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ           DEFAULT NULL -- soft delete
);

CREATE TABLE photos (
    id            BIGSERIAL PRIMARY KEY,
    post_id       BIGINT       NOT NULL REFERENCES posts(id),
    original_name VARCHAR(500) NOT NULL,
    s3_path       VARCHAR(1000) NOT NULL,  -- S3 object key
    size_bytes    BIGINT       NOT NULL,
    width         INT,
    height        INT,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    deleted_at    TIMESTAMPTZ           DEFAULT NULL
);

-- =============================================
-- 2. Indexes
-- =============================================

-- subscriptions
CREATE INDEX idx_subscriptions_followee ON subscriptions(followee_id);

-- posts
CREATE INDEX idx_posts_author_created ON posts(author_id, created_at DESC);   -- user profile feed
CREATE INDEX idx_posts_created ON posts(created_at DESC);                     -- global feed
CREATE INDEX idx_posts_deleted ON posts(deleted_at) WHERE deleted_at IS NULL; -- filter active posts

-- likes
CREATE INDEX idx_likes_user_created ON likes(user_id, created_at DESC);       -- user like history

-- comments
CREATE INDEX idx_comments_post_created ON comments(post_id, created_at DESC);   -- paginate comments on post
CREATE INDEX idx_comments_author_created ON comments(author_id, created_at DESC); -- user comment history

-- photos
CREATE INDEX idx_photos_post ON photos(post_id);

-- (optional) PostGIS geo index
-- CREATE EXTENSION postgis;
-- ALTER TABLE posts ADD COLUMN location GEOGRAPHY(Point, 4326);
-- UPDATE posts SET location = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);
-- CREATE INDEX idx_posts_location ON posts USING GIST (location);

-- =============================================
-- 3. Triggers for denormalized counters
-- =============================================

-- Function and trigger for like_count
CREATE OR REPLACE FUNCTION update_like_count() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE posts SET like_count = like_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_likes_update_counter
    AFTER INSERT OR DELETE ON likes
    FOR EACH ROW EXECUTE FUNCTION update_like_count();

-- Function and trigger for comment_count
CREATE OR REPLACE FUNCTION update_comment_count() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE posts SET comment_count = comment_count + 1 WHERE id = NEW.post_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE posts SET comment_count = comment_count - 1 WHERE id = OLD.post_id;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Only active comments (not deleted) increment the counter
CREATE TRIGGER trg_comments_update_counter
    AFTER INSERT ON comments
    FOR EACH ROW
    WHEN (NEW.deleted_at IS NULL)
    EXECUTE FUNCTION update_comment_count();

-- Soft-delete a comment decrements the counter
CREATE TRIGGER trg_comments_update_counter_del
    AFTER UPDATE OF deleted_at ON comments
    FOR EACH ROW
    WHEN (OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL)
    EXECUTE FUNCTION update_comment_count();
