/// Mirrors `Bot.format_size` in base/bore.py.
pub fn format_size(bytes: u64) -> String {
    if bytes >= 1024 * 1024 * 1024 {
        format!("{:.2}GB", bytes as f64 / (1024f64.powi(3)))
    } else if bytes >= 1024 * 1024 {
        format!("{:.2}MB", bytes as f64 / (1024f64.powi(2)))
    } else if bytes >= 1024 {
        format!("{:.2}KB", bytes as f64 / 1024.0)
    } else {
        format!("{bytes} Bytes")
    }
}

/// Mirrors `format_dt(self.boot, style="R")`: renders as a Discord timestamp tag.
pub fn booted_relative(boot_unix: u64) -> String {
    format!("<t:{boot_unix}:R>")
}

/// Resident set size from /proc/self/status (psutil's memory_info().rss).
pub fn ram_bytes() -> u64 {
    std::fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|status| {
            status.lines().find_map(|line| {
                line.strip_prefix("VmRSS:")
                    .and_then(|v| v.split_whitespace().next())
                    .and_then(|kb| kb.parse::<u64>().ok())
                    .map(|kb| kb * 1024)
            })
        })
        .unwrap_or(0)
}

/// CPU percent since boot, like psutil's cpu_percent() with no interval.
pub fn cpu_percent() -> f64 {
    let stat = std::fs::read_to_string("/proc/self/stat").unwrap_or_default();
    // Fields after comm (in parens) start at field 3 (state); utime/stime are
    // fields 14/15, so offsets 11/12 in the tail after the last ')'.
    let Some(tail) = stat.rsplit(')').next() else {
        return 0.0;
    };
    let fields: Vec<&str> = tail.split_whitespace().collect();
    let utime: f64 = fields.get(11).and_then(|v| v.parse().ok()).unwrap_or(0.0);
    let stime: f64 = fields.get(12).and_then(|v| v.parse().ok()).unwrap_or(0.0);
    let cpu_secs = (utime + stime) / 100.0; // CLK_TCK is 100 on Linux
    let uptime: f64 = std::fs::read_to_string("/proc/uptime")
        .ok()
        .and_then(|v| v.split_whitespace().next()?.parse().ok())
        .unwrap_or(1.0);
    if uptime <= 0.0 {
        0.0
    } else {
        (cpu_secs / uptime * 100.0).min(100.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sizes() {
        assert_eq!(format_size(512), "512 Bytes");
        assert_eq!(format_size(1024), "1.00KB");
        assert_eq!(format_size(1024 * 1024), "1.00MB");
        assert_eq!(format_size(1024 * 1024 * 1024), "1.00GB");
    }

    #[test]
    fn booted_tag() {
        assert_eq!(booted_relative(1_700_000_000), "<t:1700000000:R>");
    }

    #[test]
    fn proc_fields_parse() {
        assert!(ram_bytes() > 0);
        assert!((0.0..=100.0).contains(&cpu_percent()));
    }
}
