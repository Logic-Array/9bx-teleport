#!/usr/bin/env python3
"""
Orbit branding: bake the self-hosted server, public key and app name into the
RustDesk compile-time config.

WHY THIS SCRIPT EXISTS
----------------------
The constants that decide the default rendezvous/relay server, the server public
key and the product name live in `libs/hbb_common/src/config.rs`, which is a git
SUBMODULE pointing at the upstream repo `rustdesk/hbb_common`. We cannot commit
edits to a submodule's working tree from this fork, so instead we commit THIS
script and run it after `git submodule update --init` and before `cargo`/flutter
build. It rewrites the four relevant constants in place.

The edit is idempotent: running it twice is a no-op, and it fails loudly if an
expected anchor is missing (e.g. upstream renamed a constant), so a silently
un-branded build is impossible.

Usage:
    python orbit/patch_hbb_config.py            # apply (run from repo root)
    python orbit/patch_hbb_config.py --check     # verify only, non-zero if not applied
"""
import re
import sys
import pathlib

# ---- Orbit values -----------------------------------------------------------
APP_NAME = "Orbit"
# Single self-hosted host; DNS connect.orbit.bd -> 103.107.160.27 (owner adds it).
# Same host serves rendezvous (hbbs) and relay (hbbr). API is derived from it.
SERVER = "connect.orbit.bd"
PUB_KEY = "ubNfSsoZBoffk4fOCsLiPvuv+ExFWy6ErfIHKIBvrZE="
# ----------------------------------------------------------------------------

CONFIG = pathlib.Path("libs/hbb_common/src/config.rs")

# Each rule: (name, regex that matches the upstream line, replacement line,
#             regex that matches the already-patched line).
RULES = [
    (
        "PROD_RENDEZVOUS_SERVER default (drives rendezvous + derived API server)",
        re.compile(r'pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new\("[^"]*"\.to_owned\(\)\);'),
        f'pub static ref PROD_RENDEZVOUS_SERVER: RwLock<String> = RwLock::new("{SERVER}".to_owned());',
    ),
    (
        "APP_NAME default (product name; auto-replaces 'RustDesk' in all UI strings)",
        re.compile(r'pub static ref APP_NAME: RwLock<String> = RwLock::new\("[^"]*"\.to_owned\(\)\);'),
        f'pub static ref APP_NAME: RwLock<String> = RwLock::new("{APP_NAME}".to_owned());',
    ),
    (
        "RENDEZVOUS_SERVERS fallback list",
        re.compile(r'pub const RENDEZVOUS_SERVERS: &\[&str\] = &\[[^\]]*\];'),
        f'pub const RENDEZVOUS_SERVERS: &[&str] = &["{SERVER}"];',
    ),
    (
        "RS_PUB_KEY (server public key)",
        re.compile(r'pub const RS_PUB_KEY: &str = "[^"]*";'),
        f'pub const RS_PUB_KEY: &str = "{PUB_KEY}";',
    ),
]


def main() -> int:
    check_only = "--check" in sys.argv
    if not CONFIG.exists():
        print(f"ERROR: {CONFIG} not found. Run from the repo root after "
              f"'git submodule update --init libs/hbb_common'.", file=sys.stderr)
        return 2

    text = CONFIG.read_text(encoding="utf-8")
    changed = False
    for name, pattern, replacement in RULES:
        if replacement in text:
            print(f"  ok (already applied): {name}")
            continue
        new_text, n = pattern.subn(replacement, text, count=1)
        if n == 0:
            print(f"ERROR: could not find the config line to patch: {name}\n"
                  f"       Upstream hbb_common may have changed; update "
                  f"orbit/patch_hbb_config.py.", file=sys.stderr)
            return 3
        text = new_text
        changed = True
        print(f"  patched: {name}")

    if check_only:
        if changed:
            print("NOT fully applied (run without --check to apply).", file=sys.stderr)
            return 1
        print("Orbit config already baked in.")
        return 0

    if changed:
        CONFIG.write_text(text, encoding="utf-8")
        print(f"Wrote {CONFIG}")
    else:
        print("No changes needed.")
    print(f"Orbit config baked: APP_NAME={APP_NAME}, server={SERVER}, key set.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
