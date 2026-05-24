# penjuru.koplugin · Plan C — Persistent Chrome (Top Bar + Bottom Nav)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the persistent top status bar (clock · wi-fi · light · disk · battery) and the 7-cell paginated bottom nav (chevron · 5 tabs · chevron · two pages), then wire tap routing on home-screen highlights and newly-catalogued rows so they open the targeted book.

**Architecture:** Three new modules — `pen_topbar.lua` (status row), `pen_tabs.lua` (tab roster + pagination state), `pen_bottombar.lua` (7-cell rendering + tap dispatch). A small `pen_icons.lua` helper bundles 1.6px-stroke SVGs in `icons/penjuru/` and serves them as `BlitBuffer` images at requested sizes. `pen_homescreen.lua` mounts the top bar at the top and the bottom bar at the bottom of its render output. Wider "every screen" injection (file browser, reader) is out of scope for v1 — those screens keep KOReader's stock chrome.

**Tech Stack:** Lua 5.1, KOReader v2026.03 widget system (TextWidget, ImageWidget, HorizontalGroup, VerticalGroup, GestureRange, TouchMenu callbacks), pen_widgets / pen_style / pen_data from Plans A+B, KOReader's `NetworkMgr` for wi-fi state, `Device:getPowerDevice()` for battery, `Device.screen:getDPI()` for frontlight, `lfs.attributes(path).blocks/blksize` for free disk, busted for tests.

**Plan B carry-overs being closed here:**
- Tap routing on highlights → open book to the highlighted page
- Tap routing on newly-catalogued rows → open the book

