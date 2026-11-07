CREATE TABLE IF NOT EXISTS prefix (
    guild_id BIGINT PRIMARY KEY,
    prefix VARCHAR(7)
);

CREATE TABLE IF NOT EXISTS lost_boosters (
    guild_id BIGINT,
    user_id BIGINT PRIMARY KEY,
    username TEXT,
    discriminator TEXT,
    lost_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS antiraid (
    guild_id BIGINT,
    command TEXT,
    punishment TEXT,
    seconds INTEGER
);

-- Legacy antiraid tables were keyed by guild alone and stored a different
-- layout, so the columns above never got created on them. Give them the
-- columns the code reads and key them by command.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'antiraid'
          AND column_name = 'locked'
    ) THEN
        ALTER TABLE antiraid ADD COLUMN IF NOT EXISTS command TEXT;
        ALTER TABLE antiraid ADD COLUMN IF NOT EXISTS punishment TEXT;
        ALTER TABLE antiraid ADD COLUMN IF NOT EXISTS seconds INTEGER;
        ALTER TABLE antiraid DROP CONSTRAINT IF EXISTS antiraid_pkey;
        DELETE FROM antiraid WHERE command IS NULL;
        ALTER TABLE antiraid ADD CONSTRAINT antiraid_pkey PRIMARY KEY (guild_id, command);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS whitelist (
    guild_id BIGINT,
    module TEXT,
    object_id BIGINT,
    mode TEXT
);

-- Legacy whitelist tables held one row per guild and carry a different
-- layout, so the columns above never got created on them. The code stores
-- one row per whitelisted object, so the per-guild uniqueness has to go.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'whitelist'
          AND column_name = 'status'
    ) THEN
        ALTER TABLE whitelist ADD COLUMN IF NOT EXISTS module TEXT;
        ALTER TABLE whitelist ADD COLUMN IF NOT EXISTS object_id BIGINT;
        ALTER TABLE whitelist ADD COLUMN IF NOT EXISTS mode TEXT;
        ALTER TABLE whitelist DROP CONSTRAINT IF EXISTS whitelist_guild_id_key;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS guild_whitelist (
    guild_id BIGINT PRIMARY KEY
);
-- Run once. Safe to re-run.

CREATE TABLE IF NOT EXISTS antinuke_guild (
    guild_id        BIGINT PRIMARY KEY,
    enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    log_channel_id  BIGINT,
    window_seconds  INTEGER NOT NULL DEFAULT 10
);

CREATE TABLE IF NOT EXISTS antinuke_settings (
    guild_id    BIGINT NOT NULL,
    module      TEXT NOT NULL,
    punishment  TEXT NOT NULL,
    threshold   INTEGER NOT NULL DEFAULT 3,
    PRIMARY KEY (guild_id, module)
);

CREATE TABLE IF NOT EXISTS antinuke_whitelist (
    guild_id   BIGINT NOT NULL,
    object_id  BIGINT NOT NULL,
    mode       TEXT NOT NULL DEFAULT 'user',
    PRIMARY KEY (guild_id, object_id, mode)
);

CREATE TABLE IF NOT EXISTS antinuke_admins (
    guild_id  BIGINT NOT NULL,
    user_id   BIGINT NOT NULL,
    PRIMARY KEY (guild_id, user_id)
);

CREATE TABLE IF NOT EXISTS antinuke_permissions (
    guild_id    BIGINT NOT NULL,
    type        TEXT NOT NULL,
    permission  TEXT NOT NULL,
    punishment  TEXT NOT NULL DEFAULT 'stripstaff',
    PRIMARY KEY (guild_id, type, permission)
);

-- If these tables already exist without the keys/columns above:
-- ALTER TABLE antinuke_settings ADD PRIMARY KEY (guild_id, module);
-- ALTER TABLE antinuke_permissions ADD COLUMN IF NOT EXISTS punishment TEXT NOT NULL DEFAULT 'stripstaff';
-- ALTER TABLE antinuke_permissions ADD PRIMARY KEY (guild_id, type, permission);
-- ALTER TABLE antinuke_admins ADD PRIMARY KEY (guild_id, user_id);
-- ALTER TABLE antinuke_whitelist ADD PRIMARY KEY (guild_id, object_id, mode);

