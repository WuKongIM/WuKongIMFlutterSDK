DELETE FROM message_reaction;
DROP INDEX IF EXISTS chat_msg_reaction_index;
CREATE UNIQUE INDEX IF NOT EXISTS chat_msg_reaction_index ON message_reaction (message_id,uid,channel_id,channel_type);