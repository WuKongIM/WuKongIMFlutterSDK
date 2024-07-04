ALTER TABLE 'message' add column 'expire_time' BIGINT DEFAULT 0;
ALTER TABLE 'message' add column 'expire_timestamp' BIGINT DEFAULT 0;
ALTER TABLE 'message_extra' ADD COLUMN 'is_pinned' int DEFAULT 0;