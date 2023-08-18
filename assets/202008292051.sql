create table message
(
    client_seq INTEGER PRIMARY KEY AUTOINCREMENT,
    message_id TEXT,
    message_seq BIGINT default 0,
    channel_id TEXT not null default '',
    channel_type int default 0,
    timestamp INTEGER,
    from_uid text not null default '',
    type int default 0,
    content text not null default '',
    status int default 0,
    voice_status int default 0,
    created_at text not null default '',
    updated_at text not null default '',
    searchable_word text not null default '',
    client_msg_no text not null default '',
    is_deleted int default 0,
    setting int default 0,
    order_seq BIGINT default 0,
    extra text not null default ''
);

CREATE INDEX msg_channel_index ON message (channel_id,channel_type);
CREATE UNIQUE INDEX IF NOT EXISTS msg_client_msg_no_index ON message (client_msg_no);
CREATE INDEX searchable_word_index ON message (searchable_word);
CREATE INDEX type_index ON message (type);

create table conversation
(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id text not null default '',
    channel_type int default 0,
    last_client_msg_no text not null default '',
    last_msg_timestamp INTEGER,
    unread_count int default 0,
    is_deleted int default 0,
    version BIGINT default 0,
    extra text not null default ''
);

CREATE UNIQUE INDEX IF NOT EXISTS conversation_msg_index_channel ON conversation (channel_id, channel_type);
CREATE INDEX conversation_msg_index_time ON conversation (last_msg_timestamp);

create table channel
(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id text not null default '',
    channel_type int default 0,
    show_nick int default 0,
    username text not null default '',
    channel_name text not null default '',
    channel_remark text not null default '',
    top int default 0,
    mute int default 0,
    save int default 0,
    forbidden int default 0,
    follow int default 0,
    is_deleted int default 0,
    receipt int default 0,
    status int default 1,
    invite int default 0,
    robot int default 0,
    version BIGINT default 0,
    online smallint not null default 0,
    last_offline INTEGER not null default 0,
    avatar text not null default '',
    category text not null default '',
    extra text not null default '',
    created_at text not null default '',
    updated_at text not null default ''
);

CREATE UNIQUE INDEX IF NOT EXISTS channel_index ON channel (channel_id, channel_type);

create table channel_members
(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id text not null default '',
    channel_type int default 0,
    member_uid text not null default '',
    member_name text not null default '',
    member_remark text not null default '',
    member_avatar text not null default '',
    member_invite_uid text not null default '',
    role int default 0,
    status int default 1,
    is_deleted int default 0,
    robot int default 0,
    version BIGINT default 0,
    created_at text not null default '',
    updated_at text not null default '',
    extra text not null default ''
);

CREATE UNIQUE INDEX IF NOT EXISTS channel_members_index ON channel_members (channel_id,channel_type,member_uid);


create table message_reaction
(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    channel_id text not null default '',
    channel_type int default 0,
    uid text not null default '',
    name text not null default '',
    emoji text not null default '',
    message_id text not null default '',
    seq BIGINT default 0,
    is_deleted int default 0,
    created_at text
);

CREATE UNIQUE INDEX IF NOT EXISTS chat_msg_reaction_index ON message_reaction (message_id,uid,emoji);
