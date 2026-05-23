# penjuru pikiran · a reader's almanac

A KOReader UI plugin for Kindle Paperwhite. Replaces the default home/library
chrome with a newspaper-flavored home screen typed in monospace, plus a
persistent top status bar and a persistent paginated bottom nav.

The design carries the voice of penjurupikiran.com — lowercase everywhere,
triple-monospace type system (Syne Mono · IBM Plex Mono · VT323), small
quiet archive mood — onto e-ink.

## Status

- **Type:** new plugin (fork of simpleui.koplugin, then heavily reskinned + rebuilt)
- **Target device:** Kindle Paperwhite (PW5 / PW11 / PW12, 1236 × 1648 @ 300 ppi)
- **Target software:** KOReader (already installed; Kindle jailbroken)
- **Install path:** `/mnt/us/koreader/plugins/penjuru.koplugin/`

## Goals

1. Home-screen-first reading workflow. Open device → see today's reading state, your books, your highlights.
2. A distinctive monospace newspaper aesthetic that respects e-ink (no color, dithering for tonal variation, lowercase throughout).
3. Two-page paginated bottom nav so common destinations are one tap away regardless of which screen you're on.
4. Surface user-extensible content (custom folder shortcuts, plugin shortcuts, KUAL launcher) as first-class tabs.

## Non-goals