**Plan C carry-overs to Plan D:**
- Bars persisting on file-browser and reader views (we hook only the home screen in this plan)
- Cover %-overlay polish (Plan B noted it; we can address in Plan D's polish pass)
- Settings UI for tab roster / status-bar item layout (we ship sensible defaults; Plan D adds the UI)

---

## File structure (new in Plan C)

```
penjuru.koplugin/
├── pen_icons.lua                      [Phase 0]  SVG loader, role -> BlitBuffer
├── icons/penjuru/                     [Phase 0]  our SVG library
│   ├── chevron-left.svg
│   ├── chevron-right.svg
│   ├── tab-home.svg
│   ├── tab-library.svg
│   ├── tab-books.svg
│   ├── tab-manga.svg
│   ├── tab-games.svg
│   ├── tab-wifi.svg
│   ├── tab-brightness.svg
│   ├── tab-stats.svg
│   ├── tab-power.svg
│   ├── tab-search.svg
│   ├── status-clock.svg               (optional — clock can be text)
│   ├── status-wifi.svg
│   ├── status-light.svg
│   ├── status-disk.svg
│   └── status-battery.svg
├── pen_topbar.lua                     [Phase 1]  status row widget
├── pen_status.lua                     [Phase 1]  read clock / wifi / light / disk / battery
├── pen_tabs.lua                       [Phase 2]  tab roster, pagination, default config
├── pen_bottombar.lua                  [Phase 3]  7-cell row + tap dispatch
├── pen_actions.lua                    [Phase 4]  callback library (open-folder/plugin/etc.)
├── home_modules/module_highlights.lua [MOD Phase 5]  add tap handler
├── home_modules/module_catalogued.lua [MOD Phase 5]  add tap handler
├── pen_homescreen.lua                 [MOD Phase 6]  mount top + bottom bars
└── spec/unit/
    ├── pen_status_spec.lua
    ├── pen_tabs_spec.lua
    └── pen_actions_spec.lua
```

The existing `pen_topbar.lua` and `pen_bottombar.lua` (forked from SimpleUI) get stashed as `.old_simpleui` per the Plan A/B convention.

---

## Phase 0 · Icon set

### Task 0.1: Author the 12 tab/chevron SVG icons

**Files:**
- Create: `penjuru.koplugin/icons/penjuru/` (directory)
- Create: 12 SVG files inside it

The icons match the home-mockup designs we built in brainstorming. All 1.6px stroke, currentColor stroke, no fill, 24×24 viewBox so they scale.

- [ ] **Step 1: Make the directory and write the chevron pair**

```bash
mkdir -p ~/Developer/koreader-custom-ui/penjuru.koplugin/icons/penjuru
cd ~/Developer/koreader-custom-ui/penjuru.koplugin/icons/penjuru
```

`chevron-left.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <polyline points="15 6 9 12 15 18"/>
</svg>
```

`chevron-right.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <polyline points="9 6 15 12 9 18"/>
</svg>
```

- [ ] **Step 2: Write the page-1 tab icons (5 files)**

`tab-home.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3 11 L12 3 L21 11"/>
  <path d="M5 10 L5 20 L19 20 L19 10"/>
  <rect x="10" y="13" width="4" height="7"/>
</svg>
```

`tab-manga.svg` (4-panel grid):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="3" width="8" height="9"/>
  <rect x="13" y="3" width="8" height="6"/>
  <rect x="3" y="14" width="6" height="7"/>
  <rect x="11" y="11" width="10" height="10"/>
</svg>
```

`tab-books.svg` (3 stacked book spines):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="4" width="4" height="16"/>
  <rect x="9" y="4" width="4" height="16"/>
  <rect x="15" y="6" width="4" height="14"/>
  <line x1="3" y1="9" x2="7" y2="9"/>
  <line x1="9" y1="9" x2="13" y2="9"/>
</svg>
```

`tab-wifi.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <path d="M3 9c5-5 13-5 18 0"/>
  <path d="M6 13c3-3 9-3 12 0"/>
  <path d="M9 17c2-2 4-2 6 0"/>
  <circle cx="12" cy="20" r="0.8" fill="currentColor"/>
</svg>
```

`tab-games.svg` (gamepad):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <rect x="2" y="7" width="20" height="11" rx="4"/>
  <line x1="6" y1="12" x2="10" y2="12"/>
  <line x1="8" y1="10" x2="8" y2="14"/>
  <circle cx="16" cy="11" r="1"/>
  <circle cx="18.5" cy="13.5" r="1"/>
</svg>
```

- [ ] **Step 3: Write the page-2 tab icons (5 files)**

`tab-stats.svg` (bar chart):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <line x1="4" y1="20" x2="4" y2="10"/>
  <line x1="10" y1="20" x2="10" y2="4"/>
  <line x1="16" y1="20" x2="16" y2="14"/>
  <line x1="22" y1="20" x2="22" y2="8"/>
</svg>
```

`tab-brightness.svg` (sun):
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="12" cy="12" r="4"/>
  <line x1="12" y1="2" x2="12" y2="5"/>
  <line x1="12" y1="19" x2="12" y2="22"/>
  <line x1="2" y1="12" x2="5" y2="12"/>
  <line x1="19" y1="12" x2="22" y2="12"/>
  <line x1="5" y1="5" x2="7" y2="7"/>
  <line x1="17" y1="17" x2="19" y2="19"/>
  <line x1="5" y1="19" x2="7" y2="17"/>
  <line x1="17" y1="7" x2="19" y2="5"/>
</svg>
```

`tab-power.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <path d="M7 5a8 8 0 1 0 10 0"/>
  <line x1="12" y1="3" x2="12" y2="12"/>
</svg>
```

`tab-search.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <circle cx="11" cy="11" r="7"/>
  <line x1="20" y1="20" x2="16" y2="16"/>
</svg>
```

`tab-library.svg`:
```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round">
  <rect x="3" y="5" width="4" height="14"/>
  <rect x="9" y="5" width="4" height="14"/>
  <rect x="15" y="7" width="4" height="12"/>
  <line x1="2" y1="20" x2="22" y2="20"/>
</svg>
```

- [ ] **Step 4: Commit the icon set**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/icons/penjuru/
git commit -m "feat(icons): 12 SVG icons for tabs + chevrons

1.6px stroke, currentColor, 24x24 viewBox. Matches the bottom-nav
design in brainstorming mockups: chevron-left/right + tab icons for
home/manga/books/wifi/games/stats/brightness/power/search/library."
```

### Task 0.2: `pen_icons.lua` — load SVG to BlitBuffer

**Files:**
- Create: `penjuru.koplugin/pen_icons.lua`
- Create: `penjuru.koplugin/spec/unit/pen_icons_spec.lua`

KOReader's `ui/widget/iconwidget` already supports SVG via its `RenderImage` helper (which uses NanoSVG under the hood). We expose a thin wrapper that loads our bundled icons by short name and caches the resulting `BlitBuffer` per (name, size).

- [ ] **Step 1: Write the spec**

Create `penjuru.koplugin/spec/unit/pen_icons_spec.lua`:
```lua
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_icons", function()
    local Icons
    setup(function() Icons = require("pen_icons") end)

    it("resolves a known icon path", function()
        local p = Icons.path("tab-home")
        assert.is_string(p)
        assert.is_true(p:match("tab%-home%.svg$") ~= nil)
    end)

    it("errors on unknown icon name", function()
        assert.has_error(function() Icons.path("nonexistent-icon-xyz") end)
    end)

    it("returns an IconWidget for a known icon", function()
        local w = Icons.widget("tab-home", 62)
        assert.is_not_nil(w)
        -- IconWidget should expose getSize()
        local size = w:getSize()
        assert.is_number(size.w)
        assert.is_number(size.h)
    end)
end)
```

- [ ] **Step 2: Run, confirm fail**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_icons_spec.lua 2>&1 | tail -8
```

Expected: `module 'pen_icons' not found`.

- [ ] **Step 3: Implement `pen_icons.lua`**

Create `penjuru.koplugin/pen_icons.lua`:
```lua
-- penjuru/pen_icons
-- Loads SVG icons from our bundled icons/penjuru/ directory.
-- Returns IconWidget instances (KOReader handles SVG -> BlitBuffer via NanoSVG).

local IconWidget = require("ui/widget/iconwidget")

local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local icon_dir = plugin_dir .. "icons/penjuru/"

local M = {}

-- path(name) -> string  -- absolute path to icons/penjuru/<name>.svg
function M.path(name)
    local p = icon_dir .. name .. ".svg"
    local f = io.open(p, "r")
    if not f then
        error("pen_icons: unknown icon '" .. tostring(name) .. "' (looked for " .. p .. ")")
    end
    f:close()
    return p
end

-- widget(name, size_px) -> IconWidget
function M.widget(name, size_px)
    return IconWidget:new{
        icon = M.path(name),
        width = size_px,
        height = size_px,
        is_freedesktop_icon = false,
    }
end

return M
```

- [ ] **Step 4: Run spec, confirm pass**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_icons_spec.lua 2>&1 | tail -8
```

Expected: 3 successes. Grand total: 56.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_icons.lua penjuru.koplugin/spec/unit/pen_icons_spec.lua
git commit -m "feat(icons): pen_icons resolves SVG by short name, returns IconWidget

Wraps KOReader's IconWidget so callers say Icons.widget('tab-home', 62)
instead of constructing the widget + computing the path each time.
Errors loudly on unknown names so typos surface immediately."
```

---

## Phase 1 · Top status bar

### Task 1.1: `pen_status.lua` — read device status (TDD where possible)

**Files:**
- Create: `penjuru.koplugin/pen_status.lua`
- Create: `penjuru.koplugin/spec/unit/pen_status_spec.lua`

Pure-data getters that read KOReader's device singletons. Each is independently testable in shape; actual values depend on runtime hardware so specs verify contracts, not numbers.

- [ ] **Step 1: Write the spec**

Create `penjuru.koplugin/spec/unit/pen_status_spec.lua`:
```lua
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_status", function()
    local S
    setup(function() S = require("pen_status") end)

    it("clock() returns HH:MM string", function()
        local s = S.clock()
        assert.is_string(s)
        assert.is_true(s:match("^%d%d:%d%d$") ~= nil, "got '" .. s .. "'")
    end)

    it("battery_pct() returns a number 0-100 or nil", function()
        local p = S.battery_pct()
        if p ~= nil then
            assert.is_number(p)
            assert.is_true(p >= 0 and p <= 100)
        end
    end)

    it("wifi_label() returns a short string", function()
        local s = S.wifi_label()
        assert.is_string(s)
    end)

    it("frontlight_label() returns a string or nil", function()
        local s = S.frontlight_label()
        if s ~= nil then assert.is_string(s) end
    end)

    it("disk_label() returns a short string", function()
        local s = S.disk_label()
        assert.is_string(s)
    end)
end)
```

- [ ] **Step 2: Run, confirm fail**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_status_spec.lua 2>&1 | tail -8
```

