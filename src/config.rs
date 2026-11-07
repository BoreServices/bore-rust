use std::env;

pub const DEFAULT_PREFIX: &str = ",";
pub const EMBED_COLOR: u32 = 0x7dcdfc;
/// Placeholder the Python bot uses when a user has no avatar.
pub const NO_AVATAR: &str = "https://none.none";

pub struct Config {
    pub token: String,
    pub database_url: Option<String>,
}

impl Config {
    pub fn load() -> Self {
        load_dotenv();
        let token = env::var("BOT_TOKEN").expect("BOT_TOKEN is not set");
        Self {
            token,
            database_url: env::var("DATABASE_URL").ok(),
        }
    }
}

/// Tiny .env reader (no dependency). Real environment wins over file values.
fn load_dotenv() {
    let Ok(content) = std::fs::read_to_string(".env") else {
        return;
    };
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((k, v)) = line.split_once('=') {
            let k = k.trim();
            if env::var(k).is_err() {
                env::set_var(k, v.trim().trim_matches(['"', '\'']));
            }
        }
    }
}
