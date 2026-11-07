# bore-rust

Rust rewrite of `bots/bore` in **Twilight 0.17**. Framework plus two commands so far.

## Run

```bash
cp .env.example .env   # fill in BOT_TOKEN (and optionally DATABASE_URL)
cargo run
```

`BOT_TOKEN` is required. `DATABASE_URL` is optional: with it, the bot runs the
shared schema (`schema.sql`, copied verbatim from the Python bot) and loads the
per-guild `prefix` table on boot. Without it, every guild uses the default
prefix `,`.

## What's ported

- Framework: Twilight single-shard gateway, in-memory cache, prefix routing
  (guild prefix from Postgres, mention prefix, case-insensitive names),
  intents mirroring `_intents()` in `base/bore.py`, bot-authored messages ignored.
- `,ping` (aliases `latency`, `websocket`): placeholder send, then edit with
  gateway latency and a random line from `data/pings.txt` (copied verbatim).
- `,botinfo` (aliases `about`, `bi`): user/server counts from cache, RAM/CPU
  from `/proc`, boot time, same embed fields and footer format as Python.

## Not ported yet

Everything else in `bots/bore` (39k lines). The remaining cogs are being ported
in order; the framework (shard loop, prefix dispatch, cache, DB pool) is the
stable base they hang off. Dashboard HTTP endpoints (`/stats`, `/status`,
`/servers`, `/shards`, `/commands` from `main.py`) are not ported yet either.