CREATE TABLE IF NOT EXISTS blacklist (
    user_id BIGINT PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS afk (
    user_id BIGINT PRIMARY KEY,
    status TEXT,
    time BIGINT
);

-- Existing databases whose afk table predates these columns:
ALTER TABLE afk ADD COLUMN IF NOT EXISTS status TEXT;
ALTER TABLE afk ADD COLUMN IF NOT EXISTS time BIGINT;

CREATE TABLE IF NOT EXISTS forcenick (
    guild_id BIGINT,
    user_id BIGINT,
    name TEXT,
    PRIMARY KEY (guild_id, user_id)
);

-- Legacy forcenick tables kept the forced nickname in "nickname"; the code
-- reads "name".
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'forcenick'
          AND column_name = 'nickname'
    ) THEN
        ALTER TABLE forcenick RENAME COLUMN nickname TO name;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS lockdown (
    guild_id BIGINT,
    channel_id BIGINT,
    role_id BIGINT
);

CREATE TABLE IF NOT EXISTS welcome (
    guild_id BIGINT,
    channel_id BIGINT,
    message TEXT
);

CREATE TABLE IF NOT EXISTS boost (
    guild_id BIGINT,
    channel_id BIGINT,
    message TEXT
);

CREATE TABLE IF NOT EXISTS warnings (
    guild_id BIGINT,
    user_id BIGINT,
    warns INTEGER DEFAULT 0,
    PRIMARY KEY(guild_id, user_id)
);

CREATE TABLE IF NOT EXISTS aliases (
    guild_id BIGINT,
    alias TEXT,
    command TEXT,
    invoke TEXT,
    PRIMARY KEY (guild_id, alias)
);

-- Legacy aliases tables were keyed by "name"; the code reads "alias" and
-- leaves "invoke" empty.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'aliases'
          AND column_name = 'name'
    ) THEN
        ALTER TABLE aliases RENAME COLUMN name TO alias;
        ALTER TABLE aliases ALTER COLUMN invoke DROP NOT NULL;
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS autorole (
    guild_id BIGINT,
    role_id BIGINT,
    PRIMARY KEY (guild_id, role_id)
);

CREATE TABLE IF NOT EXISTS sticky_messages (
    guild_id BIGINT,
    channel_id BIGINT,
    message_id BIGINT,
    message TEXT,
    schedule TEXT,
    PRIMARY KEY (guild_id, channel_id, message_id)
);

CREATE TABLE IF NOT EXISTS autoresponders (
    id SERIAL PRIMARY KEY,
    guild_id BIGINT NOT NULL,
    trigger TEXT NOT NULL,
    response TEXT NOT NULL,
    not_strict BOOLEAN DEFAULT FALSE,
    self_destruct BOOLEAN DEFAULT FALSE,
    self_destruct_time INT DEFAULT 0,
    delete_trigger BOOLEAN DEFAULT FALSE,
    reply BOOLEAN DEFAULT FALSE,
    UNIQUE(guild_id, trigger)
);

CREATE TABLE IF NOT EXISTS booster_module (
    guild_id BIGINT PRIMARY KEY,
    base BIGINT DEFAULT NULL
);


CREATE TABLE IF NOT EXISTS booster_roles (
    guild_id BIGINT,
    user_id BIGINT,
    role_id BIGINT,
    PRIMARY KEY (guild_id, user_id)
);


CREATE TABLE IF NOT EXISTS br_award (
    guild_id BIGINT,
    role_id BIGINT,
    PRIMARY KEY (guild_id, role_id)
);

CREATE TABLE IF NOT EXISTS leave (
    guild_id BIGINT,
    channel_id BIGINT,
    message TEXT,
    PRIMARY KEY(guild_id, channel_id)
);

CREATE TABLE IF NOT EXISTS fake_permissions (
    guild_id bigint NOT NULL,
    role_id bigint NOT NULL,
    permission text NOT NULL,
    PRIMARY KEY (guild_id, role_id)
);


