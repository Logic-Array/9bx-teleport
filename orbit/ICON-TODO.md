# Orbit icon / logo swap — TODO

The code branding (name, server, key) is done. The icon/logo artwork is **not**
swapped yet — no Orbit mark was available. Replace the files below with the Orbit
logo (keep the same filename, path, format and pixel sizes), then rebuild.

## Priority 1 — Windows (what the Windows build ships)
| File | Purpose | Required sizes |
|------|---------|----------------|
| `flutter/windows/runner/resources/app_icon.ico` | Main app/exe icon (taskbar, title bar) | multi-size .ico: 16, 32, 48, 256 px |
| `res/icon.ico` | winres/portable-packer exe icon | multi-size .ico: 16, 32, 48, 256 px |
| `res/tray-icon.ico` | Windows system-tray icon | 16, 32 px (multi-size .ico) |
| `flutter/assets/icon.svg` | In-app logo (home page, About dialog) | vector SVG |

## Priority 2 — Shared source art / Linux
| File | Purpose |
|------|---------|
| `res/icon.png` | Master PNG the icons are generated from |
| `res/32x32.png`, `res/64x64.png`, `res/128x128.png`, `res/128x128@2x.png` | Linux / tray PNG sizes |
| `res/logo.svg`, `res/logo-header.svg`, `res/scalable.svg`, `res/design.svg` | Linux desktop / branding SVGs |
| `res/rustdesk-banner.svg` | Banner art |

## Priority 3 — macOS (only if a mac build is produced)
| File | Purpose |
|------|---------|
| `res/mac-icon.png` | macOS .icns source |
| `res/mac-tray-dark-x2.png`, `res/mac-tray-light-x2.png` | macOS menu-bar tray icons |

## Notes
- `res/gen_icon.sh` regenerates the PNG/ICO set from a source image — useful once
  the Orbit master art exists.
- Do **not** rename any of these files; the build and `Runner.rc`
  (`IDI_APP_ICON ICON "resources\app_icon.ico"`) reference them by exact path.