Expected: `module 'pen_status' not found`.

- [ ] **Step 3: Implement `pen_status.lua`**

Create `penjuru.koplugin/pen_status.lua`:
```lua
-- penjuru/pen_status
-- Reads device state for the top status bar. Each accessor returns the
-- short label string the bar will render. Robust to missing subsystems —
-- if KOReader can't report something (e.g. no battery on desktop emulator),
-- returns a sensible string ("--") or nil and the bar omits it.

local M = {}

function M.clock()
    return os.date("%H:%M")
end

function M.battery_pct()
    local ok, Device = pcall(require, "device")
    if not ok or not Device then return nil end
    local p = Device:getPowerDevice()
    if not p or not p.capacity then return nil end
    local ok2, pct = pcall(p.capacity, p)
    if not ok2 then return nil end
    return pct
end

function M.battery_label()
    local p = M.battery_pct()
    if not p then return "--%" end
    return string.format("%d%%", p)
end

function M.wifi_label()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok or not NetworkMgr then return "wi-fi" end
    if NetworkMgr:isWifiOn() then return "wi-fi" end
    return "wi-fi off"
end

function M.frontlight_label()
    local ok, Device = pcall(require, "device")
    if not ok or not Device or not Device:hasFrontlight() then return nil end
    local fl = Device:getPowerDevice()
    if not fl or not fl.frontlight_intensity then return nil end
    return string.format("light %d", fl.frontlight_intensity)
end

function M.disk_label()
    -- Free space on the settings volume. macOS emulator: ~/Developer/koreader.
    local ok, DataStorage = pcall(require, "datastorage")
    if not ok then return "" end
    local path = DataStorage:getSettingsDir()
    local ok2, util = pcall(require, "util")
    if not ok2 or not util.getFilesystemInfo then
        return ""  -- older KOReader; skip
    end
    local info = util.getFilesystemInfo(path)
    if not info or not info.free then return "" end
    -- Bytes -> human-readable GB
    local gb = info.free / (1024 * 1024 * 1024)
    if gb >= 10 then return string.format("%d gb", math.floor(gb)) end
    return string.format("%.1f gb", gb)
end

return M
```

- [ ] **Step 4: Run spec, confirm pass**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_status_spec.lua 2>&1 | tail -10
```

Expected: 5 successes. Grand total: 61.

If `disk_label` returns "" because `util.getFilesystemInfo` isn't in this KOReader version, that's fine — the test just checks `is_string`, and empty string passes. The top bar will skip empty items.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_status.lua penjuru.koplugin/spec/unit/pen_status_spec.lua
git commit -m "feat(status): pen_status reads clock/battery/wifi/light/disk

Each accessor returns the short label string the top bar renders.
Robust to missing subsystems — returns empty string or nil on the
emulator where battery / frontlight may not exist."
```

### Task 1.2: `pen_topbar.lua` — render the status row

**Files:**
- Create: `penjuru.koplugin/pen_topbar.lua` (after stashing the old)
- Modify: nothing else in this task (mounting into the homescreen is Phase 6)

- [ ] **Step 1: Stash the SimpleUI-derived file**

```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
git mv pen_topbar.lua pen_topbar.lua.old_simpleui
```

- [ ] **Step 2: Write the new `pen_topbar.lua`**

```lua
-- penjuru/pen_topbar
-- Persistent status row. 48px tall. Each item is independently placeable
-- left or right via settings; defaults to:
--   left:  clock, wi-fi, light
--   right: disk, battery
-- Each item shown only if pen_status returns non-empty.

local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Status = require("pen_status")

local M = {}

local DEFAULT_LAYOUT = {
    left = { "clock", "wifi", "light" },
    right = { "disk", "battery" },
}

local LABEL_FOR = {
    clock = function() return Status.clock() end,
    wifi = function() return Status.wifi_label() end,
    light = function() return Status.frontlight_label() end,
    disk = function() return Status.disk_label() end,
    battery = function() return Status.battery_label() end,
}

local function user_layout()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    return (s.topbar and s.topbar.layout) or DEFAULT_LAYOUT
end

local function pill(text, with_dot)
    local prefix = with_dot and "· " or ""
    return TextWidget:new{
        text = prefix .. text,
        face = Style.fonts.body(Style.size.top_bar),
        fgcolor = Style.colors.ink_2,
    }
end

local function cluster(items, want_separator)
    local g = HorizontalGroup:new{ align = "baseline" }
    local first = true
    for _, key in ipairs(items) do
        local fn = LABEL_FOR[key]
        local txt = fn and fn()
        if txt and txt ~= "" then
            table.insert(g, pill(txt, want_separator and not first))
            table.insert(g, HorizontalSpan:new{ width = 18 })
            first = false
        end
    end
    return g
end

-- render(content_width) -> widget  -- a 48px-tall horizontal bar
function M.render(content_width)
    local layout = user_layout()
    local left = cluster(layout.left or {}, true)
    local right = cluster(layout.right or {}, true)

    -- spaced_row pushes left to the leading edge and right to the trailing edge.
    local row = HorizontalGroup:new{ align = "baseline" }
    table.insert(row, left)
    local left_w = left:getSize().w
    local right_w = right:getSize().w
    local fill = math.max(0, content_width - left_w - right_w)
    table.insert(row, HorizontalSpan:new{ width = fill })
    table.insert(row, right)

    -- Wrap in a frame with the bottom border (rule major, ink).
    return VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = Style.gap.sm },
        row,
        VerticalSpan:new{ width = Style.gap.sm },
        Widgets.rule(content_width, Style.rules.major, Style.colors.ink),
    }
end

return M
```

- [ ] **Step 3: Confirm specs still pass**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
```

Expected: 61 passes (no new specs in this task — visual verification happens in Phase 6 mounting).

- [ ] **Step 4: Commit**

```bash
git add penjuru.koplugin/pen_topbar.lua penjuru.koplugin/pen_topbar.lua.old_simpleui
git commit -m "feat(chrome): pen_topbar renders clock/wifi/light/disk/battery row