CREATE TABLE IF NOT EXISTS honeypots (
    guild_id BIGINT NOT NULL,
    channel_id BIGINT NOT NULL,
    punishment TEXT NOT NULL CHECK (punishment IN ('ban', 'softban', 'jail')),
    PRIMARY KEY (guild_id, channel_id)
);

-- Per-server honeypot exemptions, moderation log destination, and jail role.
CREATE TABLE IF NOT EXISTS honeypot_settings (
    guild_id BIGINT PRIMARY KEY,
    staff_role_id BIGINT,
    log_channel_id BIGINT,
    jail_role_id BIGINT
);

-- VoiceMaster temporary voice channels
CREATE TABLE IF NOT EXISTS voicemaster_configuration (
    guild_id BIGINT PRIMARY KEY,
    category_id BIGINT,
    interface_id BIGINT,
    channel_id BIGINT,
    role_id BIGINT,
    region TEXT,
    bitrate INTEGER
);

CREATE TABLE IF NOT EXISTS voicemaster_channels (
    guild_id BIGINT NOT NULL,
    channel_id BIGINT PRIMARY KEY,
    owner_id BIGINT NOT NULL
);

-- Last.fm accounts and per-server Now Playing reactions
CREATE TABLE IF NOT EXISTS lastfm (
    user_id BIGINT PRIMARY KEY,
    username TEXT NOT NULL,
    url TEXT,
    playcount INTEGER DEFAULT 0,
    tracks INTEGER DEFAULT 0,
    artist TEXT
);

