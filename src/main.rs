mod commands;
mod config;
mod db;
mod format;

use std::{
    collections::HashMap,
    sync::{
        RwLock,
        atomic::{AtomicU64, Ordering},
    },
    time::{Instant, SystemTime, UNIX_EPOCH},
};

use twilight_cache_inmemory::InMemoryCache;
use twilight_gateway::{EventTypeFlags, Intents, Shard, ShardId, StreamExt as _};
use twilight_model::{
    channel::Message,
    gateway::event::Event,
    id::{Id, marker::GuildMarker},
    user::CurrentUser,
};

use config::{Config, DEFAULT_PREFIX};

/// Framework state. Ported from base/bore.py; only the caches the framework
/// and the two ported commands actually use are kept.
pub struct Bot {
    pub http: twilight_http::Client,
    pub cache: InMemoryCache,
    /// Mirrors `bot.prefix_cache` (guild_id -> prefix).
    pub prefixes: RwLock<HashMap<Id<GuildMarker>, String>>,
    /// Ready user, for mention-prefix parsing and avatar lookups.
    pub bot_user: RwLock<Option<CurrentUser>>,
    /// Mirrors `bot._uptime`; boot is set at startup like `setup_hook`.
    pub boot: Instant,
    pub boot_unix: u64,
    /// Mirrors `bot.linecount` (Rust sources only, counted once at startup).
    pub linecount: usize,
    latency_ms: AtomicU64,
}

impl Bot {
    /// Mirrors `bot.ping`: most recent gateway heartbeat latency in ms.
    fn latency_ms(&self) -> u64 {
        self.latency_ms.load(Ordering::Relaxed)
    }

    fn set_latency(&self, shard: &Shard) {
        let ms = shard
            .latency()
            .recent()
            .first()
            .map(|d| (d.as_secs_f64() * 1000.0).round() as u64)
            .unwrap_or(0);
        self.latency_ms.store(ms, Ordering::Relaxed);
    }
}

fn linecount() -> usize {
    let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("src");
    fn walk(dir: &std::path::Path) -> usize {
        let Ok(entries) = std::fs::read_dir(dir) else {
            return 0;
        };
        let mut total = 0;
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                total += walk(&path);
            } else if path.extension().is_some_and(|e| e == "rs") {
                if let Ok(src) = std::fs::read_to_string(&path) {
                    total += src.lines().count();
                }
            }
        }
        total
    }
    walk(&root)
}

#[tokio::main]
async fn main() {
    let cfg = Config::load();

    // Database is optional for local runs; without it every guild uses the
    // default prefix. With it the shared schema runs and prefix cache fills.
    let mut prefixes = HashMap::new();
    if let Some(url) = &cfg.database_url {
        match db::connect(url).await {
            Ok(pool) => {
                prefixes = db::load_prefixes(&pool).await;
                eprintln!("Loaded {} guild prefix(es)", prefixes.len());
            }
            Err(e) => eprintln!("Database unavailable, default prefix only: {e}"),
        }
    }

    let bot = std::sync::Arc::new(Bot {
        http: twilight_http::Client::new(cfg.token.clone()),
        cache: InMemoryCache::new(),
        prefixes: RwLock::new(prefixes),
        bot_user: RwLock::new(None),
        boot: Instant::now(),
        boot_unix: SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0),
        linecount: linecount(),
        latency_ms: AtomicU64::new(0),
    });

    // Intent set mirrors `_intents()` in base/bore.py.
    let intents = Intents::GUILDS
        | Intents::GUILD_MEMBERS
        | Intents::GUILD_MODERATION
        | Intents::GUILD_INVITES
        | Intents::GUILD_VOICE_STATES
        | Intents::GUILD_MESSAGES
        | Intents::GUILD_MESSAGE_REACTIONS
        | Intents::DIRECT_MESSAGES
        | Intents::AUTO_MODERATION_EXECUTION
        | Intents::MESSAGE_CONTENT;

    let mut shard = Shard::new(ShardId::ONE, cfg.token, intents);
    let wanted = EventTypeFlags::READY | EventTypeFlags::RESUMED | EventTypeFlags::MESSAGE_CREATE;

    while let Some(item) = shard.next_event(wanted).await {
        let Ok(event) = item else {
            eprintln!("event error: {:?}", item.unwrap_err());
            continue;
        };
        bot.cache.update(&event);
        bot.set_latency(&shard);
        match event {
            Event::Ready(ready) => {
                *bot.bot_user.write().expect("bot_user lock") = Some(ready.user);
                eprintln!("ready");
            }
            Event::MessageCreate(msg) => handle(&bot, &msg).await,
            _ => {}
        }
    }
}

/// Mirrors prefix invocation: guild prefix or comma default, or a bot mention.
/// Command matching is case-insensitive, no arguments are consumed by our two
/// commands. Bot-authored messages are ignored.
async fn handle(bot: &Bot, message: &Message) {
    if message.author.bot {
        return;
    }
    let Some(rest) = strip_prefix(bot, message, message.content.trim_start()) else {
        return;
    };
    let Some(name) = rest.split_whitespace().next() else {
        return;
    };
    match name.to_lowercase().as_str() {
        "ping" | "latency" | "websocket" => commands::ping(bot, message).await,
        "botinfo" | "about" | "bi" => commands::botinfo(bot, message).await,
        _ => {}
    }
}

fn strip_prefix<'a>(bot: &Bot, message: &Message, content: &'a str) -> Option<&'a str> {
    if let Some(me) = bot.bot_user.read().map(|u| u.as_ref().map(|c| c.id)).unwrap_or(None) {
        for form in [format!("<@{me}>"), format!("<@!{me}>")] {
            if let Some(rest) = content.strip_prefix(&form) {
                return Some(rest.trim_start());
            }
        }
    }
    let prefix = message
        .guild_id
        .and_then(|g| {
            bot.prefixes
                .read()
                .ok()
                .and_then(|map| map.get(&g).cloned())
        })
        .unwrap_or_else(|| DEFAULT_PREFIX.to_owned());
    content.strip_prefix(&prefix).map(str::trim_start)
}
