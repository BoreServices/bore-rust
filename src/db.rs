use std::collections::HashMap;

use sqlx::{PgPool, Row};
use twilight_model::id::{Id, marker::GuildMarker};

/// The exact schema file from the Python bot, run verbatim on boot.
const SCHEMA: &str = include_str!("../schema.sql");

pub async fn connect(url: &str) -> Result<PgPool, sqlx::Error> {
    let pool = sqlx::PgPool::connect(url).await?;
    sqlx::raw_sql(SCHEMA).execute(&pool).await?;
    eprintln!("Database connection established, schema loaded");
    Ok(pool)
}

/// Per-guild prefixes from the `prefix` table (mirrors the Python bot cache).
pub async fn load_prefixes(pool: &PgPool) -> HashMap<Id<GuildMarker>, String> {
    let rows = sqlx::query("SELECT guild_id, prefix FROM prefix")
        .fetch_all(pool)
        .await
        .unwrap_or_default();
    rows.iter()
        .filter_map(|r| {
            Some((
                Id::new(r.get::<i64, _>("guild_id") as u64),
                r.get::<String, _>("prefix"),
            ))
        })
        .collect()
}