-- Legacy lastfm tables stored a per-user Last.fm session; the code stores
-- the user's now playing track instead.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = current_schema()
          AND table_name = 'lastfm'
          AND column_name = 'discord_id'
    ) THEN
        ALTER TABLE lastfm ADD COLUMN IF NOT EXISTS user_id BIGINT;
        ALTER TABLE lastfm ADD COLUMN IF NOT EXISTS username TEXT;
        ALTER TABLE lastfm ADD COLUMN IF NOT EXISTS url TEXT;
        ALTER TABLE lastfm ADD COLUMN IF NOT EXISTS playcount INTEGER DEFAULT 0;
        ALTER TABLE lastfm ADD COLUMN IF NOT EXISTS tracks INTEGER DEFAULT 0;
        ALTER TABLE lastfm ADD COLUMN IF NOT EXISTS artist TEXT;
        ALTER TABLE lastfm DROP CONSTRAINT IF EXISTS lastfm_pkey;
        ALTER TABLE lastfm ALTER COLUMN discord_id DROP NOT NULL;
        ALTER TABLE lastfm ALTER COLUMN lastfm_username DROP NOT NULL;
        ALTER TABLE lastfm ALTER COLUMN session_key DROP NOT NULL;
        CREATE UNIQUE INDEX IF NOT EXISTS lastfm_discord_id_key ON lastfm (discord_id);
        CREATE UNIQUE INDEX IF NOT EXISTS lastfm_user_id_key ON lastfm (user_id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS lastfm_reactions (
    guild_id BIGINT PRIMARY KEY,
    upvote TEXT,
    downvote TEXT
);

CREATE TABLE IF NOT EXISTS level_settings (
    guild_id BIGINT PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    stack_roles BOOLEAN NOT NULL DEFAULT TRUE,
    message_mode TEXT NOT NULL DEFAULT 'channel',
    xp_rate REAL NOT NULL DEFAULT 1.0,
    levelup_message TEXT,
    leaderboard_title TEXT
);

CREATE TABLE IF NOT EXISTS level_roles (
    guild_id BIGINT,
    level INTEGER NOT NULL,
    role_id BIGINT NOT NULL,
    PRIMARY KEY (guild_id, level)
);

CREATE TABLE IF NOT EXISTS level_ignored (
    guild_id BIGINT,
    target_id BIGINT NOT NULL,
    target_type TEXT,
    PRIMARY KEY (guild_id, target_id)
);

CREATE TABLE IF NOT EXISTS level_users (
    guild_id BIGINT,
    user_id BIGINT,
    xp BIGINT NOT NULL DEFAULT 0,
    level INTEGER NOT NULL DEFAULT 0,
    messages INTEGER NOT NULL DEFAULT 0,
    last_message_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (guild_id, user_id)
);

CREATE INDEX IF NOT EXISTS level_users_guild_xp_idx ON level_users (guild_id, xp DESC);

CREATE TABLE IF NOT EXISTS level_notify_optout (
    guild_id BIGINT,
    user_id BIGINT,
    PRIMARY KEY (guild_id, user_id)
);

CREATE TABLE IF NOT EXISTS giveaways (
    id BIGSERIAL PRIMARY KEY,
    guild_id BIGINT NOT NULL,
    channel_id BIGINT NOT NULL,
    message_id BIGINT NOT NULL UNIQUE,
    host_ids BIGINT[] NOT NULL DEFAULT '{}',
    prize TEXT NOT NULL,
    description TEXT,
    winners INTEGER NOT NULL DEFAULT 1,
    ends_at TIMESTAMP WITH TIME ZONE NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    color BIGINT,
    image_url TEXT,
    thumbnail_url TEXT,
    required_role_ids BIGINT[] NOT NULL DEFAULT '{}',
    award_role_ids BIGINT[] NOT NULL DEFAULT '{}',
    min_level INTEGER,
    max_level INTEGER,
    min_account_age_days INTEGER,
min_stay_days        INTEGER,
winner_ids           BIGINT[] NOT NULL DEFAULT '{}',
created_by           BIGINT,
ended_at             TIMESTAMPTZ,
created_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS giveaways_guild_status_idx ON giveaways (guild_id, status);
CREATE INDEX IF NOT EXISTS giveaways_status_ends_idx ON giveaways (status, ends_at);

CREATE TABLE IF NOT EXISTS giveaway_entries (
giveaway_id BIGINT,
user_id     BIGINT,
PRIMARY KEY (giveaway_id, user_id)
);

CREATE TABLE IF NOT EXISTS level_settings (
guild_id          BIGINT PRIMARY KEY,
enabled           BOOLEAN NOT NULL DEFAULT FALSE,
stack_roles       BOOLEAN NOT NULL DEFAULT TRUE,
message_mode      TEXT NOT NULL DEFAULT 'channel',   -- channel | pm | context | none
xp_rate           REAL NOT NULL DEFAULT 1.0,
levelup_message   TEXT,
leaderboard_title TEXT
);

CREATE TABLE IF NOT EXISTS level_users (
guild_id        BIGINT,
user_id         BIGINT,
xp              BIGINT NOT NULL DEFAULT 0,
level           INTEGER NOT NULL DEFAULT 0,
messages        INTEGER NOT NULL DEFAULT 0,
last_message_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
PRIMARY KEY (guild_id, user_id)
);

CREATE INDEX IF NOT EXISTS level_users_guild_xp_idx ON level_users (guild_id, xp DESC);

CREATE TABLE IF NOT EXISTS level_roles (
guild_id BIGINT,
level    INTEGER NOT NULL,
role_id  BIGINT NOT NULL,
PRIMARY KEY (guild_id, level)
);

CREATE TABLE IF NOT EXISTS level_ignored (
guild_id    BIGINT,
target_id   BIGINT NOT NULL,
target_type TEXT,
PRIMARY KEY (guild_id, target_id)
);

CREATE TABLE IF NOT EXISTS level_notify_optout (
guild_id BIGINT,
user_id  BIGINT,
PRIMARY KEY (guild_id, user_id)
);

-- Older drafts of this package created level_ignored with a "kind" column.
-- Normalize such a table to the live column name so the code can always read
-- target_type. Safe when the column already exists (or the table is fresh).
DO $$
BEGIN
IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name = 'level_ignored'
      AND column_name = 'kind'
) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = current_schema()
      AND table_name = 'level_ignored'
      AND column_name = 'target_type'
) THEN
    ALTER TABLE level_ignored RENAME COLUMN kind TO target_type;
