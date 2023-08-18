ALTER TABLE 'channel' add column 'parent_channel_id' text not null default '';
ALTER TABLE 'channel' add column 'parent_channel_type' int default 0;
ALTER TABLE 'conversation' add column 'parent_channel_id' text not null default '';
ALTER TABLE 'conversation' add column 'parent_channel_type' int default 0;