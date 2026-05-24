# Plan A · DONE — 2026-05-24

## What's working

- KOReader emulator builds and runs on macOS (`~/Developer/koreader`, pinned to `v2026.03`)
- `penjuru.koplugin/` is wired into the emulator via symlink at `~/Developer/koreader/plugins/penjuru.koplugin`
- Plugin loads cleanly in the emulator with no module-level errors
- Home screen renders: masthead (`penjuru pikiran` in Syne Mono 76px) → tagline (Plex Mono 20px) → 2.5px dashed rule → dateline row (vol / date / edition) → 1.5px rule → italic body placeholder
- Bundled fonts (IBM Plex Mono Regular/Italic/Medium/Bold · Syne Mono · VT323) load via `pen_fonts` with cached `Face` lookup
- Token system in `pen_style.lua`: colors (greyscale palette), font factories per role, size scale (21 named sizes), rule weights, spacing gaps
- Pure-data date helpers in `pen_dates`: `edition_for_hour`, `day_of_year`, `iso_week` (with pure-Lua fallback), `format_long`, `month_name`
- Legacy-API shim on `pen_style` lets SimpleUI-derived files (pen_titlebar, pen_bottombar, pen_menu, etc.) continue loading via no-op stubs until rewritten in Plans B/C/D
- 16 specs pass via `./scripts/run-specs.sh` (5 pen_fonts + 4 pen_style + 7 pen_dates)
- Repo public at https://github.com/alfajrd/penjuru-KOReader-UI

## How to verify locally

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh         # 16/16 should pass

export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader && bash ./kodev run
# In the emulator: tap the "Home" tab in the penjuru bottom bar
# Expect: full-screen white widget with the masthead skeleton centered
```

## Known limitations carried to Plan B

- **Dotted rules** — KOReader's `LineWidget` doesn't support `style = "dotted"`. Dateline rule currently falls back to solid grey (`Style.colors.rule`). Real dotted rules need a custom widget in Plan B.
- **Vol/No in dateline** is a placeholder `vol. i · no. 1`. Spec calls for `vol = years since install + 1`, `no = days since install + 1`. Needs install-date storage in Plan B.
- **Other pen_*.lua files** (pen_titlebar, pen_bottombar, pen_menu, pen_quickactions, pen_topbar, pen_patches) are still SimpleUI-derived and use the legacy-API shim. Any interactive feature outside the home screen may misbehave until rewritten.

## What's NOT yet built (Plan B picks this up)

- Currently-reading module (lead story with cover-less headline, byline, pull quote, body, progress)
- Today's ledger module (reading min, pages, streak, year goal)
- The almanac module (day of year, week no., sunrise/sunset, moon phase)
- On the desk module (5 covers of in-progress books with % overlay)
- Newly catalogued module (recently-added unstarted books)
- Recent highlights module (3 most-recent annotations from user data)

## What's deferred to Plan C

- Persistent top status bar (clock/wifi/light/disk/battery)
- 7-cell paginated bottom nav with the manga / books / home / wi-fi / games / stats / brightness / power / search / library roster

## What's deferred to Plan D

- Settings menu (Menu → Tools → penjuru sub-tree)
- Reading goal / location / newly-threshold config
- On-Kindle install (build script, .koplugin folder layout, INSTALL.md for end users)
- Visible Acknowledgments section in README crediting Doctor Hetfield (simpleui.koplugin)

## Plan A commit log (Phase 0 → Phase 4)

| Commit | Subject |
|---|---|
| `176a485` | docs: record KOReader emulator setup |
| `26503c6` | feat: vendor simpleui.koplugin source as starting point |
| `ef959c8` | feat: rename plugin to penjuru, add MIT LICENSE with SimpleUI attribution |
| `be505b7` | verify: plugin loads in koreader emulator via symlink (no load errors) |
| `0f4a0fb` | refactor: remove simpleui modules and features out of scope for penjuru v1 |
| `06d9d59` | refactor: rename sui_* -> pen_*, SUI -> PEN, simpleui -> penjuru |
| `414cb08` | feat: bundle IBM Plex Mono, Syne Mono, VT323 TTFs |
| `36df29e` | feat(fonts): pen_fonts helper maps roles to bundled TTFs |
| `b2854c1` | feat(style): single source of truth for colors, fonts, sizes, rules |
| `8a962d6` | fix(style): legacy-API shim so SimpleUI-derived files keep loading |
| `414f15d` | feat(home): masthead-only placeholder home screen (Task 3.1) |
| `cfc8dd6` | feat(home): add dateline + rules to placeholder home |