Replaces SimpleUI-derived pen_topbar.lua (stashed at .old_simpleui).
Reads device state via pen_status; layout-driven so user can move items
between left and right clusters via penjuru.topbar.layout setting. Items
that return empty are silently dropped. Mounting into pen_homescreen
deferred to Phase 6."
```

---

## Phase 2 · Tab roster + pagination state

### Task 2.1: `pen_tabs.lua` — tab descriptors, defaults, pagination math

**Files:**
- Create: `penjuru.koplugin/pen_tabs.lua`
- Create: `penjuru.koplugin/spec/unit/pen_tabs_spec.lua`

A "tab" is a descriptor table: `{ id, label, icon, action }`. Pages are arrays of tabs. The default config matches the spec roster.

- [ ] **Step 1: Write the spec**

Create `penjuru.koplugin/spec/unit/pen_tabs_spec.lua`:
```lua
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_tabs", function()
    local Tabs
    setup(function() Tabs = require("pen_tabs") end)

    describe("default_pages", function()
        it("returns 2 pages", function()
            local pages = Tabs.default_pages()
            assert.equals(2, #pages)
        end)

        it("each page has exactly 5 tabs", function()
            local pages = Tabs.default_pages()
            assert.equals(5, #pages[1])
            assert.equals(5, #pages[2])
        end)

        it("page 1 has tabs in the spec'd order", function()
            local p1 = Tabs.default_pages()[1]
            assert.equals("manga", p1[1].id)
            assert.equals("books", p1[2].id)
            assert.equals("home", p1[3].id)
            assert.equals("wifi", p1[4].id)
            assert.equals("games", p1[5].id)
        end)

        it("page 2 has utilities", function()
            local p2 = Tabs.default_pages()[2]
            assert.equals("stats", p2[1].id)
            assert.equals("brightness", p2[2].id)
            assert.equals("power", p2[3].id)
            assert.equals("search", p2[4].id)
            assert.equals("library", p2[5].id)
        end)

        it("every tab has id, label, icon fields", function()
            local pages = Tabs.default_pages()
            for _, page in ipairs(pages) do
                for _, tab in ipairs(page) do
                    assert.is_string(tab.id)
                    assert.is_string(tab.label)
                    assert.is_string(tab.icon)
                end
            end
        end)
    end)

    describe("clamp_page", function()
        it("returns 1 when input is below range", function()
            assert.equals(1, Tabs.clamp_page(0, 2))
            assert.equals(1, Tabs.clamp_page(-5, 2))
        end)
        it("returns n when input is above range", function()
            assert.equals(2, Tabs.clamp_page(99, 2))
        end)
        it("returns input when in range", function()
            assert.equals(1, Tabs.clamp_page(1, 2))
            assert.equals(2, Tabs.clamp_page(2, 2))
        end)
    end)
end)
```

- [ ] **Step 2: Run, confirm fail**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_tabs_spec.lua 2>&1 | tail -8
```

Expected: `module 'pen_tabs' not found`.

- [ ] **Step 3: Implement `pen_tabs.lua`**

```lua
-- penjuru/pen_tabs
-- Tab descriptor catalog, default page layout, pagination helpers.
-- Tab descriptors are pure data:
--   { id, label, icon, action }
-- where action is a string action-id understood by pen_actions, or a
-- table { type, target } for richer actions (e.g. folder shortcut).

local M = {}

-- DEFAULT_TABS is the catalog of tab types penjuru ships with.
local DEFAULT_TABS = {
    home       = { id="home",       label="home",       icon="tab-home",       action="home" },
    library    = { id="library",    label="library",    icon="tab-library",    action="library" },
    wifi       = { id="wifi",       label="wi-fi",      icon="tab-wifi",       action="wifi_toggle" },
    brightness = { id="brightness", label="brightness", icon="tab-brightness", action="brightness" },
    power      = { id="power",      label="power",      icon="tab-power",      action="power_menu" },
    search     = { id="search",     label="search",     icon="tab-search",     action="search" },
    stats      = { id="stats",      label="stats",      icon="tab-stats",      action="stats" },
    -- Folder shortcuts and KUAL: these need user paths; defaults below.
    manga      = { id="manga", label="manga", icon="tab-manga",
                   action = { type="folder", target="/mnt/us/koreader/mangas" } },
    books      = { id="books", label="books", icon="tab-books",
                   action = { type="folder", target="/mnt/us/koreader/books" } },
    games      = { id="games", label="games", icon="tab-games",
                   action = { type="kual" } },
}
M.catalog = DEFAULT_TABS

function M.default_pages()
    return {
        { DEFAULT_TABS.manga, DEFAULT_TABS.books, DEFAULT_TABS.home, DEFAULT_TABS.wifi, DEFAULT_TABS.games },
        { DEFAULT_TABS.stats, DEFAULT_TABS.brightness, DEFAULT_TABS.power, DEFAULT_TABS.search, DEFAULT_TABS.library },
    }
end

-- user_pages() -> array of pages
-- Reads from G_reader_settings.penjuru.bottombar.pages; falls back to defaults.
function M.user_pages()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    local stored = s.bottombar and s.bottombar.pages
    if stored and #stored > 0 then return stored end
    return M.default_pages()
end

function M.clamp_page(n, total)
    if n < 1 then return 1 end
    if n > total then return total end
    return n
end

return M
```

- [ ] **Step 4: Run spec, confirm pass**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_tabs_spec.lua 2>&1 | tail -8
```

Expected: 9 successes. Grand total: 70.

- [ ] **Step 5: Commit**

```bash
git add penjuru.koplugin/pen_tabs.lua penjuru.koplugin/spec/unit/pen_tabs_spec.lua
git commit -m "feat(tabs): pen_tabs — descriptors + default page layout

Catalog of 10 tab types. Default page 1 = manga/books/home/wifi/games,
page 2 = stats/brightness/power/search/library. Page roster reads from
G_reader_settings.penjuru.bottombar.pages with fallback to defaults."
```

---

## Phase 3 · Bottom nav rendering

### Task 3.1: Stash old `pen_bottombar.lua` and write the new one

**Files:**
- Stash: `pen_bottombar.lua` → `pen_bottombar.lua.old_simpleui`
- Create: `pen_bottombar.lua` (new)

- [ ] **Step 1: Stash**

```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
git mv pen_bottombar.lua pen_bottombar.lua.old_simpleui
```

- [ ] **Step 2: Write the new file**

```lua
-- penjuru/pen_bottombar
-- Persistent 7-cell paginated nav bar.
-- Layout: chevron-left · 5 content tabs · chevron-right.
-- Active-tab indicator: 7px top-edge bar via box-shadow-style frame border.
-- Hold any tab: opens tab config screen (placeholder until Plan D).

local FrameContainer = require("ui/widget/container/framecontainer")
local GestureRange = require("ui/gesturerange")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Tabs = require("pen_tabs")
local Icons = require("pen_icons")

local M = {}

-- Pagination state lives on the module table (singleton).
M._current_page = 1
M._active_id = "home"  -- highlighted tab id

-- Width math: chevron flex = 10, content tab flex = 16. Total = 100.
local CHEVRON_FLEX = 10
local CONTENT_FLEX = 16
local TOTAL_FLEX = CHEVRON_FLEX * 2 + CONTENT_FLEX * 5

local NAV_HEIGHT = 170
local ICON_SIZE = 62

-- A clickable cell. content_w is the cell's pixel width.
local function make_cell(cell_w, icon_name, label, is_active, is_disabled, on_tap, on_hold)
    local icon = Icons.widget(icon_name, ICON_SIZE)
    local txt = TextWidget:new{
        text = label,
        face = Style.fonts.body(Style.size.nav_label),
        fgcolor = is_disabled and Style.colors.disabled or Style.colors.ink,
    }
    local inner = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = Style.gap.md },
        icon,
        VerticalSpan:new{ width = Style.gap.sm },
        txt,
        VerticalSpan:new{ width = Style.gap.md },
    }

    -- Active = top border 7px ink; inactive = top border 7px transparent.
    -- We approximate with an outer FrameContainer that has a top border
    -- (KOReader doesn't support per-edge borders directly — use a top
    -- LineWidget above the inner content).
    local top_bar = is_active
        and Widgets.rule(cell_w, Style.rules.active, Style.colors.ink)
        or VerticalSpan:new{ width = Style.rules.active }

    local cell_inner = VerticalGroup:new{
        align = "center",
        top_bar,
        inner,
    }

    -- FrameContainer wraps everything to give a consistent fill / hit area.
    local wrap = FrameContainer:new{
        background = Style.colors.paper,
        bordersize = 0,
        margin = 0,
        padding_left = 0, padding_right = 0,
        padding_top = 0, padding_bottom = 0,
        width = cell_w,
        height = NAV_HEIGHT,
        cell_inner,
    }

    -- Make it tappable via InputContainer.
    if on_tap or on_hold then
        local ic = InputContainer:new{
            dimen = Geom:new{ w = cell_w, h = NAV_HEIGHT },
            wrap,
            key_events = {},
            ges_events = {},
        }
        if on_tap and not is_disabled then
            ic.ges_events.Tap = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x=0, y=0, w=cell_w, h=NAV_HEIGHT },
                },
                handler = on_tap,
            }
        end
        if on_hold and not is_disabled then
            ic.ges_events.Hold = {
                GestureRange:new{
                    ges = "hold",
                    range = Geom:new{ x=0, y=0, w=cell_w, h=NAV_HEIGHT },
                },
                handler = on_hold,
            }
        end
        return ic
    end
    return wrap