- Color / riso palette (e-ink is greyscale; we use dither density instead).
- Replacing KOReader's reader view, page-turn, or book metadata internals.
- Audiobook playback (KOReader doesn't play audio; the audiobooks tab was dropped in favor of `library`).
- Theme switching at runtime — single locked aesthetic.
- Sync to any external service.

## Visual system

### Typography

| Role | Font | Size range (native px @ 1236w) |
|---|---|---|
| Display / headlines / pull quotes | Syne Mono | 22–76px |
| Body / dateline / captions | IBM Plex Mono | 18–24px |
| Numerals (clock, stats, dates) | VT323 | 14–36px |
| Italic / bylines / source attribution | IBM Plex Mono Italic | 18–21px |

All copy is **lowercase**. No serifs. No proportional fonts.

### Color

E-ink monochrome only. Palette:

- `#fff` — paper
- `#111` — primary ink
- `#444` / `#555` / `#666` / `#777` — secondary ink shades for hierarchy
- `#aaa` / `#bbb` / `#ccc` / `#ddd` — dividers, disabled state
- `#eee` — subtle row dividers

Tonal variation in covers and accents comes from **45° diagonal dither patterns** at four densities (light / medium / dither / dense) — this both reads on e-ink without ghosting and visually echoes the riso textures of penjurupikiran.com.

### Rules and dividers

- **Major rules** (between sections): 2px solid `#111`
- **Minor rules** (within section, e.g. stat rows): 1.5px dotted `#aaa`/`#ccc`
- **Soft rules** (between similar items): 1.5px solid `#eee`
- **Masthead rule:** 2.5px dashed `#111`
- **Section heads (VT323):** underlined with 2.5px solid `#111`

### Borders and shadows

- Device frame: 1px solid `#444` (preview only — invisible on actual Kindle)
- Covers: 2px solid `#111`
- No shadows on e-ink content (they band).

## Screen layout · top to bottom

The device is 1236 × 1648 native px. All measurements below are CSS px at native size.

**Scope note:** This spec defines the **home screen** in full. The persistent
top status bar and bottom nav also appear on every other screen
(library, history, search results, etc.), and those other screens inherit
the global typography (Plex/Syne/VT323), color tokens, and rule styles via
the shared `sui_style.lua` theme — but their internal layouts are
unchanged from SimpleUI's behavior in v1.

### 1. Top status bar (persistent across every screen)

- Height: ~48px (padding 14px × 2 + ~22px font + 2px border)
- Background: `#fff`, bottom border: 2px solid `#111`
- Left cluster: `clock · wi-fi · light <N>`
- Right cluster: `<free> gb · <pct>%`
- All items lowercase IBM Plex Mono, 24px, with `· ` prefix between
- Each item is independently placeable (left/right) via settings

### 2. Masthead

- Title: `penjuru pikiran` in Syne Mono 76px, letter-spacing -1px, centered
- Tagline: `a reader's almanac · mind-wide` in IBM Plex Mono 20px, letter-spacing 4.5px, color `#555`
- Bottom border: 2.5px dashed `#111`

### 3. Dateline

- Three-cell row with `justify-content: space-between`
- Left: `vol. <I>. · no. <N>` — volume rolls over annually; number = days-since-install
- Center: `<weekday> · <D> <month> <YYYY>` — full date
- Right: `<edition>` — `morning` (00–11:59), `afternoon` (12–17:59), `evening` (18–23:59)
- IBM Plex Mono 20px, color `#444`, bottom border 2px dotted `#aaa`

### 4. Lead row (two-column grid, 1.5fr / 1fr)

#### 4a. Currently reading (left, 1.5fr)

The **single** most-recently-opened book.

- Section head: `currently reading` (VT323 36px underlined)
- Headline: book title in Syne Mono 48px, line-height 1.1 — rendered AS the headline, not "Title: X"
- Byline: `— from the desk of <author>, <year>` in italic 21px, color `#555`
- Pull quote: most recent highlight from this book in IBM Plex Mono italic 24px, with left border-rule 4px solid `#111`
- Body lede: 22px line — `<time-today> of progress today, advancing through <chapter>. an estimated <remaining> remain.` Drop cap on first letter (Syne Mono 66px).
- Progress: `p <current>` · dithered bar · `<total> · <pct>%`

If no book opened yet today, show: `no entries today` and skip the byline/pull/body/progress.

#### 4b. Today's ledger + The almanac (right, 1fr)

Two stacked stat blocks.

**today's ledger** (VT323 36px underlined):
- `reading` — minutes today, e.g. `42m`
- `pages` — pages read today
- `streak` — consecutive days with any reading
- `<YYYY>` — books finished this year over goal, e.g. `17/40`

**the almanac** (VT323 36px underlined):
- `day of year` — e.g. `143`
- `week no.` — ISO week, e.g. `21`
- `sun rises` / `sun sets` — computed offline from device locale, e.g. `05:47` / `18:02`
- `moon` — phase name + glyph (waxing / full / waning / new) computed from date

All ledger and almanac values are **VT323** for the numerals.

### 5. Desk row (two-column grid, 1.5fr / 1fr)

#### 5a. On the desk (left, 1.5fr)

5 covers, books with progress > 0% and < 100%, **excluding the lead-story book** (to avoid duplication). Sorted by last-opened, most recent first.

- 5-column subgrid, gap 11px
- Cover: 2:3 aspect, 2px black border
- Progress overlay: black bar at cover bottom with VT323 28px white percentage, e.g. `72%`
- Caption: book title in 18px, max 2 lines (~42px height), centered

#### 5b. Newly catalogued (right, 1fr)

3 rows. Books recently added to library with progress == 0%. Sorted by file mtime descending.

- Each row: ~80px min-height for comfortable tap target
- Title: Syne Mono 28px, single line, ellipsized if too long
- Author: IBM Plex Mono 20px, color `#777`
- Right: age in VT323 32px (e.g. `2d`, `5d`, `1w`, `3w`) followed by ` →` chevron in `#aaa`
- Tap row: opens that book

"Newly" threshold is configurable — default 30 days. Files older than threshold drop out even if untouched.

### 6. Recent highlights (full width)

- Section head: `recent highlights` (VT323 36px underlined)
- 3 items, dotted divider between
- Quote: Syne Mono 29px with " glyph in `#777` at left
- Source: `— <author>, <book>` and `p. <#> · <date>` in italic 20px, `#666`
- Highlights are the **3 most-recent** across all books (not random)
- Tap a highlight: opens that book to that page

### 7. Persistent paginated bottom nav

#### 7a. Pagination meta row

- Padding: 8px 28px, bottom border 2px dotted `#aaa`
- Left: `navpager · page <i> / <n>` (IBM Plex Mono 19px, `#666`)
- Center: pagination dots — small filled/empty circles
- Right: `hold any tab → settings` (hint text)

#### 7b. Tab row

7-cell flex row: chevron · 5 content tabs · chevron.

- Total flex: `10 + 16×5 + 10 = 100` (chevrons narrower than content)
- Each cell: min-height 170px, top edge gets a 7px black bar via `box-shadow: inset 0 7px 0 #111` when active
- Icon: 62 × 62 px SVG (1.6px stroke), label below in IBM Plex Mono 22px lowercase

**Page 1 (your content):**

| Cell | Label | Kind | Target |
|---|---|---|---|
| 1 | prev | chevron | paginate bar back (dimmed on page 1) |
| 2 | manga | custom folder | `/mnt/us/koreader/mangas/` |
| 3 | books | custom folder | `/mnt/us/koreader/books/` |
| 4 | home | built-in | this home screen (active by default) |
| 5 | wi-fi | toggle | flip Wi-Fi on/off |
| 6 | games | KUAL launcher | jumps to `/mnt/us/extensions/` |
| 7 | next | chevron | paginate bar forward |

**Page 2 (utilities):**

| Cell | Label | Kind | Target |
|---|---|---|---|
| 1 | prev | chevron | paginate bar back |
| 2 | stats | plugin | KOReader Statistics |
| 3 | brightness | built-in | frontlight slider |
| 4 | power | built-in | restart / quit / sleep menu |
| 5 | search | built-in | global file search |
| 6 | library | built-in | full KOReader library |
| 7 | next | chevron | paginate bar forward (dimmed on page 2) |

Pagination behavior:
- Bar pages independently of the current screen (you can be reading and still flip the bar).
- Active-tab indicator (top-edge bar) only shows when the current screen lives on the currently visible bar page.
- Hold-anywhere on the bar opens the tab configuration screen (preserved from simpleui).

## Data sources

All data is **local**, read from KOReader's existing data files. No network calls.

| Module | Source |
|---|---|
| Currently reading (lead) | KOReader's `history.lua` — most recent file with last-opened timestamp |
| Pull quote in lead | KOReader's per-book `<book>.sdr/metadata.lua` — `bookmarks[1].notes` for the lead book |
| Today's ledger (reading min, pages, streak, year goal) | KOReader Statistics plugin's SQLite db at `koreader/settings/statistics.sqlite3` |
| Almanac (sunrise/sunset, moon phase) | Computed offline from device location (user-configured lat/lon) + date |
| Almanac (day of year, week) | Pure date math |
| On the desk | KOReader collections + per-book metadata — files in library with `percent_finished > 0 and < 1`, sorted by last-opened |
| Newly catalogued | Library scan: files with `percent_finished == 0` and `mtime > now - 30d`, sorted by mtime desc |
| Recent highlights (3) | Per-book `.sdr/metadata.lua` scan — `bookmarks` arrays across all books, flattened, sorted by `datetime` desc |
| Vol./No. in dateline | `(install_date, today)` → years since install, days since install |
| Edition (morning/afternoon/evening) | Current hour |

## Settings

Accessible via **Menu → Tools → penjuru**. Categories:

- **Home modules** — toggle each module on/off, reorder, resize
- **Bottom nav** — assign tab per slot per page, set custom folder paths, set plugin shortcuts
- **Top status bar** — toggle each item, set left/right placement
- **Location** — set lat/lon for sunrise/sunset/moon
- **Reading goal** — set annual book goal (the `<YYYY>` ledger row)
- **Newly threshold** — set "added in last N days" cutoff (default 30)
- **Start with home** — make home the boot screen
- **Reset to defaults**

## Install

1. Build: `make` in plugin folder produces `penjuru.koplugin/` directory (mirror simpleui's Makefile)
2. Copy: `/mnt/us/koreader/plugins/penjuru.koplugin/` on the Kindle
3. Restart KOReader (Menu → Restart KOReader)
4. Enable: Menu → Tools → penjuru → Enable
5. Tap the **home** tab on the bottom nav (or Menu → Tools → penjuru → Home Screen → Start with Home Screen)

## Implementation approach

Fork simpleui.koplugin as the starting point — it already solves the hard
problems (monkey-patching KOReader's UI to insert the persistent top + bottom
bars, registering modules via `moduleregistry.lua`, settings menu, i18n,
icon-pack hot-swap). Then:

1. **Rename** the plugin (`penjuru.koplugin`, `_meta.lua` updated)
2. **Replace the typography layer** in `sui_style.lua` — load IBM Plex Mono, Syne Mono, VT323 from bundled `fonts/` (no internet on Kindle); set every text style to use them
3. **Rewrite `sui_homescreen.lua`** to the spec'd modules above; gut SimpleUI's existing modules
4. **Rewrite the desktop modules** in `desktop_modules/` — `module_currently.lua` (now newspaper-headline style), new `module_almanac.lua`, modified `module_reading_stats.lua` (now "ledger"), modified `module_recent.lua` (now "on the desk"), modified `module_new_books.lua` (now "newly catalogued"), modified `module_quote.lua` (now "recent highlights" pulling from user data)
5. **Replace the bottom-nav** in `sui_bottombar.lua` — keep Navpager pagination machinery, redesign cell rendering (icon-above-label, 7-cell grid, active-tab top-bar indicator)
6. **Replace the icon set** in `icons/` — produce 1.6px-stroke SVGs matching the design (manga, books, home, wi-fi, games, stats, brightness, power, search, library, prev, next, etc.)
7. **Bundle a fonts directory** — Plex Mono / Syne Mono / VT323 TTFs, ~600KB total
8. **Trim everything else** — drop SimpleUI's quote-of-the-day, folder-covers, browse-by-author/series/tags etc. modules we don't use

## Open questions for future iterations

- Cover-art handling — KOReader can extract covers from EPUB but the .sdr cache may need warming
- "On this day" or "word of the day" modules — left for a v2
- Icon-pack support — punt to v2 (the design ships with one locked icon set)

## Out of scope for v1

- Color or runtime theme swap
- Networking / sync / weather
- Audiobook playback or library
- Folder covers feature (drop it — not in this design)
- Quote of the day from external corpus (replaced by user's own highlights)
- Multi-device support beyond Kindle Paperwhite (Kobo / Android can come later)
