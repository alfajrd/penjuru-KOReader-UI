# Plan C · DONE — 2026-05-24

## What's working

- **12 SVG icons** (1.6px stroke, currentColor, 24×24 viewBox) bundled at `icons/penjuru/`
- **`pen_icons`** loads icons by short name into KOReader's `IconWidget`
- **`pen_status`** reads clock / battery / wifi / frontlight / disk from KOReader device singletons, robust to missing subsystems
- **`pen_topbar`** renders the status row with left/right clusters; layout configurable via `G_reader_settings.penjuru.topbar.layout`
- **`pen_tabs`** catalog + default 2-page roster (page 1 = manga/books/home/wifi/games, page 2 = stats/brightness/power/search/library) + pagination math
- **`pen_bottombar`** renders the 7-cell paginated nav with proportional widths (10 + 16×5 + 10 = 100), active-tab top-edge bar, tap + hold gestures
- **`pen_actions`** dispatches taps to KOReader UI: home / library / wifi-toggle / brightness / power-menu / search / stats built-ins plus folder / KUAL / plugin shortcuts; all wrapped in pcall
- **Tap on a highlight** opens the book in `ReaderUI:showReader`
- **Tap on a newly-catalogued row** opens the book
- **Home screen mounts both bars** around the body (top bar full width, body in 36px padded indent, bottom bar full width)
- **75 specs pass** via `./scripts/run-specs.sh`

## Carry-overs to Plan D

- **Legacy SimpleUI glue** in `pen_patches.lua` and `main.lua` still calls the OLD `Topbar`/`Bottombar` singletons that we just replaced. The plugin still loads (calls fail soft via pcall in the inherited code), but the legacy patches don't do anything useful. Plan D should rip out `pen_patches.lua` entirely (or stash it as `.old_simpleui`) — its purpose was to inject SimpleUI's chrome into KOReader's screens, which we don't need since our chrome lives in `pen_homescreen.lua`.
- **Hold-on-tab** opens a placeholder `InfoMessage("tab settings — coming in plan d")` — Plan D wires the real tab-config screen
- **`stats`** action shows a placeholder toast — Plan D wires it to KOReader's ReadingStatistics plugin
- **`search`** action shows a hint toast — Plan D wires it to the file-search UI
- **Cover %-overlay polish** carried from Plan B (% band rendered below cover, not overlaid)
- **Page-jump on highlight tap** — currently opens the book without seeking to the highlighted page; needs post-open goto via ReaderUI
- **Bars on file-browser and reader views** — currently only on the home screen. Inheriting SimpleUI's monkey-patches for that was deemed out of scope; revisit if you want bars everywhere.
- **Async catalogue scan** carried from Plan B (synchronous on render)

## What's deferred to Plan D

- Settings menu (Menu → Tools → penjuru sub-tree) for reading goal, location, newly-threshold, catalogue dirs, tab roster, status-bar layout
- On-Kindle install (build script, INSTALL.md for end users)
- Visible Acknowledgments to Doctor Hetfield in README
- Optional: persisting bars across all KOReader screens (file browser, reader)

## Plan C commit log

| Commit | Subject |
|---|---|
| `b5636d9` | docs: Plan C implementation plan |
| `9217d64` | feat(icons): 12 SVG icons for tabs + chevrons |
| `1baea5c` | feat(icons): pen_icons resolves SVG by short name |
| `b465a1d` | feat(status): pen_status reads clock/battery/wifi/light/disk |
| `4585ff1` | feat(chrome): pen_topbar renders status row |
| `b3ee582` | feat(tabs): pen_tabs — descriptors + default 2-page roster |
| `810850a` | feat(chrome): pen_bottombar — 7-cell paginated nav |
| `1893856` | feat(actions): pen_actions — central dispatcher |
| `ec2c80d` | feat(home): tap a highlight opens the book |
| `b3f4581` | feat(home): tap a newly-catalogued row opens the book |
| `dc9a0f5` | feat(home): mount pen_topbar + pen_bottombar around the body |