end

-- render(content_width, action_dispatch) -> widget
-- action_dispatch is a function(tab_descriptor) called when a content tab
-- is tapped. The bar handles chevron taps internally (pagination).
function M.render(content_width, action_dispatch)
    local pages = Tabs.user_pages()
    local total_pages = #pages
    local cur = Tabs.clamp_page(M._current_page, total_pages)
    local page = pages[cur] or {}

    -- Pagination meta row.
    local meta_left = TextWidget:new{
        text = string.format("navpager · page %d / %d", cur, total_pages),
        face = Style.fonts.body(Style.size.nav_meta),
        fgcolor = Style.colors.ink_dim,
    }
    local meta_right = TextWidget:new{
        text = "hold any tab → settings",
        face = Style.fonts.body(Style.size.nav_meta),
        fgcolor = Style.colors.ink_dim,
    }
    local meta_row = Widgets.spaced_row(content_width, { meta_left, meta_right })
    local meta = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = Style.gap.xs },
        meta_row,
        VerticalSpan:new{ width = Style.gap.xs },
        Widgets.dotted_rule(content_width, Style.rules.minor, Style.colors.rule),
    }

    -- Cell widths
    local cell_w_unit = content_width / TOTAL_FLEX
    local chevron_w = math.floor(cell_w_unit * CHEVRON_FLEX)
    local content_w_cell = math.floor(cell_w_unit * CONTENT_FLEX)

    -- Prev / Next chevrons
    local prev_disabled = (cur == 1)
    local next_disabled = (cur == total_pages)
    local prev_cell = make_cell(
        chevron_w, "chevron-left", "prev",
        false, prev_disabled,
        not prev_disabled and function()
            M._current_page = cur - 1
            -- Caller must re-render; we expose a refresh hook below.
            if M._on_paginate then M._on_paginate() end
        end or nil,
        nil)
    local next_cell = make_cell(
        chevron_w, "chevron-right", "next",
        false, next_disabled,
        not next_disabled and function()
            M._current_page = cur + 1
            if M._on_paginate then M._on_paginate() end
        end or nil,
        nil)

    local row = HorizontalGroup:new{ align = "top" }
    table.insert(row, prev_cell)
    for _, tab in ipairs(page) do
        local on_tap = function()
            if action_dispatch then action_dispatch(tab) end
        end
        local on_hold = function()
            UIManager:show(require("ui/widget/infomessage"):new{
                text = "Tab settings — coming in Plan D",
                timeout = 2,
            })
        end
        local is_active = (tab.id == M._active_id)
        table.insert(row, make_cell(content_w_cell, tab.icon, tab.label,
            is_active, false, on_tap, on_hold))
    end
    table.insert(row, next_cell)

    return VerticalGroup:new{
        align = "left",
        Widgets.rule(content_width, Style.rules.nav_top, Style.colors.ink),
        meta,
        row,
    }
end

-- Setters for pagination + active state.
function M.set_active(tab_id)
    M._active_id = tab_id
end
function M.set_page(n)
    M._current_page = n
end
function M.set_on_paginate(callback)
    M._on_paginate = callback
end

return M
```

- [ ] **Step 3: Confirm specs still pass**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
```

