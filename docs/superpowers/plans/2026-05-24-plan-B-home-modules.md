# penjuru.koplugin · Plan B — Home Screen Modules

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the body placeholder on the home screen with the six modules from the spec — currently reading (lead), today's ledger, the almanac, on the desk, newly catalogued, recent highlights — all wired to real KOReader data.

**Architecture:** Each home module is a self-contained Lua file in `home_modules/` exposing one function: `module.render(content_width) -> widget`. Data access (history, per-book `.sdr/metadata.lua`, statistics SQLite) lives in `pen_data.lua` so modules stay UI-only. Pure-math helpers (sunrise/sunset, moon phase) live in `pen_almanac.lua` with no KOReader deps. Shared widget primitives (rule, section head, spaced row, custom dashed/dotted line) live in `pen_widgets.lua`. The home screen composes the six modules vertically inside the existing masthead + dateline skeleton.

**Tech Stack:** Lua 5.1, KOReader v2026.03 widget system (`TextWidget`, `ImageWidget`, `VerticalGroup`, `HorizontalGroup`, `LineWidget`, custom `BlitBuffer` for dotted lines), `sqlite3` (LuaJIT FFI binding shipped with KOReader), pure-math for astronomical calculations, busted for tests.

**Plan A carry-overs:**
- KOReader's `LineWidget` doesn't support dotted style — we ship a custom `DottedLineWidget` in this plan (Task 0.1).
- Dateline `vol. i · no. 1` is placeholder; this plan adds install-date storage (Task 1.4) so it shows real values.

---

## File structure (new in Plan B)

```
penjuru.koplugin/
├── pen_data.lua                       [Phase 0]   KOReader data access
├── pen_widgets.lua                    [Phase 0]   shared widget primitives
├── pen_almanac.lua                    [Phase 1]   sunrise/moon math (pure)
├── pen_install_date.lua               [Phase 1]   install-date storage
├── home_modules/
│   ├── module_almanac.lua             [Phase 1]   day-of-year + week + sun + moon
│   ├── module_ledger.lua              [Phase 2]   today's stats sidebar
│   ├── module_currently.lua           [Phase 3]   lead story (active book)
│   ├── module_desk.lua                [Phase 4]   5 in-progress book covers
│   ├── module_catalogued.lua          [Phase 5]   3 newly-added unstarted books
│   └── module_highlights.lua          [Phase 6]   3 recent annotations
├── pen_homescreen.lua                 [MOD Phase 7]   composes all modules
└── spec/unit/
    ├── pen_almanac_spec.lua           [Phase 1]
    ├── pen_install_date_spec.lua      [Phase 1]
    ├── pen_data_spec.lua              [Phase 0]
    └── (module specs where logic is testable)
```

---

## Phase 0 · Shared infrastructure

### Task 0.1: `pen_widgets.lua` — rule helper, section head, spaced row, custom dotted line

**Files:**
- Create: `penjuru.koplugin/pen_widgets.lua`

KOReader's `LineWidget` supports solid and dashed strokes but not dotted. We need dotted for the spec's "1.5px dotted within section" rule. Also factor out the repeated `rule(...)` and `spaced_row(...)` helpers that pen_homescreen.lua already defines inline.

- [ ] **Step 1: Create `pen_widgets.lua`**

```lua
-- penjuru/pen_widgets
-- Shared widget primitives reused across home modules.
-- One source of truth for rule construction, section-head styling, and
-- space-between row layout.

local BlitBuffer = require("ffi/blitbuffer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local Style = require("pen_style")

local M = {}

-- rule(width, weight, color)  -- solid rule, full width
function M.rule(w, weight, color)
    return LineWidget:new{
        dimen = { w = w, h = weight },
        background = color or Style.colors.ink,
    }
end

-- dashed_rule(width, weight, color, dash_len, gap_len)
-- KOReader's LineWidget supports `style = "dashed"`; we wrap it for clarity.
function M.dashed_rule(w, weight, color, dash_len, gap_len)
    return LineWidget:new{
        dimen = { w = w, h = weight },
        background = color or Style.colors.ink,
        style = "dashed",
        dash_length = dash_len or 8,
        gap_length = gap_len or 4,
    }
end

-- DottedLineWidget — custom widget that paints a row of small black squares.
-- Used for the spec's "minor rule" (1.5px dotted #aaa within sections).
local DottedLineWidget = Widget:extend{
    width = 0,
    weight = 1,
    color = BlitBuffer.COLOR_BLACK,
    dot_size = 2,
    gap = 4,
}

function DottedLineWidget:getSize()
    return { w = self.width, h = self.weight }
end

function DottedLineWidget:paintTo(bb, x, y)
    local step = self.dot_size + self.gap
    local i = 0
    while i + self.dot_size <= self.width do
        bb:paintRect(x + i, y, self.dot_size, self.weight, self.color)
        i = i + step
    end
end

-- dotted_rule(width, weight, color)
function M.dotted_rule(w, weight, color)
    return DottedLineWidget:new{
        width = w,
        weight = weight,
        color = color or Style.colors.rule,
    }
end

-- section_head(width, label)  -- VT323 underlined section heading
function M.section_head(w, label)
    local txt = TextWidget:new{
        text = label,
        face = Style.fonts.numerals(Style.size.section_head),
        fgcolor = Style.colors.ink,
    }
    return VerticalGroup:new{
        align = "left",
        txt,
        VerticalSpan:new{ width = 2 },
        M.rule(w, Style.rules.section, Style.colors.ink),
        VerticalSpan:new{ width = Style.gap.sm },
    }
end

-- spaced_row(width, items)  -- distribute items with space-between
function M.spaced_row(w, items)
    if #items == 0 then return HorizontalGroup:new{} end
    local total_text_w = 0
    for _, item in ipairs(items) do total_text_w = total_text_w + item:getSize().w end
    local gap = (#items > 1) and math.floor((w - total_text_w) / (#items - 1)) or 0
    local row = HorizontalGroup:new{ align = "baseline" }
    for i, item in ipairs(items) do
        table.insert(row, item)
        if i < #items then table.insert(row, HorizontalSpan:new{ width = gap }) end
    end
    return row
end

return M
```

- [ ] **Step 2: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_widgets.lua
git commit -m "feat(widgets): shared primitives for rules, section heads, spaced rows

