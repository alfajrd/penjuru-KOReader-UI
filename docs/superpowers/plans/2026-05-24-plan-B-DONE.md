# Plan B · DONE — 2026-05-24

## What's working

All six home-screen modules render in the emulator with real KOReader data, composed into the spec's two-column layout:

- **currently reading** (lead) — Macbeth, headline + Shakespeare byline + most-recent "sleep that knits up..." highlight as pull quote + 42% progress bar
- **today's ledger** — reading minutes / pages / streak / year-finished (zeros until statistics.sqlite3 has real sessions)
- **the almanac** — day of year, ISO week, NOAA-computed sunrise/sunset for Jakarta, synodic moon phase
- **on the desk** — Walden (78%) + Moby Dick (15%) cover thumbnails with % bands; 3 empty slots in 5-slot grid
- **newly catalogued** — Austen + Lovecraft as 2 tap rows (recently added, no .sdr yet)
- **recent highlights** — top 3 Macbeth highlights sorted by datetime desc

## Verification

- **53 specs pass** via `./scripts/run-specs.sh` (12 pen_data + 9 pen_almanac + 5 pen_install_date + 7 pen_dates + 5 pen_fonts + 4 pen_style + 1 pen_widgets smoke)
- **Emulator boots cleanly** with the plugin loaded and the new home screen renders end-to-end (manual visual verification by user pending)
- Real KOReader data flowing — pre-populated `.sdr/metadata.epub.lua` sidecars + `history.lua` confirmed reading through to widget output

## Architecture summary

| File | Role |
|---|---|
| `pen_widgets.lua` | rule / dashed_rule / dotted_rule (custom widget) / section_head / spaced_row |
| `pen_data.lua` | history.lua, .sdr metadata, statistics.sqlite3, recursive book listing |
| `pen_almanac.lua` | NOAA sun_times, synodic moon_phase, format_hhmm |
| `pen_install_date.lua` | vol/no math + lazy-initialized install timestamp |
| `home_modules/module_*.lua` (×6) | UI-only; one `M.render(content_width)` each |
| `pen_homescreen.lua` | composes masthead + dateline + module grid |

Each module touches data only via `pen_data`. Each pulls visual tokens only via `pen_style`. Shared widget primitives only via `pen_widgets`. Clean separation; modules can be reordered or removed independently.

## Bugs caught during execution

- **lfs.dir pattern mismatch** in `Data.list_books_in` — KOReader's bundled lfs returns `iter, dir_obj` tuple from `pcall(lfs.dir, d)`; only `iter` was being captured, breaking the for-loop. Fixed to `for entry in iter, dir_obj do`.
- **ljsqlite3 cdata return** in `Data.read_today_stats` — SUM/COUNT aggregates return LuaJIT cdata integers, not Lua numbers; `math.floor` crashed on them. Wrapped all `scalar()` outputs in `tonumber()`.

Both bugs surfaced in real-environment emulator runs, not in spec tests — reinforcing that "specs pass" is necessary but not sufficient and the smoke-test phase matters.

## Carry-overs to Plan C

- **Cover thumbnails** have % bands rendered BELOW the cover (not overlaid), because KOReader's widget set lacks an absolute-position container. Build a `PositionedOverlayWidget` in Plan C.
- **Catalogue scan happens synchronously on render** — for a library with thousands of files this could lag the first frame. Async or cached scan deferred.
- **Tap routing not wired**: spec says tapping a highlight opens the book to that page, and tapping a newly-catalogued row opens that book. Plan B renders the widgets; the tap handlers are TODO. Belongs with the bottom-nav tap routing work in Plan C.
- **Today's ledger shows zeros** because no real reading sessions exist in statistics.sqlite3. Once you read a book in the emulator (or on the Kindle), the numbers populate naturally — no additional code needed.

## What's deferred to Plan C

- Persistent top status bar (clock / wi-fi / light / disk / battery)
- 7-cell paginated bottom nav with manga / books / home / wi-fi / games / stats / brightness / power / search / library
- Tap routing for highlights and catalogue rows
- Cover overlay polish

## What's deferred to Plan D

- Settings menu (Menu → Tools → penjuru sub-tree)
- Reading goal / location / newly-threshold / catalogue dirs config
- On-Kindle install (build script, install instructions)
- Visible Acknowledgments to Doctor Hetfield in README

## Plan B commit log

| Commit | Subject |
|---|---|
| `988dfb5` | docs: Plan B implementation plan |
| `03bf5e0` | feat(widgets): shared primitives for rules, section heads, spaced rows |
| `e09d356` | feat(data): pen_data — KOReader data-access layer (TDD) |
| `22cb68d` | feat(almanac): sunrise/sunset via NOAA solar formula |
| `7b638f9` | feat(almanac): moon phase via synodic cycle count |
| `959380a` | feat(home): module_almanac renders day-of-year/week/sun/moon |
| `3d5e06c` | feat(home): pen_install_date computes vol/no for dateline |
| `e5719ae` | feat(data): read_today_stats from statistics.sqlite3 |
| `089aa33` | feat(home): module_ledger renders reading/pages/streak/year sidebar |
| `6cba007` | feat(home): currently-reading lead module (B.3.1-3) |
| `5907110` | feat(home): on-the-desk 5-cover module (B.4.1-3) |
| `93fe92c` | feat(home): newly-catalogued module (B.5.1-2) |
| `5cd2893` | feat(home): recent-highlights module (B.6.1-2) |
| `daedcc6` | feat(home): compose all six modules in two-column layout |