Expected: 70 passes (no new specs in this task).

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_bottombar.lua penjuru.koplugin/pen_bottombar.lua.old_simpleui
git commit -m "feat(chrome): pen_bottombar — 7-cell paginated nav

Replaces SimpleUI-derived pen_bottombar.lua (stashed). Renders
navpager meta row + 7-cell flex grid (chevron · 5 tabs · chevron) with
proportional widths (10 + 16x5 + 10 = 100). Active tab gets a 7px top
edge bar; disabled chevrons dim. Tap on chevron paginates (via
M.set_on_paginate callback), tap on content tab calls the
action_dispatch handed in. Hold on tab shows placeholder InfoMessage
until Plan D wires the settings screen."
```

---

## Phase 4 · Tab action dispatch

### Task 4.1: `pen_actions.lua` — action library + dispatcher

**Files:**
- Create: `penjuru.koplugin/pen_actions.lua`
- Create: `penjuru.koplugin/spec/unit/pen_actions_spec.lua`

Centralizes what each tab does when tapped. Each action is a function that takes no args (or the action `{type, target}` table for parameterized ones like folder).

- [ ] **Step 1: Write the spec**

Create `penjuru.koplugin/spec/unit/pen_actions_spec.lua`:
```lua
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_actions", function()
    local Actions
    setup(function() Actions = require("pen_actions") end)

    it("exposes a dispatch function", function()
        assert.is_function(Actions.dispatch)
    end)

    it("dispatch with unknown action returns false (no crash)", function()
        local ok = Actions.dispatch({ id="totally-fake-tab", action="nonexistent" })
        assert.is_false(ok)
    end)

    it("dispatch with a folder-type action requires target path", function()
        -- No target -> returns false rather than erroring.
        local ok = Actions.dispatch({ id="manga", action={ type="folder" } })
        assert.is_false(ok)
    end)
end)
```

- [ ] **Step 2: Run, confirm fail**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_actions_spec.lua 2>&1 | tail -8
```

Expected: `module 'pen_actions' not found`.

- [ ] **Step 3: Implement `pen_actions.lua`**

```lua
-- penjuru/pen_actions
-- Maps tab actions to KOReader UI calls. Each handler returns true on
-- success, false on no-op or failure. Failures are logged via KOReader's
-- logger; the bottombar caller doesn't act on the return value beyond
-- a possible toast.

local UIManager = require("ui/uimanager")
local logger = require("logger")

local M = {}

-- Built-in handlers keyed by string action id.
local HANDLERS = {}

HANDLERS.home = function()
    local ok, Home = pcall(require, "pen_homescreen")
    if not ok or not Home then return false end
    if Home.refresh then pcall(Home.refresh) end
    if Home.show then pcall(Home.show) end
    return true
end

HANDLERS.library = function()
    -- Tell KOReader to open the file manager root.
    local ok, FM = pcall(require, "apps/filemanager/filemanager")
    if not ok or not FM then return false end
    if FM.instance then
        pcall(FM.instance.setupLayout, FM.instance)
        return true
    end
    return false
end

HANDLERS.wifi_toggle = function()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok or not NetworkMgr then return false end
    if NetworkMgr:isWifiOn() then
        pcall(NetworkMgr.turnOffWifi, NetworkMgr)
    else
        pcall(NetworkMgr.turnOnWifi, NetworkMgr)
    end
    return true
end

HANDLERS.brightness = function()
    local ok, Device = pcall(require, "device")
    if not ok or not Device or not Device:hasFrontlight() then return false end
    local ok2, FL = pcall(require, "ui/widget/frontlightwidget")
    if not ok2 then return false end
    UIManager:show(FL:new{})
    return true
end

HANDLERS.power_menu = function()
    local ok, PowerMenu = pcall(require, "ui/widget/poweroffmenu")
    if not ok then
        -- Fallback: KOReader's standard exit menu.
        local ok2, ConfirmBox = pcall(require, "ui/widget/confirmbox")
        if not ok2 then return false end
        UIManager:show(ConfirmBox:new{
            text = "exit koreader?",
            ok_callback = function() UIManager:quit() end,
        })
        return true
    end
    UIManager:show(PowerMenu:new{})
    return true
end

HANDLERS.search = function()
    local ok, FileSearcher = pcall(require, "apps/filemanager/filemanagerfilesearcher")
    if not ok or not FileSearcher then return false end
    -- FileSearcher needs a host (file manager). Punt for now.
    UIManager:show(require("ui/widget/infomessage"):new{
        text = "search — open library then tap the search icon",
        timeout = 2,
    })
    return true
end

HANDLERS.stats = function()
    -- Open the Statistics plugin's main UI.
    local ok, Stats = pcall(require, "readhistory")
    if not ok then return false end
    UIManager:show(require("ui/widget/infomessage"):new{
        text = "stats — wire to ReadingStatistics in Plan D",
        timeout = 2,
    })
    return true
end

-- Parameterized action: folder shortcut.
local function dispatch_folder(target)
    if not target or target == "" then return false end
    local lfs = require("libs/libkoreader-lfs")
    if not lfs.attributes(target) then
        UIManager:show(require("ui/widget/infomessage"):new{
            text = "folder not found: " .. target,
            timeout = 3,
        })
        return false
    end
    local ok, FM = pcall(require, "apps/filemanager/filemanager")
    if not ok or not FM then return false end
    if FM.instance and FM.instance.file_chooser then
        pcall(FM.instance.file_chooser.changeToPath, FM.instance.file_chooser, target)
        return true
    end
    return false
end

local function dispatch_kual()
    -- KUAL launcher: real Kindle path is /mnt/us/extensions/.
    -- On emulator, we just toast.
    UIManager:show(require("ui/widget/infomessage"):new{
        text = "KUAL launcher — Kindle-only",
        timeout = 2,
    })
    return true
end

-- dispatch(tab) -> bool
function M.dispatch(tab)
    if not tab then return false end
    local action = tab.action
    if type(action) == "string" then
        local h = HANDLERS[action]
        if not h then
            logger.warn("pen_actions: no handler for action", action)
            return false
        end
        local ok, result = pcall(h)
        if not ok then
            logger.warn("pen_actions: handler errored for", action, result)
            return false
        end
        return result and true or false
    end
    if type(action) == "table" then
        if action.type == "folder" then return dispatch_folder(action.target) end
        if action.type == "kual" then return dispatch_kual() end
        if action.type == "plugin" then
            -- Plugin shortcut: action.target = plugin name. Lazy-load + call.
            local ok, plugin = pcall(require, action.target)
            if not ok or not plugin then return false end
            if plugin.show then pcall(plugin.show) end
            return true
        end
    end
    return false
end

return M
```