END IF;
END $$;


-- Starboard configuration, ignored targets, unique voters, and posted highlights.
CREATE TABLE IF NOT EXISTS starboard_settings (
guild_id BIGINT PRIMARY KEY,
channel_id BIGINT,
emoji TEXT NOT NULL DEFAULT '⭐',
threshold INTEGER NOT NULL DEFAULT 3 CHECK (threshold BETWEEN 1 AND 100),
enabled BOOLEAN NOT NULL DEFAULT FALSE,
jumpurl BOOLEAN NOT NULL DEFAULT TRUE,
selfstar BOOLEAN NOT NULL DEFAULT FALSE,
timestamp BOOLEAN NOT NULL DEFAULT TRUE,
attachments BOOLEAN NOT NULL DEFAULT TRUE,
color BIGINT
);

CREATE TABLE IF NOT EXISTS starboard_ignores (
guild_id BIGINT NOT NULL,
target_id BIGINT NOT NULL,
target_type TEXT NOT NULL CHECK (target_type IN ('channel', 'member', 'role')),
PRIMARY KEY (guild_id, target_id, target_type)
);

CREATE TABLE IF NOT EXISTS starboard_votes (
guild_id BIGINT NOT NULL,
channel_id BIGINT NOT NULL,
message_id BIGINT NOT NULL,
user_id BIGINT NOT NULL,
PRIMARY KEY (guild_id, channel_id, message_id, user_id)
);
CREATE INDEX IF NOT EXISTS starboard_votes_message_idx ON starboard_votes (guild_id, channel_id, message_id);

CREATE TABLE IF NOT EXISTS starboard_posts (
guild_id BIGINT NOT NULL,
channel_id BIGINT NOT NULL,
message_id BIGINT NOT NULL,
board_message_id BIGINT,
star_count INTEGER NOT NULL DEFAULT 0,
PRIMARY KEY (guild_id, channel_id, message_id)
);

-- Fun module: the servers juul
CREATE TABLE IF NOT EXISTS juul (
    guild_id BIGINT PRIMARY KEY,
    holder_id BIGINT,
    hits BIGINT NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    flavor TEXT NOT NULL DEFAULT 'mint'
);

CREATE TABLE IF NOT EXISTS juul_hits (
    guild_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    hits BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (guild_id, user_id)
);

-- Fun module: per-guild tags
CREATE TABLE IF NOT EXISTS tags (
    guild_id BIGINT NOT NULL,
    name TEXT NOT NULL,
    content TEXT NOT NULL,
    author_id BIGINT,
    uses INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (guild_id, name)
);

-- Fun module: tic-tac-toe scoreboard
CREATE TABLE IF NOT EXISTS tictactoe_stats (
    user_id BIGINT PRIMARY KEY,
    wins INTEGER NOT NULL DEFAULT 0,
    losses INTEGER NOT NULL DEFAULT 0,
    draws INTEGER NOT NULL DEFAULT 0
);

-- Integrations: Roblox account links
CREATE TABLE IF NOT EXISTS roblox_links (
    discord_id BIGINT PRIMARY KEY,
    roblox_id BIGINT NOT NULL,
    roblox_username TEXT NOT NULL,
    linked_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Server module: repeating messages
CREATE TABLE IF NOT EXISTS server_timers (
    id BIGSERIAL PRIMARY KEY,
    guild_id BIGINT NOT NULL,
    channel_id BIGINT NOT NULL,
    interval_seconds INTEGER NOT NULL,
    message TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    next_run TIMESTAMP WITH TIME ZONE NOT NULL,
    created_by BIGINT
);

CREATE TABLE IF NOT EXISTS server_timer_settings (
    guild_id BIGINT PRIMARY KEY,
    require_activity BOOLEAN NOT NULL DEFAULT FALSE
);

-- Framework: per-command invocation counters
CREATE TABLE IF NOT EXISTS command_usage (
    command TEXT PRIMARY KEY,
    count BIGINT NOT NULL DEFAULT 1
);
