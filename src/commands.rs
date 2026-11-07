use std::time::{Instant, SystemTime, UNIX_EPOCH};

use twilight_model::{
    channel::Message,
    channel::message::embed::{
        Embed, EmbedAuthor, EmbedField, EmbedFooter, EmbedThumbnail,
    },
    id::{Id, marker::UserMarker},
    user::User,
};

use crate::{
    Bot,
    config::{EMBED_COLOR, NO_AVATAR},
    format,
};

/// Number of top-level commands (the Python footer counts all non-owner ones).
pub const COMMAND_COUNT: usize = 2;

const PINGS: &str = include_str!("../data/pings.txt");

/// Mirrors `information.ping` (aliases: latency, websocket).
pub async fn ping(bot: &Bot, message: &Message) {
    let lines: Vec<&str> = PINGS.lines().collect();
    let seed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.subsec_nanos() as usize)
        .unwrap_or(0);
    let randomping = lines[seed % lines.len()];
    let start = Instant::now();
    let latency_ms = bot.latency_ms();
    let Ok(response) = bot
        .http
        .create_message(message.channel_id)
        .content("ping...")
        .await
    else {
        eprintln!("ping: failed to send placeholder message");
        return;
    };
    let Ok(created) = response.model().await else {
        eprintln!("ping: failed to parse placeholder message");
        return;
    };
    let edit_ms = (start.elapsed().as_secs_f64() * 1000.0 * 10.0).round() / 10.0;
    let content = format!("it took `{latency_ms}ms` to ping **{randomping}** (edit: `{edit_ms:.1}ms`)");
    if let Err(e) = bot
        .http
        .update_message(message.channel_id, created.id)
        .content(Some(&content))
        .await
    {
        eprintln!("ping: edit failed: {e:?}");
    }
}

/// Mirrors `information.botinfo` (aliases: about, bi).
pub async fn botinfo(bot: &Bot, message: &Message) {
    let guilds = bot.cache.iter().guilds().count();
    let users = bot.cache.iter().users().count();
    let author = &message.author;
    let bot_user = bot.bot_user.read().expect("bot_user lock").clone();
    let embed = Embed {
        author: Some(EmbedAuthor {
            icon_url: Some(avatar_url(author.id, &author.avatar)),
            name: display_name(author).to_owned(),
            proxy_icon_url: None,
            url: None,
        }),
        color: Some(EMBED_COLOR),
        description: None,
        fields: vec![
            EmbedField {
                inline: true,
                name: "Bot".to_owned(),
                value: format!(
                    "Users: **{}** \nServers: **{}** \nPing: **{}ms**",
                    comma(users),
                    comma(guilds),
                    bot.latency_ms()
                ),
            },
            EmbedField {
                inline: true,
                name: "Info".to_owned(),
                value: format!(
                    "RAM: **{}** \nCPU: **{}%** \nBooted: **{}**",
                    format::format_size(format::ram_bytes()),
                    format::cpu_percent().round() as u64,
                    format::booted_relative(bot.boot_unix)
                ),
            },
        ],
        footer: Some(EmbedFooter {
            icon_url: None,
            proxy_icon_url: None,
            text: format!("Commands: {COMMAND_COUNT} | lines: {}", comma(bot.linecount)),
        }),
        image: None,
        kind: "rich".to_owned(),
        provider: None,
        thumbnail: Some(EmbedThumbnail {
            height: None,
            proxy_url: None,
            url: bot_user
                .as_ref()
                .map(|u| avatar_url(u.id, &u.avatar))
                .unwrap_or_else(|| NO_AVATAR.to_owned()),
            width: None,
        }),
        timestamp: None,
        title: None,
        url: None,
        video: None,
    };
    if let Err(e) = bot
        .http
        .create_message(message.channel_id)
        .embeds(&[embed])
        .await
    {
        eprintln!("botinfo: send failed: {e:?}");
    }
}

/// discord.py's display_name: global display name, else username.
fn display_name(user: &User) -> &str {
    user.global_name.as_deref().unwrap_or(&user.name)
}

/// Mirrors `display_avatar.url`, falling back to the Python placeholder.
fn avatar_url(id: Id<UserMarker>, avatar: &Option<twilight_model::util::ImageHash>) -> String {
    match avatar {
        Some(hash) => format!("https://cdn.discordapp.com/avatars/{}/{hash}.png?size=1024", id.get()),
        None => NO_AVATAR.to_owned(),
    }
}

/// `f"{n:,}"` from the Python bot.
fn comma(n: usize) -> String {
    let mut out = String::new();
    for (i, c) in n.to_string().chars().rev().enumerate() {
        if i > 0 && i % 3 == 0 {
            out.push(',');
        }
        out.push(c);
    }
    out.chars().rev().collect()
}