- [ ] **Step 4: Run spec, confirm pass**

```bash
./scripts/run-specs.sh penjuru.koplugin/spec/unit/pen_actions_spec.lua 2>&1 | tail -8
```

Expected: 3 successes. Grand total: 73.

- [ ] **Step 5: Commit**

```bash
git add penjuru.koplugin/pen_actions.lua penjuru.koplugin/spec/unit/pen_actions_spec.lua
git commit -m "feat(actions): pen_actions — central dispatcher for tab taps

Maps action id (or {type,target} table) to a KOReader UI call. Built-in:
home / library / wifi_toggle / brightness / power_menu / search / stats.
Parameterized: folder (changeToPath in FM), kual (Kindle-only), plugin
(lazy require + show). All handlers wrapped in pcall — failures log a
warning and return false so the bar can show a toast."
```

---

## Phase 5 · Home module tap routing (Plan B carry-over)

### Task 5.1: Wrap highlight blocks in InputContainer with tap → open book

**Files:**
- Modify: `penjuru.koplugin/home_modules/module_highlights.lua`

KOReader can open a book and seek to a page via `ReaderUI:showReader(path, page)`. We wrap each highlight block in an InputContainer that calls this on tap.

- [ ] **Step 1: Read the current module to understand the existing structure**

```bash
grep -n 'highlight_block\|InputContainer' ~/Developer/koreader-custom-ui/penjuru.koplugin/home_modules/module_highlights.lua
```

The `highlight_block` function currently returns a VerticalGroup. We need to wrap that in an InputContainer with a Tap gesture range.

- [ ] **Step 2: Edit the file**

Replace the existing `highlight_block` function in `~/Developer/koreader-custom-ui/penjuru.koplugin/home_modules/module_highlights.lua` with:
```lua
local function highlight_block(w, h)
    local quote = TextBoxWidget:new{
        text = '"' .. string.lower(h.text) .. '"',
        face = Style.fonts.headline(Style.size.highlight_q),
        fgcolor = Style.colors.ink,
        width = w,
    }
    local parts = { "— " }
    if h.book_author ~= "" then table.insert(parts, string.lower(h.book_author) .. ", ") end
    table.insert(parts, string.lower(h.book_title))
    table.insert(parts, " · p. " .. h.page)
    if h.datetime ~= "" then
        table.insert(parts, " · " .. h.datetime:sub(1, 10))
    end
    local src = TextWidget:new{
        text = table.concat(parts),
        face = Style.fonts.italic(Style.size.highlight_src),
        fgcolor = Style.colors.ink_dim,
    }
    local content = VerticalGroup:new{
        align = "left",
        quote,
        VerticalSpan:new{ width = 6 },
        src,
        VerticalSpan:new{ width = 10 },
        Widgets.dotted_rule(w, Style.rules.minor, Style.colors.rule_soft),
        VerticalSpan:new{ width = 10 },
    }

    local content_h = content:getSize().h
    local InputContainer = require("ui/widget/container/inputcontainer")
    local GestureRange = require("ui/gesturerange")
    local Geom = require("ui/geometry")
    return InputContainer:new{
        dimen = Geom:new{ w = w, h = content_h },
        content,
        ges_events = {
            Tap = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x=0, y=0, w=w, h=content_h },
                },
                handler = function()
                    if not h.book_file then return end
                    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
                    if not ok or not ReaderUI then return end
                    pcall(ReaderUI.showReader, ReaderUI, h.book_file)
                    -- Note: jumping to specific page requires opening the
                    -- reader first then issuing a goto; we open to the
                    -- book and let the user navigate. Page-jump is a Plan
                    -- D enhancement.
                end,
            },
        },
    }
end
```

- [ ] **Step 3: Confirm specs pass and smoke-test in emulator**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# 73 expected

export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader
LOG=$(mktemp /tmp/penjuru-hltap-log.XXXX)
bash ./kodev run > "$LOG" 2>&1 &
KODEV_PID=$!
sleep 12
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
sleep 2
grep -iE 'error|cannot|nil value|attempt to' "$LOG" | grep -iE 'module_highlights|pen_home' | head -10
```

Expected: no errors.

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/home_modules/module_highlights.lua
git commit -m "feat(home): tap a highlight opens the book in ReaderUI

Wraps each highlight block in InputContainer with a Tap handler that
invokes ReaderUI:showReader(book_file). Page-jump to the highlighted
location deferred to Plan D (requires post-open goto)."
```

### Task 5.2: Wrap catalogue rows in InputContainer with tap → open book

**Files:**
- Modify: `penjuru.koplugin/home_modules/module_catalogued.lua`

Same pattern as Task 5.1.

- [ ] **Step 1: Edit the file**

Replace the existing `book_row` function in `~/Developer/koreader-custom-ui/penjuru.koplugin/home_modules/module_catalogued.lua` with:
```lua
local function book_row(w, book)
    local title_text = string.lower(book.title)
    if #title_text > 36 then title_text = title_text:sub(1, 35) .. "…" end
    local title = TextWidget:new{
        text = title_text,
        face = Style.fonts.headline(Style.size.cat_title),
        fgcolor = Style.colors.ink,
    }
    local age = TextWidget:new{
        text = pretty_age(book.age_days) .. " →",
        face = Style.fonts.numerals(Style.size.cat_age),
        fgcolor = Style.colors.ink_soft,
    }
    local content = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = 12 },
        Widgets.spaced_row(w, { title, age }),
        VerticalSpan:new{ width = 12 },
        Widgets.dotted_rule(w, Style.rules.minor, Style.colors.rule_soft),
    }

    local content_h = content:getSize().h
    local InputContainer = require("ui/widget/container/inputcontainer")
    local GestureRange = require("ui/gesturerange")
    local Geom = require("ui/geometry")
    return InputContainer:new{
        dimen = Geom:new{ w = w, h = content_h },
        content,
        ges_events = {
            Tap = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x=0, y=0, w=w, h=content_h },
                },
                handler = function()
                    if not book.file then return end
                    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
                    if not ok or not ReaderUI then return end
                    pcall(ReaderUI.showReader, ReaderUI, book.file)
                end,
            },
        },
    }
end
```