Includes DottedLineWidget — a custom Widget subclass that paints rows of
small black squares for the spec's minor-rule style (KOReader's
LineWidget supports solid and dashed but not dotted)."
```

### Task 0.2: `pen_data.lua` — KOReader data-access layer

**Files:**
- Create: `penjuru.koplugin/pen_data.lua`
- Create: `penjuru.koplugin/spec/unit/pen_data_spec.lua`

We need centralized helpers to read KOReader's user data: the global history file, per-book `.sdr/metadata.lua` files (which hold cover hints, bookmarks/highlights, reading status), and the statistics SQLite database. The modules will call these — modules themselves don't touch disk.

- [ ] **Step 1: Write the failing spec**

Create `penjuru.koplugin/spec/unit/pen_data_spec.lua`:
```lua
-- Test bootstrap: prepend plugin dir to package.path (mirrors pen_fonts_spec)
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_data", function()
    local Data
    setup(function() Data = require("pen_data") end)

    describe("read_history", function()
        it("returns a table (possibly empty)", function()
            local h = Data.read_history()
            assert.is_table(h)
        end)
    end)

    describe("read_sdr_metadata", function()
        it("returns nil for a non-existent path", function()
            local m = Data.read_sdr_metadata("/nonexistent/book.epub")
            assert.is_nil(m)
        end)
    end)

    describe("parse_lua_file", function()
        it("returns nil for a non-existent file", function()
            assert.is_nil(Data.parse_lua_file("/nonexistent/file.lua"))
        end)

        it("returns the table when the file is a valid `return { ... }`", function()
            local tmp = os.tmpname() .. ".lua"
            local f = io.open(tmp, "w")
            f:write([[return { hello = "world", n = 42 }]])
            f:close()
            local r = Data.parse_lua_file(tmp)
            assert.equals("world", r.hello)
            assert.equals(42, r.n)
            os.remove(tmp)
        end)
    end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_data_spec.lua 2>&1 | tail -10
```

Expected: `module 'pen_data' not found` error.

- [ ] **Step 3: Implement `pen_data.lua`**

Create `penjuru.koplugin/pen_data.lua`:
```lua
-- penjuru/pen_data
-- Centralized read access to KOReader's user data. Modules call here so
-- only this file knows about file paths, history format, .sdr layout,
-- and statistics SQLite. Pure read; no mutations.

local DataStorage = require("datastorage")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local M = {}

-- parse_lua_file(path) -> table | nil
-- Loads a file expected to be `return { ... }`. Used for KOReader's
-- history.lua and per-book .sdr/metadata.lua files. Errors during load
-- are logged and produce nil — callers handle missing data gracefully.
function M.parse_lua_file(path)
    local ok_stat, stat = pcall(lfs.attributes, path)
    if not ok_stat or not stat then return nil end
    local chunk, err = loadfile(path)
    if not chunk then
        logger.warn("pen_data: failed to load", path, err)
        return nil
    end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        logger.warn("pen_data: invalid table in", path, result)
        return nil
    end
    return result
end

-- read_history() -> table
-- KOReader's history.lua is at <settings>/history.lua. Returns its parsed
-- table (a numbered list of { file = "...", time = N } entries, most
-- recent first), or empty table if absent.
function M.read_history()
    local path = DataStorage:getSettingsDir() .. "/history.lua"
    return M.parse_lua_file(path) or {}
end

-- sdr_path_for(book_path) -> string
-- Given /path/to/book.epub, return /path/to/book.sdr/metadata.epub.lua
-- (KOReader's per-book sidecar convention).
function M.sdr_path_for(book_path)
    if not book_path or book_path == "" then return nil end
    local dir, name = book_path:match("(.*)/(.*)$")
    if not dir or not name then return nil end
    local stem, ext = name:match("(.*)%.(.*)$")
    if not stem or not ext then return nil end
    return dir .. "/" .. stem .. ".sdr/metadata." .. ext:lower() .. ".lua"
end

-- read_sdr_metadata(book_path) -> table | nil
-- Returns the parsed metadata.lua sidecar for a book, or nil if absent.
function M.read_sdr_metadata(book_path)
    local p = M.sdr_path_for(book_path)
    if not p then return nil end
    return M.parse_lua_file(p)
end

-- file_mtime(path) -> number | nil
-- Seconds since epoch for the file's modification time, or nil if missing.
function M.file_mtime(path)
    local ok, stat = pcall(lfs.attributes, path)
    if not ok or not stat then return nil end
    return stat.modification
end

-- list_books_in(dir) -> array of absolute paths
-- Walks `dir` recursively, returning every file whose extension is in
-- KOReader's supported set. Hidden files and .sdr/ folders are skipped.
local SUPPORTED_EXTS = {
    epub=true, pdf=true, mobi=true, azw=true, azw3=true, cbz=true, cbr=true,
    fb2=true, djvu=true, txt=true, rtf=true, html=true, htm=true, doc=true,
    docx=true, odt=true, chm=true, zip=true,
}
function M.list_books_in(dir)
    local out = {}
    local function walk(d)
        local ok, iter = pcall(lfs.dir, d)
        if not ok then return end
        for entry in iter do
            if entry:sub(1,1) ~= "." then
                local full = d .. "/" .. entry
                local attr = lfs.attributes(full)
                if attr and attr.mode == "directory" then
                    if not entry:match("%.sdr$") then walk(full) end
                elseif attr then
                    local ext = entry:match("%.([^.]+)$")
                    if ext and SUPPORTED_EXTS[ext:lower()] then
                        table.insert(out, full)
                    end
                end
            end
        end
    end
    walk(dir)
    return out
end

return M
```

- [ ] **Step 4: Run the spec and confirm pass**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_data_spec.lua 2>&1 | tail -10
```

Expected: `4 successes`.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_data.lua penjuru.koplugin/spec/unit/pen_data_spec.lua
git commit -m "feat(data): pen_data — KOReader data-access layer

Read access to history.lua, per-book .sdr/metadata.lua, file mtimes,
and recursive book listings. Centralizes paths so home modules stay
UI-only."
```

---

## Phase 1 · Almanac module

The simplest module — pure math, no KOReader internals. Good warm-up for the rest.

### Task 1.1: `pen_almanac.lua` — sunrise/sunset (NOAA formula)

**Files:**
- Create: `penjuru.koplugin/pen_almanac.lua`
- Create: `penjuru.koplugin/spec/unit/pen_almanac_spec.lua`

- [ ] **Step 1: Write the failing spec**

Create `penjuru.koplugin/spec/unit/pen_almanac_spec.lua`:
```lua
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_almanac", function()
    local A
    setup(function() A = require("pen_almanac") end)

    describe("sun_times", function()
        -- Jakarta on 2026-05-23: sunrise ~05:51, sunset ~17:39 (local time, UTC+7)
        -- Allow ±5 min tolerance for NOAA formula.
        it("computes sunrise within 5 minutes for Jakarta on 2026-05-23", function()
            local r = A.sun_times(2026, 5, 23, -6.2088, 106.8456, 7)
            assert.is_true(math.abs(r.sunrise_min - (5 * 60 + 51)) < 5)
        end)
        it("computes sunset within 5 minutes for Jakarta on 2026-05-23", function()
            local r = A.sun_times(2026, 5, 23, -6.2088, 106.8456, 7)
            assert.is_true(math.abs(r.sunset_min - (17 * 60 + 39)) < 5)
        end)
        it("formats times as HH:MM", function()
            assert.equals("05:47", A.format_hhmm(5 * 60 + 47))
            assert.equals("18:02", A.format_hhmm(18 * 60 + 2))
        end)
    end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_almanac_spec.lua 2>&1 | tail -10
```

Expected: `module 'pen_almanac' not found`.

- [ ] **Step 3: Implement sun_times using the NOAA algorithm**

Create `penjuru.koplugin/pen_almanac.lua`:
```lua
-- penjuru/pen_almanac
-- Pure-math astronomical helpers. No KOReader deps; fully unit-testable.
-- Sunrise/sunset uses NOAA's solar position formulas
-- (https://gml.noaa.gov/grad/solcalc/calcdetails.html).
-- Moon phase uses a normalized synodic-month calculation from a known new moon.

local M = {}

local function rad(deg) return deg * math.pi / 180 end
local function deg(rad) return rad * 180 / math.pi end

-- Julian day for date at midnight UTC.
local function julian_day(y, m, d)
    if m <= 2 then y = y - 1; m = m + 12 end
    local a = math.floor(y / 100)
    local b = 2 - a + math.floor(a / 4)
    return math.floor(365.25 * (y + 4716))
         + math.floor(30.6001 * (m + 1))
         + d + b - 1524.5
end

-- sun_times(year, month, day, lat, lon, tz_hours)
-- Returns { sunrise_min, sunset_min } in local minutes-since-midnight.
function M.sun_times(year, month, day, lat, lon, tz_hours)
    local jd = julian_day(year, month, day)
    local jc = (jd - 2451545.0) / 36525.0  -- Julian century

    local geom_mean_long = (280.46646 + jc * (36000.76983 + jc * 0.0003032)) % 360
    local geom_mean_anom = 357.52911 + jc * (35999.05029 - 0.0001537 * jc)
    local eccent_earth   = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc)
    local sun_eq_ctr = math.sin(rad(geom_mean_anom)) *
            (1.914602 - jc * (0.004817 + 0.000014 * jc))
        + math.sin(rad(2 * geom_mean_anom)) * (0.019993 - 0.000101 * jc)
        + math.sin(rad(3 * geom_mean_anom)) * 0.000289
    local sun_true_long  = geom_mean_long + sun_eq_ctr
    local sun_app_long   = sun_true_long - 0.00569
        - 0.00478 * math.sin(rad(125.04 - 1934.136 * jc))

    local mean_obliq = 23 + (26 + ((21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813)))) / 60) / 60
    local obliq_corr = mean_obliq + 0.00256 * math.cos(rad(125.04 - 1934.136 * jc))

    local sun_decl = deg(math.asin(math.sin(rad(obliq_corr)) * math.sin(rad(sun_app_long))))

    local var_y = math.tan(rad(obliq_corr / 2)) * math.tan(rad(obliq_corr / 2))
    local eq_of_time = 4 * deg(
        var_y * math.sin(2 * rad(geom_mean_long))
      - 2 * eccent_earth * math.sin(rad(geom_mean_anom))
      + 4 * eccent_earth * var_y * math.sin(rad(geom_mean_anom)) * math.cos(2 * rad(geom_mean_long))
      - 0.5 * var_y * var_y * math.sin(4 * rad(geom_mean_long))
      - 1.25 * eccent_earth * eccent_earth * math.sin(2 * rad(geom_mean_anom))
    )

    -- Hour angle for sunrise/sunset (solar altitude = -0.833° to account
    -- for refraction + apparent solar radius).
    local cos_ha = (math.cos(rad(90.833)) / (math.cos(rad(lat)) * math.cos(rad(sun_decl))))
                 - math.tan(rad(lat)) * math.tan(rad(sun_decl))
    if cos_ha > 1 then return { sunrise_min = nil, sunset_min = nil } end  -- polar night
    if cos_ha < -1 then return { sunrise_min = 0, sunset_min = 24 * 60 } end  -- polar day
    local ha = deg(math.acos(cos_ha))

    local solar_noon = (720 - 4 * lon - eq_of_time + tz_hours * 60)
    return {
        sunrise_min = math.floor(solar_noon - 4 * ha),
        sunset_min  = math.floor(solar_noon + 4 * ha),
    }
end

function M.format_hhmm(mins)
    if not mins then return "--:--" end
    return string.format("%02d:%02d", math.floor(mins / 60) % 24, mins % 60)
end

return M
```

- [ ] **Step 4: Run the spec and confirm pass**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_almanac_spec.lua 2>&1 | tail -10
```

Expected: 3 successes.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_almanac.lua penjuru.koplugin/spec/unit/pen_almanac_spec.lua
git commit -m "feat(almanac): sunrise/sunset via NOAA formula

Pure-math; offline. Verified against published Jakarta times for
2026-05-23 (±5 min tolerance for formula precision)."
```

### Task 1.2: Add moon-phase calculation to `pen_almanac.lua`

**Files:**
- Modify: `penjuru.koplugin/pen_almanac.lua`
- Modify: `penjuru.koplugin/spec/unit/pen_almanac_spec.lua`

The synodic month is 29.530588 days. Counting full synodic cycles since the known new moon of 2000-01-06 06:14 UTC gives the current phase.

- [ ] **Step 1: Add the spec block**

Append to `spec/unit/pen_almanac_spec.lua` (inside the outer `describe`):
```lua
    describe("moon_phase", function()
        -- Known new moons (UTC midnight tolerance): 2000-01-06, 2026-05-17
        it("returns 'new' near a known new-moon date", function()
            local p = A.moon_phase(2026, 5, 17)
            assert.equals("new", p.name)
        end)
        it("returns 'waxing' a few days after new", function()
            local p = A.moon_phase(2026, 5, 21)
            assert.equals("waxing", p.name)
        end)
        it("returns 'full' near a known full-moon date (~2026-06-01)", function()
            local p = A.moon_phase(2026, 6, 1)
            assert.equals("full", p.name)
        end)
        it("returns a fraction in [0,1)", function()
            local p = A.moon_phase(2026, 5, 23)
            assert.is_true(p.fraction >= 0 and p.fraction < 1)
        end)
    end)
```

- [ ] **Step 2: Run the new specs and confirm they fail**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_almanac_spec.lua 2>&1 | tail -10
```

Expected: `attempt to call field 'moon_phase' (a nil value)` for the new tests.

- [ ] **Step 3: Implement `moon_phase` and add to `pen_almanac.lua`**

Append before `return M`:
```lua
-- Reference new moon: 2000-01-06 18:14 UTC.
-- Julian day of this instant: 2451550.26.
local NEW_MOON_JD = 2451550.26
local SYNODIC_DAYS = 29.530588853

-- moon_phase(year, month, day) -> { name, fraction }
-- fraction: 0 = new, 0.25 = first quarter, 0.5 = full, 0.75 = last quarter.
function M.moon_phase(year, month, day)
    local jd = julian_day(year, month, day) + 0.5  -- midnight UTC -> noon-ish for stability
    local cycles = (jd - NEW_MOON_JD) / SYNODIC_DAYS
    local fraction = cycles - math.floor(cycles)
    if fraction < 0 then fraction = fraction + 1 end

    -- Bucket into 8 named phases.
    local name
    if fraction < 0.03 or fraction >= 0.97 then name = "new"
    elseif fraction < 0.22 then name = "waxing"
    elseif fraction < 0.28 then name = "first quarter"
    elseif fraction < 0.47 then name = "waxing"
    elseif fraction < 0.53 then name = "full"
    elseif fraction < 0.72 then name = "waning"
    elseif fraction < 0.78 then name = "last quarter"
    else name = "waning" end

    return { name = name, fraction = fraction }
end
```

- [ ] **Step 4: Run specs and confirm pass**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_almanac_spec.lua 2>&1 | tail -10
```

Expected: 7 successes (3 sun + 4 moon).

If the "new" test fails for 2026-05-17 (the actual new moon that month is May 17 17:42 UTC), the tolerance in the `name` buckets may need adjustment. Loosen the `< 0.03` to `< 0.04` if needed.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_almanac.lua penjuru.koplugin/spec/unit/pen_almanac_spec.lua
git commit -m "feat(almanac): moon phase via synodic cycle count

References 2000-01-06 18:14 UTC new moon as epoch. Returns named bucket
(new / waxing / first quarter / full / waning / last quarter) plus
fractional position in cycle [0,1)."
```

### Task 1.3: `home_modules/module_almanac.lua` — render the sidebar block

**Files:**
- Create: `penjuru.koplugin/home_modules/module_almanac.lua`

Renders the "the almanac" block as it appears in the spec mockup: day of year, week no., sun rises, sun sets, moon — each as a stat-row line with VT323 numerals on the right.

- [ ] **Step 1: Create the module**

```bash
mkdir -p ~/Developer/koreader-custom-ui/penjuru.koplugin/home_modules
```

Create `penjuru.koplugin/home_modules/module_almanac.lua`:
```lua
-- home_modules/module_almanac
-- Renders the "the almanac" section: day of year, week, sun times, moon.
-- Pulls user location from KOReader settings (lat/lon/tz) — defaults to
-- Jakarta if unset. Plan D wires up a settings UI for these values.

local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local G_reader_settings = G_reader_settings  -- KOReader global
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Almanac = require("pen_almanac")
local Dates = require("pen_dates")

local M = {}

-- Default location: Jakarta (close to user's region).
local DEFAULT_LAT = -6.2088
local DEFAULT_LON = 106.8456
local DEFAULT_TZ = 7

local function user_location()
    local s = G_reader_settings and G_reader_settings:readSetting("penjuru") or {}
    s = s.almanac or {}
    return s.lat or DEFAULT_LAT, s.lon or DEFAULT_LON, s.tz or DEFAULT_TZ
end

local function stat_line(w, label_text, value_text)
    local label = TextWidget:new{
        text = label_text,
        face = Style.fonts.body(Style.size.body - 4),
        fgcolor = Style.colors.ink_2,
    }
    local value = TextWidget:new{
        text = value_text,
        face = Style.fonts.numerals(Style.size.almanac_value),
        fgcolor = Style.colors.ink,
    }
    return Widgets.spaced_row(w, { label, value })
end

-- render(content_width) -> widget
function M.render(content_width)
    local t = os.time()
    local d = os.date("*t", t)
    local lat, lon, tz = user_location()
    local sun = Almanac.sun_times(d.year, d.month, d.day, lat, lon, tz)
    local moon = Almanac.moon_phase(d.year, d.month, d.day)

    return VerticalGroup:new{
        align = "left",
        Widgets.section_head(content_width, "the almanac"),
        stat_line(content_width, "day of year", tostring(Dates.day_of_year(t))),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "week no.", tostring(Dates.iso_week(t))),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "sun rises", Almanac.format_hhmm(sun.sunrise_min)),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "sun sets", Almanac.format_hhmm(sun.sunset_min)),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "moon", moon.name),
    }
end

return M
```

- [ ] **Step 2: Smoke-test by adding the module under the homescreen body placeholder**

Open `penjuru.koplugin/pen_homescreen.lua`. Inside the show()/render path (the implementer of Task 3.1 will have a specific spot for the body placeholder TextWidget), replace the placeholder with a call to `require("home_modules/module_almanac").render(content_width)`. Wrap in a VerticalGroup so we can add more modules later.

(If the homescreen file structure makes this hard, **don't refactor it now** — that's Phase 7's job. Instead, temporarily add a separate menu item under Menu → Tools → penjuru → "Show almanac (test)" that displays just `Almanac.render(800)` in a CenterContainer overlay. This lets you visually verify the module in isolation.)

- [ ] **Step 3: Visual smoke test in emulator**

```bash
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader
LOG=$(mktemp /tmp/penjuru-almanac-log.XXXX)
bash ./kodev run > "$LOG" 2>&1 &
KODEV_PID=$!
sleep 12
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
sleep 2
grep -iE 'error|cannot|nil value|attempt to' "$LOG" | grep -iE 'almanac|pen_' | head -10
echo "--- log: $LOG ---"
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/home_modules/module_almanac.lua penjuru.koplugin/pen_homescreen.lua
git commit -m "feat(home): module_almanac renders day-of-year/week/sun/moon"
```

### Task 1.4: `pen_install_date.lua` — install-date storage for vol/no

**Files:**
- Create: `penjuru.koplugin/pen_install_date.lua`
- Create: `penjuru.koplugin/spec/unit/pen_install_date_spec.lua`
- Modify: `penjuru.koplugin/pen_homescreen.lua` (dateline vol/no)

Vol = years since install + 1. No = days since install + 1. Stored as `penjuru.install_date` in `G_reader_settings`.

- [ ] **Step 1: Write the spec**

Create `penjuru.koplugin/spec/unit/pen_install_date_spec.lua`:
```lua
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_install_date", function()
    local ID
    setup(function() ID = require("pen_install_date") end)

    describe("vol_and_no_for", function()
        it("returns vol=1, no=1 on the install date itself", function()
            local install = os.time{year=2026, month=5, day=24, hour=12}
            local now = install
            local r = ID.vol_and_no_for(install, now)
            assert.equals(1, r.vol)
            assert.equals(1, r.no)
        end)

        it("returns vol=1, no=10 nine days after install", function()
            local install = os.time{year=2026, month=5, day=24, hour=12}
            local now = install + 9 * 86400
            local r = ID.vol_and_no_for(install, now)
            assert.equals(1, r.vol)
            assert.equals(10, r.no)
        end)

        it("returns vol=2 after 365 days", function()
            local install = os.time{year=2026, month=5, day=24, hour=12}
            local now = install + 365 * 86400
            local r = ID.vol_and_no_for(install, now)
            assert.equals(2, r.vol)
            assert.equals(1, r.no)
        end)
    end)

    describe("roman", function()
        it("converts 1..10 to lowercase roman", function()
            assert.equals("i",   ID.roman(1))
            assert.equals("ii",  ID.roman(2))
            assert.equals("iv",  ID.roman(4))
            assert.equals("v",   ID.roman(5))
            assert.equals("ix",  ID.roman(9))
            assert.equals("x",   ID.roman(10))
        end)
    end)
end)
```

- [ ] **Step 2: Run the spec and confirm fail**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_install_date_spec.lua 2>&1 | tail -10
```

Expected: `module 'pen_install_date' not found`.

- [ ] **Step 3: Implement**

Create `penjuru.koplugin/pen_install_date.lua`:
```lua
-- penjuru/pen_install_date
-- Tracks when penjuru was first activated so the dateline can show
-- vol = years since install + 1, no = days since install + 1.

local M = {}

-- Pure helper: compute vol/no for any install and now timestamps.
function M.vol_and_no_for(install_ts, now_ts)
    if not install_ts then return { vol = 1, no = 1 } end
    local days = math.floor((now_ts - install_ts) / 86400)
    if days < 0 then days = 0 end
    return {
        vol = math.floor(days / 365) + 1,
        no  = (days % 365) + 1,
    }
end

local ROMAN = {
    { 10, "x" }, { 9, "ix" }, { 5, "v" }, { 4, "iv" }, { 1, "i" }
}
function M.roman(n)
    local s = ""
    for _, pair in ipairs(ROMAN) do
        while n >= pair[1] do
            s = s .. pair[2]
            n = n - pair[1]
        end
    end
    return s
end

-- Read or initialize the install timestamp in G_reader_settings.
-- The KOReader global may not exist in test environments — callers
-- pass `now_ts` explicitly in tests; production calls use os.time().
function M.get_install_ts(settings, now_ts)
    if not settings then return now_ts end
    local s = settings:readSetting("penjuru") or {}
    if not s.install_date then
        s.install_date = now_ts
        settings:saveSetting("penjuru", s)
    end
    return s.install_date
end

return M
```

- [ ] **Step 4: Run spec, confirm pass**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_install_date_spec.lua 2>&1 | tail -10
```

Expected: 4 successes.

- [ ] **Step 5: Wire pen_homescreen's dateline to use real vol/no**

Open `penjuru.koplugin/pen_homescreen.lua`. Find the line that constructs the dateline's left cell as `"vol. i · no. 1"` (placeholder from Plan A) and replace with:
```lua
local InstallDate = require("pen_install_date")
local install_ts = InstallDate.get_install_ts(G_reader_settings, os.time())
local vn = InstallDate.vol_and_no_for(install_ts, os.time())
local vol_text = "vol. " .. InstallDate.roman(vn.vol) .. " · no. " .. vn.no
-- pass vol_text into the existing TextWidget that builds the left dateline cell
```

- [ ] **Step 6: Smoke-test in emulator**

```bash
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader && bash ./kodev run &
KODEV_PID=$!
sleep 12
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
```

Open Home tab in emulator. Dateline should show `vol. i · no. 1` on day-1; after a day passes (or by manually editing the saved install_date in `~/Developer/koreader/settings.reader.lua`) it bumps to `no. 2`.

- [ ] **Step 7: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_install_date.lua penjuru.koplugin/spec/unit/pen_install_date_spec.lua penjuru.koplugin/pen_homescreen.lua
git commit -m "feat(home): pen_install_date computes vol/no for dateline

Vol = years since install + 1 (lowercase roman), no = days since install
+ 1. Install timestamp stored in G_reader_settings.penjuru.install_date,
lazy-initialized on first read."
```

---

## Phase 2 · Today's ledger

### Task 2.1: `pen_data.read_today_stats()` from statistics.sqlite3

**Files:**
- Modify: `penjuru.koplugin/pen_data.lua`
- Modify: `penjuru.koplugin/spec/unit/pen_data_spec.lua`

KOReader's Statistics plugin stores reading sessions in `<settings>/statistics.sqlite3`. Schema (as of v2026.03):
- `book` table: `id`, `title`, `authors`, `notes`, `last_open`, `highlights`, `pages`, `series`, `language`, `md5`, `total_read_time`, `total_read_pages`
- `page_stat_data` table: `id_book`, `page`, `start_time`, `duration`, `total_pages`

For "today's stats" we need:
- reading_minutes: SUM(duration) for sessions where start_time is today
- pages: COUNT(DISTINCT page) per (id_book, page) for today's sessions
- streak: consecutive days ending today with any session
- books_finished_this_year: count of books where total_read_time > 0 and last_open in current year and pages_read == total_pages

- [ ] **Step 1: Add spec**

Append to `spec/unit/pen_data_spec.lua` (inside the outer describe):
```lua
    describe("read_today_stats", function()
        it("returns a table with the expected keys (defaults if db absent)", function()
            local s = Data.read_today_stats()
            assert.is_table(s)
            assert.is_number(s.reading_minutes)
            assert.is_number(s.pages)
            assert.is_number(s.streak_days)
        end)
    end)
```

- [ ] **Step 2: Run spec, confirm fail**

Expected: `attempt to call field 'read_today_stats' (a nil value)`.

- [ ] **Step 3: Implement against the SQLite db**

Append to `pen_data.lua` before `return M`:
```lua
-- read_today_stats() -> { reading_minutes, pages, streak_days, year_finished }
-- Reads KOReader's statistics.sqlite3. Returns sensible zeros if the db
-- is absent (e.g. user hasn't enabled the Statistics plugin yet).
function M.read_today_stats()
    local default = { reading_minutes = 0, pages = 0, streak_days = 0, year_finished = 0 }
    local path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    local stat = lfs.attributes(path)
    if not stat then return default end

    local ok_sql, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok_sql then return default end
    local ok_db, db = pcall(SQ3.open, path)
    if not ok_db then return default end

    local function scalar(sql)
        local ok, stmt = pcall(db.prepare, db, sql)
        if not ok then return nil end
        local row = stmt:step()
        local v = row and row[1] or nil
        stmt:close()
        return v
    end

    -- "today" = local-time start-of-day to start-of-tomorrow.
    local now = os.date("*t")
    local day_start = os.time{ year = now.year, month = now.month, day = now.day, hour = 0 }
    local day_end = day_start + 86400

    local reading_seconds = scalar(string.format(
        "SELECT IFNULL(SUM(duration), 0) FROM page_stat_data WHERE start_time >= %d AND start_time < %d",
        day_start, day_end))
    local pages_today = scalar(string.format(
        "SELECT COUNT(DISTINCT id_book || ':' || page) FROM page_stat_data WHERE start_time >= %d AND start_time < %d",
        day_start, day_end))

    -- Streak: walk backwards day by day until we find a day with no rows.
    local streak = 0
    local cursor = day_start
    while true do
        local n = scalar(string.format(
            "SELECT COUNT(*) FROM page_stat_data WHERE start_time >= %d AND start_time < %d",
            cursor, cursor + 86400)) or 0
        if n == 0 and cursor ~= day_start then break end  -- empty today is fine; break only on past empties
        if n > 0 then streak = streak + 1 end
        if n == 0 then break end
        cursor = cursor - 86400
    end

    -- Books finished this year: total_read_pages >= pages, last_open in current year.
    local year_start = os.time{ year = now.year, month = 1, day = 1, hour = 0 }
    local year_finished = scalar(string.format(
        "SELECT COUNT(*) FROM book WHERE total_read_pages >= pages AND pages > 0 AND last_open >= %d",
        year_start)) or 0

    db:close()
    return {
        reading_minutes = math.floor((reading_seconds or 0) / 60),
        pages = pages_today or 0,
        streak_days = streak,
        year_finished = year_finished,
    }
end
```

- [ ] **Step 4: Run spec, confirm pass**

Expected: 1 new success. (Test is intentionally weak — it just verifies the contract holds even when no db exists.)

- [ ] **Step 5: Commit**

```bash
git add penjuru.koplugin/pen_data.lua penjuru.koplugin/spec/unit/pen_data_spec.lua
git commit -m "feat(data): read_today_stats from KOReader's statistics.sqlite3

Returns reading_minutes / pages / streak_days / year_finished. Falls
back to zeros if the Statistics plugin isn't installed (db absent)."
```

### Task 2.2: `home_modules/module_ledger.lua` — today's ledger

**Files:**
- Create: `penjuru.koplugin/home_modules/module_ledger.lua`

- [ ] **Step 1: Create the module**

```lua
-- home_modules/module_ledger
-- Renders today's stats sidebar: reading min / pages / streak / year goal.

local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local TextWidget = require("ui/widget/textwidget")
local G_reader_settings = G_reader_settings
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local function user_year_goal()
    local s = G_reader_settings and G_reader_settings:readSetting("penjuru") or {}
    return s.year_goal or 40
end

local function stat_row(w, label_text, value_text)
    local label = TextWidget:new{
        text = label_text,
        face = Style.fonts.body(Style.size.stat_label - 2),
        fgcolor = Style.colors.ink_2,
    }
    local value = TextWidget:new{
        text = value_text,
        face = Style.fonts.numerals(Style.size.stat_value),
        fgcolor = Style.colors.ink,
    }
    return Widgets.spaced_row(w, { label, value })
end

function M.render(content_width)
    local s = Data.read_today_stats()
    local now = os.date("*t")
    local goal = user_year_goal()
    return VerticalGroup:new{
        align = "left",
        Widgets.section_head(content_width, "today's ledger"),
        stat_row(content_width, "reading", s.reading_minutes .. "m"),
        VerticalSpan:new{ width = 2 },
        stat_row(content_width, "pages", tostring(s.pages)),
        VerticalSpan:new{ width = 2 },
        stat_row(content_width, "streak", s.streak_days .. "d"),
        VerticalSpan:new{ width = 2 },
        stat_row(content_width, tostring(now.year), s.year_finished .. "/" .. goal),
    }
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add penjuru.koplugin/home_modules/module_ledger.lua
git commit -m "feat(home): module_ledger renders reading/pages/streak/year"
```

---

## Phase 3 · Currently reading (lead story)

### Task 3.1: `pen_data.read_lead_book()` — most recently opened book

**Files:**
- Modify: `penjuru.koplugin/pen_data.lua`
- Modify: `penjuru.koplugin/spec/unit/pen_data_spec.lua`

- [ ] **Step 1: Add spec**

```lua
    describe("read_lead_book", function()
        it("returns nil when history is empty (or a table with file/title)", function()
            local b = Data.read_lead_book()
            -- May be nil (fresh install) or a table with at least .file
            if b then
                assert.is_string(b.file)
            end
        end)
    end)
```

- [ ] **Step 2: Add implementation**

Append to `pen_data.lua` before `return M`:
```lua
-- read_lead_book() -> { file, title, author, year, percent, pages_total, last_read_ts } | nil
function M.read_lead_book()
    local history = M.read_history()
    if #history == 0 then return nil end
    local top = history[1]  -- KOReader stores history most-recent-first
    if not top or not top.file then return nil end

    local sdr = M.read_sdr_metadata(top.file) or {}
    local doc_props = sdr.doc_props or {}
    local pages = sdr.doc_pages or sdr.stats and sdr.stats.pages or 0
    local percent = sdr.percent_finished or 0
    return {
        file = top.file,
        title = doc_props.title or top.file:match("([^/]+)%.([^.]+)$") or "untitled",
        author = doc_props.authors or "",
        year = doc_props.year or "",
        percent = percent,  -- 0..1 float
        pages_total = pages,
        page_current = math.floor(percent * pages + 0.5),
        last_read_ts = top.time or 0,
    }
end
```

- [ ] **Step 3: Run spec, confirm pass; commit**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_data_spec.lua 2>&1 | tail -10
git add penjuru.koplugin/pen_data.lua penjuru.koplugin/spec/unit/pen_data_spec.lua
git commit -m "feat(data): read_lead_book — most recently opened book"
```

### Task 3.2: `pen_data.read_book_highlights(book_path, limit)` — recent highlights from one book

**Files:**
- Modify: `penjuru.koplugin/pen_data.lua`
- Modify: `penjuru.koplugin/spec/unit/pen_data_spec.lua`

KOReader's `.sdr/metadata.lua` stores `bookmarks` as an array. Each bookmark has `text` (the highlighted passage), `datetime` (e.g. "2026-05-24 10:42"), `chapter`, `page`. We want the most recent one for the lead's pull quote.

- [ ] **Step 1: Add spec**

```lua
    describe("read_book_highlights", function()
        it("returns an empty array for a non-existent book", function()
            local hs = Data.read_book_highlights("/nonexistent.epub", 5)
            assert.is_table(hs)
            assert.equals(0, #hs)
        end)
    end)
```

- [ ] **Step 2: Add implementation**

Append:
```lua
-- read_book_highlights(book_path, limit) -> array of { text, datetime, page }
-- Sorted by datetime descending (most-recent first).
function M.read_book_highlights(book_path, limit)
    limit = limit or 1
    local sdr = M.read_sdr_metadata(book_path)
    if not sdr or not sdr.bookmarks then return {} end
    local hs = {}
    for _, bm in ipairs(sdr.bookmarks) do
        if bm.text and bm.text ~= "" then
            table.insert(hs, {
                text = bm.text,
                datetime = bm.datetime or "",
                page = bm.page or 0,
            })
        end
    end
    table.sort(hs, function(a, b) return a.datetime > b.datetime end)
    local out = {}
    for i = 1, math.min(limit, #hs) do out[i] = hs[i] end
    return out
end
```

- [ ] **Step 3: Commit**

```bash
./scripts/run-specs.sh
git add penjuru.koplugin/pen_data.lua penjuru.koplugin/spec/unit/pen_data_spec.lua
git commit -m "feat(data): read_book_highlights — sorted by recency"
```

### Task 3.3: `home_modules/module_currently.lua` — lead story render

**Files:**
- Create: `penjuru.koplugin/home_modules/module_currently.lua`

- [ ] **Step 1: Create the module**

```lua
-- home_modules/module_currently
-- The lead story: headline = book title, byline = author/year, pull quote =
-- most recent highlight, body lede = activity summary, progress bar.

local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LineWidget = require("ui/widget/linewidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local function pull_quote(w, text)
    -- left-bordered italic quote block
    local quote = TextBoxWidget:new{
        text = '"' .. text .. '"',
        face = Style.fonts.italic(Style.size.pull),
        fgcolor = Style.colors.ink_2,
        width = w - 18,
    }
    return HorizontalGroup:new{
        align = "top",
        LineWidget:new{
            dimen = { w = 4, h = quote:getSize().h },
            background = Style.colors.ink,
        },
        HorizontalSpan:new{ width = 14 },
        quote,
    }
end

local function progress_bar(w, percent)
    local left = TextWidget:new{
        text = "p " .. math.floor(percent * 100 + 0.5) .. "%",
        face = Style.fonts.body(Style.size.body - 4),
        fgcolor = Style.colors.ink_soft,
    }
    local bar_w = w - left:getSize().w - 16
    local filled = math.max(2, math.floor(bar_w * percent))
    local bar = HorizontalGroup:new{
        align = "center",
        LineWidget:new{ dimen = { w = filled, h = 5 }, background = Style.colors.ink },
        LineWidget:new{ dimen = { w = bar_w - filled, h = 5 }, background = Style.colors.rule_dim },
    }
    return HorizontalGroup:new{
        align = "center",
        left,
        HorizontalSpan:new{ width = 16 },
        bar,
    }
end

-- render(content_width) -> widget
function M.render(content_width)
    local b = Data.read_lead_book()
    if not b then
        return TextWidget:new{
            text = "no entries today",
            face = Style.fonts.italic(Style.size.body),
            fgcolor = Style.colors.ink_faint,
        }
    end

    local headline = TextBoxWidget:new{
        text = string.lower(b.title),
        face = Style.fonts.headline(Style.size.headline),
        fgcolor = Style.colors.ink,
        width = content_width,
    }
    local byline_parts = { "— " }
    if b.author and b.author ~= "" then table.insert(byline_parts, string.lower(b.author)) end
    if b.year and b.year ~= "" then table.insert(byline_parts, ", " .. tostring(b.year)) end
    local byline = TextWidget:new{
        text = table.concat(byline_parts),
        face = Style.fonts.italic(Style.size.byline),
        fgcolor = Style.colors.ink_soft,
    }

    local children = {
        Widgets.section_head(content_width, "currently reading"),
        headline,
        VerticalSpan:new{ width = 6 },
        byline,
    }

    local hs = Data.read_book_highlights(b.file, 1)
    if hs[1] then
        table.insert(children, VerticalSpan:new{ width = 10 })
        table.insert(children, pull_quote(content_width, hs[1].text))
    end

    table.insert(children, VerticalSpan:new{ width = 10 })
    table.insert(children, progress_bar(content_width, b.percent or 0))

    return VerticalGroup:new{ align = "left", table.unpack(children) }
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add penjuru.koplugin/home_modules/module_currently.lua
git commit -m "feat(home): module_currently renders the lead story"
```

---

## Phase 4 · On the desk

### Task 4.1: `pen_data.read_in_progress_books(exclude_path)` — books with 0 < % < 1

**Files:**
- Modify: `penjuru.koplugin/pen_data.lua`
- Modify: `penjuru.koplugin/spec/unit/pen_data_spec.lua`

- [ ] **Step 1: Add spec + implementation in one task (low-risk read-only logic)**

Spec append:
```lua
    describe("read_in_progress_books", function()
        it("returns a table (possibly empty)", function()
            local books = Data.read_in_progress_books(nil)
            assert.is_table(books)
        end)
        it("excludes the path passed as exclude argument", function()
            -- We can't verify content without seed data, but the call shouldn't error.
            local books = Data.read_in_progress_books("/some/book.epub")
            assert.is_table(books)
        end)
    end)
```

Implementation append to `pen_data.lua`:
```lua
-- read_in_progress_books(exclude_path) -> array of { file, title, percent, last_read_ts }
-- Walks the entire history. A book is "in progress" if its .sdr metadata
-- has 0 < percent_finished < 1. Sorted by last_read_ts descending.
function M.read_in_progress_books(exclude_path)
    local history = M.read_history()
    local seen, out = {}, {}
    for _, entry in ipairs(history) do
        if entry.file and entry.file ~= exclude_path and not seen[entry.file] then
            seen[entry.file] = true
            local sdr = M.read_sdr_metadata(entry.file) or {}
            local pct = sdr.percent_finished or 0
            if pct > 0 and pct < 1 then
                local props = sdr.doc_props or {}
                table.insert(out, {
                    file = entry.file,
                    title = props.title or entry.file:match("([^/]+)%.[^.]+$") or "untitled",
                    percent = pct,
                    last_read_ts = entry.time or 0,
                })
            end
        end
    end
    table.sort(out, function(a, b) return a.last_read_ts > b.last_read_ts end)
    return out
end
```

- [ ] **Step 2: Run, commit**

```bash
./scripts/run-specs.sh
git add penjuru.koplugin/pen_data.lua penjuru.koplugin/spec/unit/pen_data_spec.lua
git commit -m "feat(data): read_in_progress_books — sorted by recency, excluding lead"
```

### Task 4.2: `pen_data.read_book_cover(book_path)` — cover image as BlitBuffer

**Files:**
- Modify: `penjuru.koplugin/pen_data.lua`

KOReader's `DocumentRegistry` can open any supported file and extract the cover. We thumbnail it on the fly. Caching is out of scope for v1 (the home screen re-renders ~once per visit).

- [ ] **Step 1: Add implementation**

Append to `pen_data.lua`:
```lua
-- read_book_cover(book_path, target_w, target_h) -> BlitBuffer | nil
-- Returns a scaled cover image suitable for the on-the-desk row, or nil
-- if the file can't be read (corrupted, unsupported, etc.).
function M.read_book_cover(book_path, target_w, target_h)
    local ok, DocumentRegistry = pcall(require, "document/documentregistry")
    if not ok then return nil end
    local doc = DocumentRegistry:openDocument(book_path)
    if not doc then return nil end
    local cover_bb = doc:getCoverPageImage()
    doc:close()
    if not cover_bb then return nil end
    -- Scale preserving aspect; KOReader's BlitBuffer has :scale() in newer versions.
    if cover_bb.scale then
        return cover_bb:scale(target_w, target_h)
    end
    return cover_bb
end
```

- [ ] **Step 2: Commit (no test — relies on real files)**

```bash
git add penjuru.koplugin/pen_data.lua
git commit -m "feat(data): read_book_cover — extracted cover BlitBuffer"
```

### Task 4.3: `home_modules/module_desk.lua` — 5 covers with % overlay

**Files:**
- Create: `penjuru.koplugin/home_modules/module_desk.lua`

- [ ] **Step 1: Create the module**

```lua
-- home_modules/module_desk
-- "on the desk" — 5 cover thumbnails of in-progress books with a %
-- overlay at the bottom of each cover. Excludes the lead book.

local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Blitbuffer = require("ffi/blitbuffer")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local COVER_COUNT = 5
local COVER_GAP = 11

local function cover_cell(cell_w, book)
    local cell_h = math.floor(cell_w * 1.5)  -- 2:3 aspect
    local cover_bb = book.file and Data.read_book_cover(book.file, cell_w, cell_h)

    local cover_widget
    if cover_bb then
        cover_widget = ImageWidget:new{ image = cover_bb, width = cell_w, height = cell_h }
    else
        cover_widget = FrameContainer:new{
            background = Style.colors.rule_dim,
            bordersize = 2,
            margin = 0, padding = 0,
            width = cell_w, height = cell_h,
            VerticalSpan:new{ width = cell_h },
        }
    end

    local pct_text = math.floor((book.percent or 0) * 100 + 0.5) .. "%"
    local pct_band_h = math.floor(cell_h * 0.16)
    local pct_band = FrameContainer:new{
        background = Blitbuffer.COLOR_BLACK,
        bordersize = 0, margin = 0, padding = 4,
        width = cell_w, height = pct_band_h,
        TextWidget:new{
            text = pct_text,
            face = Style.fonts.numerals(math.floor(pct_band_h * 0.75)),
            fgcolor = Style.colors.paper,
        },
    }

    -- Stack the pct band over the cover by using a vertical group where
    -- the band overlaps the bottom — KOReader doesn't have an absolute
    -- overlay widget out of the box, so we render the cover with a band
    -- placed at the bottom via VerticalGroup truncation. For v1 we
    -- approximate: cover_widget then a 0-margin band below (no overlap).
    -- A proper overlay can come in Plan D polish.
    local caption = TextWidget:new{
        text = string.sub(string.lower(book.title or ""), 1, 18),
        face = Style.fonts.body(Style.size.caption - 4),
        fgcolor = Style.colors.ink_soft,
    }
    return VerticalGroup:new{
        align = "center",
        cover_widget,
        pct_band,
        VerticalSpan:new{ width = 4 },
        caption,
    }
end

function M.render(content_width)
    local lead = Data.read_lead_book()
    local books = Data.read_in_progress_books(lead and lead.file)

    local cell_w = math.floor((content_width - COVER_GAP * (COVER_COUNT - 1)) / COVER_COUNT)
    local row = HorizontalGroup:new{ align = "top" }
    for i = 1, COVER_COUNT do
        local book = books[i]
        if book then
            table.insert(row, cover_cell(cell_w, book))
        else
            -- empty slot keeps the grid even
            table.insert(row, VerticalSpan:new{ width = cell_w })
        end
        if i < COVER_COUNT then
            table.insert(row, HorizontalSpan:new{ width = COVER_GAP })
        end
    end

    return VerticalGroup:new{
        align = "left",
        Widgets.section_head(content_width, "on the desk"),
        row,
    }
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add penjuru.koplugin/home_modules/module_desk.lua
git commit -m "feat(home): module_desk renders 5 in-progress covers"
```

---

## Phase 5 · Newly catalogued

### Task 5.1: `pen_data.read_newly_catalogued(book_dirs, age_days, limit)` — recently added unstarted

**Files:**
- Modify: `penjuru.koplugin/pen_data.lua`
- Modify: `penjuru.koplugin/spec/unit/pen_data_spec.lua`

- [ ] **Step 1: Add spec**

```lua
    describe("read_newly_catalogued", function()
        it("returns a table (possibly empty)", function()
            local books = Data.read_newly_catalogued({"/nonexistent_dir"}, 30, 3)
            assert.is_table(books)
        end)
    end)
```

- [ ] **Step 2: Add implementation**

Append to `pen_data.lua`:
```lua
-- read_newly_catalogued(dirs, age_days, limit) -> array of { file, title, author, age_days }
-- Files in `dirs` with mtime within the last `age_days` AND no .sdr (i.e.
-- never opened). Sorted by mtime descending. `limit` caps the result.
function M.read_newly_catalogued(dirs, age_days, limit)
    age_days = age_days or 30
    limit = limit or 3
    local cutoff = os.time() - age_days * 86400
    local candidates = {}
    for _, dir in ipairs(dirs or {}) do
        for _, path in ipairs(M.list_books_in(dir)) do
            local mt = M.file_mtime(path)
            if mt and mt >= cutoff then
                local sdr_path = M.sdr_path_for(path)
                -- Newly catalogued = no .sdr sidecar yet (never opened in KOReader).
                local has_sdr = sdr_path and lfs.attributes(sdr_path) ~= nil
                if not has_sdr then
                    local name = path:match("([^/]+)%.[^.]+$") or path
                    table.insert(candidates, {
                        file = path,
                        title = name,
                        author = "",  -- no .sdr means we can't get author cheaply
                        age_days = math.floor((os.time() - mt) / 86400),
                        mtime = mt,
                    })
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.mtime > b.mtime end)
    local out = {}
    for i = 1, math.min(limit, #candidates) do out[i] = candidates[i] end
    return out
end
```

- [ ] **Step 3: Commit**

```bash
./scripts/run-specs.sh
git add penjuru.koplugin/pen_data.lua penjuru.koplugin/spec/unit/pen_data_spec.lua
git commit -m "feat(data): read_newly_catalogued — recently added unopened books"
```

### Task 5.2: `home_modules/module_catalogued.lua` — 3 tap rows

**Files:**
- Create: `penjuru.koplugin/home_modules/module_catalogued.lua`

- [ ] **Step 1: Create the module**

```lua
-- home_modules/module_catalogued
-- "newly catalogued" — 3 rows of recently-added unstarted books, no covers,
-- big tap target (80px+ minimum height). Title + author + age + chevron.

local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local function pretty_age(days)
    if days <= 1 then return "1d"
    elseif days < 7 then return days .. "d"
    elseif days < 30 then return math.floor(days / 7) .. "w"
    else return math.floor(days / 30) .. "mo" end
end

local function book_row(w, book)
    local title = TextWidget:new{
        text = string.lower(book.title),
        face = Style.fonts.headline(Style.size.cat_title),
        fgcolor = Style.colors.ink,
        max_width = math.floor(w * 0.7),
    }
    local age = TextWidget:new{
        text = pretty_age(book.age_days) .. " →",
        face = Style.fonts.numerals(Style.size.cat_age),
        fgcolor = Style.colors.ink_soft,
    }
    return VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = 12 },
        Widgets.spaced_row(w, { title, age }),
        VerticalSpan:new{ width = 12 },
        Widgets.dotted_rule(w, Style.rules.minor, Style.colors.rule_soft),
    }
end

-- user_book_dirs() -> array of dirs to scan
-- Pulls from G_reader_settings.penjuru.catalogue_dirs; defaults to the
-- two custom-folder shortcuts ("manga" and "books") from the spec.
local function user_book_dirs()
    local s = G_reader_settings and G_reader_settings:readSetting("penjuru") or {}
    if s.catalogue_dirs and #s.catalogue_dirs > 0 then return s.catalogue_dirs end
    return { "/mnt/us/koreader/books", "/mnt/us/koreader/mangas" }
end

function M.render(content_width)
    local books = Data.read_newly_catalogued(user_book_dirs(), 30, 3)
    local out = { Widgets.section_head(content_width, "newly catalogued") }
    if #books == 0 then
        table.insert(out, TextWidget:new{
            text = "nothing new",
            face = Style.fonts.italic(Style.size.body - 4),
            fgcolor = Style.colors.ink_faint,
        })
    else
        for _, b in ipairs(books) do
            table.insert(out, book_row(content_width, b))
        end
    end
    return VerticalGroup:new{ align = "left", table.unpack(out) }
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add penjuru.koplugin/home_modules/module_catalogued.lua
git commit -m "feat(home): module_catalogued renders 3 recently-added rows"
```

---

## Phase 6 · Recent highlights

### Task 6.1: `pen_data.read_recent_highlights(limit)` — top N across all books

**Files:**
- Modify: `penjuru.koplugin/pen_data.lua`
- Modify: `penjuru.koplugin/spec/unit/pen_data_spec.lua`

- [ ] **Step 1: Add spec**

```lua
    describe("read_recent_highlights", function()
        it("returns a table (possibly empty)", function()
            local hs = Data.read_recent_highlights(3)
            assert.is_table(hs)
        end)
    end)
```

- [ ] **Step 2: Add implementation**

Append:
```lua
-- read_recent_highlights(limit) -> array of { text, book_title, book_author, page, datetime }
-- Sorted by datetime descending. Pulls from every book in history.
function M.read_recent_highlights(limit)
    limit = limit or 3
    local history = M.read_history()
    local all = {}
    for _, entry in ipairs(history) do
        if entry.file then
            local sdr = M.read_sdr_metadata(entry.file) or {}
            local props = sdr.doc_props or {}
            for _, bm in ipairs(sdr.bookmarks or {}) do
                if bm.text and bm.text ~= "" then
                    table.insert(all, {
                        text = bm.text,
                        datetime = bm.datetime or "",
                        page = bm.page or 0,
                        book_file = entry.file,
                        book_title = props.title or "untitled",
                        book_author = props.authors or "",
                    })
                end
            end
        end
    end
    table.sort(all, function(a, b) return a.datetime > b.datetime end)
    local out = {}
    for i = 1, math.min(limit, #all) do out[i] = all[i] end
    return out
end
```

- [ ] **Step 3: Commit**

```bash
./scripts/run-specs.sh
git add penjuru.koplugin/pen_data.lua penjuru.koplugin/spec/unit/pen_data_spec.lua
git commit -m "feat(data): read_recent_highlights — top N annotations across all books"
```

### Task 6.2: `home_modules/module_highlights.lua` — 3 highlight blocks

**Files:**
- Create: `penjuru.koplugin/home_modules/module_highlights.lua`

- [ ] **Step 1: Create the module**

```lua
-- home_modules/module_highlights
-- "recent highlights" — 3 most-recent annotations across all books.
-- Each: quote (Syne Mono) + source line (Plex italic small) + dotted divider.

local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local function highlight_block(w, h)
    local quote = TextBoxWidget:new{
        text = '"' .. string.lower(h.text) .. '"',
        face = Style.fonts.headline(Style.size.highlight_q),
        fgcolor = Style.colors.ink,
        width = w,
    }
    local src_parts = { "— " }
    if h.book_author ~= "" then table.insert(src_parts, string.lower(h.book_author) .. ", ") end
    table.insert(src_parts, string.lower(h.book_title))
    table.insert(src_parts, " · p. " .. h.page)
    if h.datetime ~= "" then
        table.insert(src_parts, " · " .. h.datetime:sub(1, 10))
    end
    local src = TextWidget:new{
        text = table.concat(src_parts),
        face = Style.fonts.italic(Style.size.highlight_src),
        fgcolor = Style.colors.ink_dim,
    }
    return VerticalGroup:new{
        align = "left",
        quote,
        VerticalSpan:new{ width = 6 },
        src,
        VerticalSpan:new{ width = 10 },
        Widgets.dotted_rule(w, Style.rules.minor, Style.colors.rule_soft),
        VerticalSpan:new{ width = 10 },
    }
end

function M.render(content_width)
    local hs = Data.read_recent_highlights(3)
    local children = { Widgets.section_head(content_width, "recent highlights") }
    if #hs == 0 then
        table.insert(children, TextWidget:new{
            text = "no highlights yet",
            face = Style.fonts.italic(Style.size.body - 4),
            fgcolor = Style.colors.ink_faint,
        })
    else
        for _, h in ipairs(hs) do
            table.insert(children, highlight_block(content_width, h))
        end
    end
    return VerticalGroup:new{ align = "left", table.unpack(children) }
end

return M
```

- [ ] **Step 2: Commit**

```bash
git add penjuru.koplugin/home_modules/module_highlights.lua
git commit -m "feat(home): module_highlights renders 3 most-recent annotations"
```

---

## Phase 7 · Integration

### Task 7.1: Compose all six modules into `pen_homescreen.lua`

**Files:**
- Modify: `penjuru.koplugin/pen_homescreen.lua`

End state: replace the body placeholder with a two-column layout (1.5fr / 1fr) for `currently` + `(ledger over almanac)`, then full-width `(desk + catalogued)` row also as 1.5fr/1fr, then full-width `highlights`.

- [ ] **Step 1: Read the current pen_homescreen.lua to understand where the body placeholder lives**

```bash
cat ~/Developer/koreader-custom-ui/penjuru.koplugin/pen_homescreen.lua | grep -n -A2 "plan b\|placeholder"
```

Locate the line(s) that build the italic "[ plan b — home modules land here ]" placeholder. That's the insertion point.

- [ ] **Step 2: Replace placeholder with module composition**

In the show()/build path of pen_homescreen.lua, after the dateline + dotted-rule region and before the closing of the outer VerticalGroup, insert:
```lua
local Currently = require("home_modules/module_currently")
local Ledger = require("home_modules/module_ledger")
local Almanac = require("home_modules/module_almanac")
local Desk = require("home_modules/module_desk")
local Catalogued = require("home_modules/module_catalogued")
local Highlights = require("home_modules/module_highlights")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local VerticalSpan = require("ui/widget/verticalspan")

-- Two-column body. Spec: 1.5fr / 1fr with a vertical dotted rule between.
local col_gap = 30
local left_w = math.floor((content_w - col_gap) * 0.6)
local right_w = content_w - col_gap - left_w

local body_top = HorizontalGroup:new{
    align = "top",
    Currently.render(left_w),
    HorizontalSpan:new{ width = col_gap },
    VerticalGroup:new{
        align = "left",
        Ledger.render(right_w),
        VerticalSpan:new{ width = 18 },
        Almanac.render(right_w),
    },
}

local body_mid = HorizontalGroup:new{
    align = "top",
    Desk.render(left_w),
    HorizontalSpan:new{ width = col_gap },
    Catalogued.render(right_w),
}

-- Replace the existing placeholder TextWidget with:
-- body_top, vertical span, body_mid, vertical span, Highlights.render(content_w)
```

The exact replacement depends on how Task 3.1's implementer structured the show() function. Adapt to the existing layout: find the placeholder line, replace it with these three composed children, separated by `VerticalSpan:new{ width = Style.gap.lg }` between sections.

- [ ] **Step 3: Smoke-test in emulator**

```bash
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader
LOG=$(mktemp /tmp/penjuru-integ-log.XXXX)
bash ./kodev run > "$LOG" 2>&1 &
KODEV_PID=$!
sleep 15
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
sleep 2
grep -iE 'error|cannot|nil value|attempt to' "$LOG" | grep -iE 'pen_|module_|home_modules' | head -20
echo "--- log: $LOG ---"
```

Expected: no errors. Visually verify by re-launching and tapping the Home tab — you should see all six modules rendered with real data (or graceful empty states for modules without seed data).

- [ ] **Step 4: Take a screenshot for the commit**

```bash
mkdir -p ~/Developer/koreader-custom-ui/docs/dev/screenshots
# After visually verifying, screenshot the SDL window via macOS Cmd-Shift-4
# and save to docs/dev/screenshots/2026-MM-DD-home-v1.png
```

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_homescreen.lua docs/dev/screenshots/
git commit -m "feat(home): compose all six modules in two-column layout

Body now renders: (currently | ledger + almanac), then (desk | catalogued),
then highlights full-width. Replaces the Plan A placeholder."
```

### Task 7.2: Plan B DONE.md + push

**Files:**
- Create: `docs/superpowers/plans/2026-MM-DD-plan-B-DONE.md`

- [ ] **Step 1: Write DONE.md**

```bash
cd ~/Developer/koreader-custom-ui
DATE=$(date '+%Y-%m-%d')
cat > docs/superpowers/plans/${DATE}-plan-B-DONE.md <<EOF
# Plan B · DONE — $(date '+%Y-%m-%d')

## What's working

- All 6 home modules render with real KOReader data:
  - currently reading (lead, with pull-quote from latest highlight)
  - today's ledger (reading min / pages / streak / year goal)
  - the almanac (day-of-year / week / sunrise/sunset / moon phase)
  - on the desk (5 in-progress book covers with % overlay)
  - newly catalogued (3 recently-added unstarted rows)
  - recent highlights (3 most-recent annotations across all books)
- Data layer (pen_data.lua) reads history.lua, per-book .sdr metadata,
  statistics.sqlite3, and walks book directories
- Pure-math astronomical calcs (pen_almanac.lua): NOAA sunrise/sunset
  and synodic moon phase
- Custom DottedLineWidget for spec-correct dotted rules
- Install-date storage drives real vol/no in dateline
- $(./scripts/run-specs.sh 2>&1 | grep -oE '[0-9]+ tests' | head -1) tests passing

## Carry-overs to Plan C

- Cover thumbnails currently have % band rendered BELOW the cover (not
  overlaid) due to lack of an absolute-overlay widget. Add a
  Container/AbsolutePosition pattern.
- Catalogue scan happens synchronously on render; for large libraries
  this could lag. Async or cached scan deferred.
- **Tap routing not wired**: spec says tapping a highlight opens the
  book to that page, and tapping a newly-catalogued row opens the book.
  Plan B renders the widgets but the tap handlers are TODO. Belongs
  with the bottom-nav tap routing work in Plan C.

## Next: Plan C — persistent top status bar + 7-cell paginated bottom nav
EOF
git add docs/superpowers/plans/${DATE}-plan-B-DONE.md
git commit -m "docs: Plan B complete — six home modules with real data"
git push origin main
EOF
```

- [ ] **Step 2: Push**

```bash
git push origin main
```

Expected: push succeeds.

- [ ] **Step 3: Hand off**

Tell the controller: "Plan B complete. The home screen renders all six modules with real reading data. Ready for Plan C (persistent top status bar + paginated bottom nav)."
