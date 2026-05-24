# Plan D · DONE — 2026-05-24 (v1.0.0)

## What's working

- **`pen_patches.lua` removed** (legacy SimpleUI chrome injection); boot is clean — no more `TOTAL_H` / `scheduleRefresh` soft-fail errors
- **`pen_menu.lua` replaced** with a 3-item stub (Open home / Settings / About); old 239KB SimpleUI menu stashed at `.old_simpleui`
- **`pen_settings_defaults.lua`** centralizes default values so every module sees a complete settings table via `__index` fallback
- **Settings sub-tree:** annual reading goal (SpinWidget), location lat/lon/tz (InputDialog), newly-catalogued threshold (SpinWidget)
- **`module_catalogued`** reads threshold from settings (was hardcoded 30)
- **`stats` action** broadcasts `ShowReaderStatistics` event (real Statistics plugin handles it)
- **`search` action** opens FileManager + broadcasts `ShowFileSearch`
- **`pen_book_open`** helper opens books and (deferred 0.5s) seeks to a page via `GotoPage` event
- **Tap on a highlight** now seeks to the highlighted page (was just opening the book at last-read)
- **Hold-on-tab** shows a real read-only roster of every tab on every page
- **`build.sh`** packages plugin as `dist/penjuru.koplugin.zip` (804K) excluding `spec/`, `.old_simpleui` stashes, `.DS_Store`, `.git`
- **`INSTALL.md`** end-user install guide (jailbreak prereq, unzip path, enable steps, troubleshooting)
- **`README.md`** has visible Acknowledgments section crediting Doctor Hetfield, KOReader, and bundled fonts
- **v1.0.0 tagged** and pushed; GitHub release published with the zip attached
- **75 specs pass** via `./scripts/run-specs.sh`

## v1.0 carry-overs / known limitations

- **Bars persist only on the home screen** — file-browser and reader views keep KOReader's stock chrome. Inheriting SimpleUI's monkey-patches for "bars everywhere" was deemed out of scope for v1.0; the home tab brings you back to the bars whenever you need to navigate.
- **Tab-roster GUI editor** — read-only on hold; edit via `G_reader_settings.penjuru.bottombar.pages` directly for v1.0
- **Async catalogue scan** — synchronous on render; for very large libraries the first frame may lag
- **Cover %-overlay polish** — % band sits below the cover, not overlaid
- **Module visibility / order / scale settings UI** — defaults are sensible; advanced reordering deferred
- **Top-bar layout editor** — defaults work; left/right item moves deferred
- **Plenty of legacy SimpleUI methods** in `pen_core.lua` / `main.lua` (e.g. `navigate`, `rebuildAllNavbars`, `setActiveAndRefreshFM`) reference functions that don't exist on our new minimal bars. They're not triggered at boot but may fail if specific event-driven code paths run. Plan E (if ever) does a deep cleanup of those.

## What's deferred to a potential v1.1

- Any of the v1.0 carry-overs above
- Custom icon-pack support (drop .svg / pack.lua into a folder, hot-swap from settings)
- Per-book reading goal / collections support
- Bars on file-browser and reader views (rip out remaining legacy glue, build a proper chrome injector)

## Plan D commit log

| Commit | Subject |
|---|---|
| `b55f652` | docs: Plan D implementation plan |
| `9bf7527` | chore: rip pen_patches — legacy SimpleUI chrome injection |
| `ccf8bb0` | chore: replace 239KB SimpleUI menu with 3-item stub + defaults |
| `8725ab0` | feat(settings): year goal + location + newly threshold |
| `43f5058` | feat(actions): wire stats and search to KOReader events |
| `3c95878` | feat(home): tap a highlight opens the book AND seeks to its page |
| `57460f5` | feat(chrome): hold-on-tab shows current tab roster (read-only) |
| `859b70b` | feat(build): build.sh packages plugin as dist/penjuru.koplugin.zip |
| `01d6c65` | docs: INSTALL.md — end-user install guide for Kindle |
| `92508f0` | docs: add Acknowledgments crediting Doctor Hetfield, KOReader, fonts |