- [ ] **Step 2: Smoke + commit**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# 73 expected
git add penjuru.koplugin/home_modules/module_catalogued.lua
git commit -m "feat(home): tap a newly-catalogued row opens the book"
```

---

## Phase 6 · Mount bars on the home screen

### Task 6.1: Wire `pen_topbar` and `pen_bottombar` into `pen_homescreen.lua`

**Files:**
- Modify: `penjuru.koplugin/pen_homescreen.lua`

End state: home screen renders top bar → masthead → dateline → body modules → bottom nav, all in one VerticalGroup.

- [ ] **Step 1: Read the current pen_homescreen.lua to find where the outer VerticalGroup is built**

```bash
grep -n 'VerticalGroup\|return frame\|UIManager:show' ~/Developer/koreader-custom-ui/penjuru.koplugin/pen_homescreen.lua | head -20
```

The implementer for Plan A/B has a specific structure. The outer composition likely returns a FrameContainer wrapping a VerticalGroup. Insert the top bar at the start of that VerticalGroup and the bottom bar at the end.

- [ ] **Step 2: Add the requires at the top of pen_homescreen.lua**

If not already imported:
```lua
local TopBar = require("pen_topbar")
local BottomBar = require("pen_bottombar")
local Actions = require("pen_actions")
```

- [ ] **Step 3: Build the bars in show() and insert into the outer stack**

In the body of show() (or wherever the outer widget is constructed), insert near where you build the `body` VerticalGroup:
```lua
-- Top bar: full screen width, sits above masthead.
local top_bar = TopBar.render(screen_w)

-- Bottom bar: full screen width, sits below body.
BottomBar.set_active("home")
BottomBar.set_page(1)
BottomBar.set_on_paginate(function()
    -- Re-render the home so the bar picks up the new page.
    if Homescreen and Homescreen.refresh then Homescreen.refresh() end
end)
local bottom_bar = BottomBar.render(screen_w, function(tab)
    Actions.dispatch(tab)
end)
```

Then change the outer VerticalGroup composition so it's:
```lua
local outer = VerticalGroup:new{
    align = "left",
    top_bar,
    -- existing masthead + dateline + body content, indented under the padding
    -- (the existing inner padding stays as-is for the body content)
    inner_body_with_padding,
    bottom_bar,
}
```

The `screen_w` should already be available in the show() function. The body content keeps its existing 36px horizontal padding; the top and bottom bars span the full screen width.

- [ ] **Step 4: Smoke-test in emulator**

```bash
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader
LOG=$(mktemp /tmp/penjuru-chrome-log.XXXX)
bash ./kodev run > "$LOG" 2>&1 &
KODEV_PID=$!
sleep 15
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
sleep 2
echo "--- plugin-related errors ---"
grep -iE 'error|cannot|nil value|attempt to' "$LOG" | grep -iE 'pen_|home_modules' | head -20
echo "--- log: $LOG ---"
```

Expected: no errors. The user can visually verify by tapping the Home tab in the emulator — the home now has a top status bar at the top, masthead/dateline/modules in the middle, and the 7-cell paginated bottom bar at the bottom.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_homescreen.lua
git commit -m "feat(home): mount pen_topbar + pen_bottombar around the body

Home screen now renders the full chrome: persistent status row at top,
masthead/dateline/modules in the middle (existing), 7-cell paginated
nav at bottom. Home is the active tab; paginating the bar re-renders
the home via Homescreen.refresh."
```

---

## Phase 7 · Wrap-up

### Task 7.1: Plan C DONE.md + push

**Files:**
- Create: `docs/superpowers/plans/2026-MM-DD-plan-C-DONE.md`

- [ ] **Step 1: Write DONE.md**

```bash
cd ~/Developer/koreader-custom-ui
DATE=$(date '+%Y-%m-%d')
cat > docs/superpowers/plans/${DATE}-plan-C-DONE.md <<EOF
# Plan C · DONE — $(date '+%Y-%m-%d')

## What's working

- 12 SVG icons (1.6px stroke, 24×24) bundled at icons/penjuru/
- pen_icons.lua loads icons by short name into IconWidget
- pen_status.lua reads clock/wifi/light/disk/battery from KOReader's device singletons
- pen_topbar.lua renders the status row (left and right clusters; per-item layout via settings)
- pen_tabs.lua catalog + default 2-page roster (manga/books/home/wifi/games | stats/brightness/power/search/library)
- pen_bottombar.lua renders the 7-cell paginated nav with active-tab indicator, tap + hold gestures
- pen_actions.lua dispatches taps to KOReader UI (built-ins + folder/kual/plugin shortcuts)
- Tap on a highlight or newly-catalogued row opens that book in ReaderUI
- Home screen mounts both bars around the existing body
- $(./scripts/run-specs.sh 2>&1 | grep -oE '[0-9]+ tests' | head -1) specs pass

## Carry-overs to Plan D

- Hold-on-tab opens a placeholder InfoMessage — Plan D wires the real tab config screen
- Stats / search built-in actions are stubbed with toasts — Plan D wires the real KOReader plugins
- Cover %-overlay polish (Plan B noted it)
- Page-jump on highlight tap (currently opens the book without seeking)

## What's deferred to Plan D

- Settings menu (Menu → Tools → penjuru sub-tree)
- Top-bar layout config (move items between left/right)
- Bottom-nav tab roster config (change which tabs are on which page)
- Reading goal / location / newly-threshold / catalogue-dirs config
- Bars on file-browser and reader screens (currently home-only)
- On-Kindle install (build script, INSTALL.md for users)
- Visible Acknowledgments to Doctor Hetfield in README
EOF
git add docs/superpowers/plans/${DATE}-plan-C-DONE.md
git commit -m "docs: Plan C complete — persistent chrome on the home screen"
git push origin main
```

- [ ] **Step 2: Hand off**

Tell the controller: "Plan C complete. Home now has persistent top status bar + 7-cell paginated bottom nav with the spec'd roster, plus tap routing on highlights and catalogue rows. Ready for Plan D (settings UI + on-Kindle install)."
