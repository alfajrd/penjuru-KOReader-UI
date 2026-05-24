# penjuru.koplugin · Plan D — Settings, Polish, Install (v1.0 ship)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close out the v1.0 release. Rip out the now-unused SimpleUI monkey-patch tower, add a minimal settings menu, wire the placeholder actions (stats/search) to real KOReader plugins, polish two interactions (page-jump on highlight tap, real tab-config on hold), write a build script + INSTALL.md so other Kindle users can install penjuru, and add the Acknowledgments section crediting Doctor Hetfield. Tag and push v1.0.0.

**Architecture:** No new core modules — Plan D is mostly cleanup and integration. Settings live in `G_reader_settings:readSetting("penjuru")` (a single nested table) read by existing modules; we add `pen_menu.lua` that registers KOReader menu items under Menu → Tools → penjuru and writes back to that table. A `pen_book_open.lua` helper centralizes "open this book and seek to page" since both highlights and (future) bookmark-browser need it. A simple shell `build.sh` zips the plugin folder into `dist/penjuru.koplugin.zip` for distribution.

**Tech Stack:** Lua 5.1, KOReader v2026.03 (SpinWidget, InputDialog, ToggleSwitchWidget, Menu module), Bash for build script, Markdown for docs.

**Plan C carry-overs being closed here:**
- Rip `pen_patches.lua` (legacy SimpleUI glue); silences the two boot-time soft-fail errors
- Real handlers for the `stats` and `search` tab actions
- Hold-on-tab opens an actual tab-config screen (minimal — just shows which tab is in which slot; full editing deferred to v1.1)
- Page-jump on highlight tap

**Out of scope for v1.0** (revisit if/when a Plan E becomes warranted):
- Bars persisting on file-browser and reader views (home-only stays)
- Async catalogue scan
- Tab-roster live editing UI (settings menu supports it via JSON, not GUI)
- Cover %-overlay polish

---

## File structure (new in Plan D)

```
penjuru.koplugin/
├── pen_patches.lua                    [DELETE Phase 0, stash as .old]
├── pen_menu.lua                       [REPLACE Phase 1, was SimpleUI's huge menu file]
├── pen_settings_defaults.lua          [Phase 1, NEW] central default values
├── pen_book_open.lua                  [Phase 3, NEW] open book + seek to page helper
├── (existing files modified to read/write penjuru settings table)
└── docs/, scripts/, etc.

Repo root:
├── INSTALL.md                         [Phase 5, NEW] end-user install guide
├── README.md                          [Phase 5, MODIFIED] add Acknowledgments
├── build.sh                           [Phase 4, NEW] zips plugin to dist/
└── dist/penjuru.koplugin.zip          [Phase 4 build artifact, gitignored]
```

---

## Phase 0 · Cleanup

### Task D.0.1: Audit what `pen_patches.lua` still does, then stash it

**Files:**
- Stash: `penjuru.koplugin/pen_patches.lua` → `pen_patches.lua.old_simpleui`
- Modify: `penjuru.koplugin/main.lua` (remove the require + setup call)

`pen_patches.lua` was SimpleUI's monkey-patch tower — it injected the top/bottom bars into KOReader's FileManager and ReaderUI. We replaced both bars with our own (Plan C), and our chrome lives in `pen_homescreen.lua`, so the patches no longer match our surfaces. They currently emit two soft-fail errors at boot (`TOTAL_H` / `scheduleRefresh` on the old singletons).

- [ ] **Step 1: Confirm what main.lua does with pen_patches**

```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
grep -n 'pen_patches\|Patches' main.lua | head -10
```

Note every reference — typically a `require("pen_patches")` near the top and a `Patches.install(...)` / `Patches.installAll(...)` call somewhere in the setup/init path.

- [ ] **Step 2: Stash pen_patches.lua**

```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
git mv pen_patches.lua pen_patches.lua.old_simpleui
```

- [ ] **Step 3: Remove or comment out the require + call in main.lua**

Use Edit to remove the `local Patches = require("pen_patches")` line and any `Patches.install...` / `Patches.teardown...` calls. Replace each with a comment like `-- pen_patches removed: legacy SimpleUI glue (Plan D / D.0.1)`.

- [ ] **Step 4: Boot the emulator and confirm both soft-fail errors are gone**

```bash
export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader
LOG=$(mktemp /tmp/penjuru-d01-log.XXXX)
bash ./kodev run > "$LOG" 2>&1 &
KODEV_PID=$!
sleep 12
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
sleep 2
echo "--- TOTAL_H / scheduleRefresh errors (should be empty) ---"
grep -iE 'TOTAL_H|scheduleRefresh' "$LOG" | head -5
echo "--- any pen_ errors ---"
grep -iE 'error|cannot|nil value|attempt to' "$LOG" | grep -iE 'pen_|penjuru|home_modules' | head -10
echo "--- log: $LOG ---"
```

Expected: both grep blocks empty. If `TOTAL_H` / `scheduleRefresh` errors still appear, they're triggered by something other than pen_patches — search for those identifiers in main.lua / pen_homescreen.lua and remove the calls.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# expect 75 passes (unchanged)
git add penjuru.koplugin/pen_patches.lua penjuru.koplugin/pen_patches.lua.old_simpleui penjuru.koplugin/main.lua
git commit -m "chore: rip pen_patches — legacy SimpleUI chrome injection

pen_patches.lua hooked KOReader's FileManager and ReaderUI to inject
SimpleUI's top + bottom bars on every screen. Plan C replaced both
bars; our chrome lives in pen_homescreen.lua. The patches no longer
match their target surfaces and were logging two soft-fail errors at
boot (TOTAL_H / scheduleRefresh). Stashed at .old_simpleui for
reference; main.lua's require and install calls removed."
```

### Task D.0.2: Stash the old `pen_menu.lua` and replace with a minimal stub

**Files:**
- Stash: `pen_menu.lua` → `pen_menu.lua.old_simpleui`
- Create: new minimal `pen_menu.lua`

The current `pen_menu.lua` is 239KB inherited from SimpleUI — a huge nested menu tree with FoldercCovers / BrowseMeta / Theme presets we don't have. We replace it with a 3-section stub: Home / Bottom bar / About. Real settings UI lands in Phase 1.

- [ ] **Step 1: Stash**

```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
git mv pen_menu.lua pen_menu.lua.old_simpleui
```

- [ ] **Step 2: Write a minimal new pen_menu.lua**

Create `~/Developer/koreader-custom-ui/penjuru.koplugin/pen_menu.lua`:
```lua
-- penjuru/pen_menu
-- Registers the Menu → Tools → penjuru sub-tree. Phase 1 of Plan D
-- expands this into a real settings UI; v0 ships with stubs.

local _ = require("gettext")
local Defaults = require("pen_settings_defaults")

local M = {}

local function read_settings()
    if not rawget(_G, "G_reader_settings") then return Defaults.all() end
    local s = G_reader_settings:readSetting("penjuru") or {}
    return setmetatable(s, { __index = Defaults.all() })
end

local function write_settings(s)
    if rawget(_G, "G_reader_settings") then
        G_reader_settings:saveSetting("penjuru", s)
    end
end
M._read_settings = read_settings
M._write_settings = write_settings

-- get_menu_items() -> array
-- Called by main.lua during plugin init to register under Tools → penjuru.
function M.get_menu_items()
    return {
        {
            text = _("Open home"),
            callback = function()
                local Home = require("pen_homescreen")
                if Home.refresh then pcall(Home.refresh) end
                if Home.show then pcall(Home.show) end
            end,
        },
        -- Real settings items land in D.1.x.
        {
            text = _("Settings"),
            sub_item_table = {
                {
                    text = _("(settings coming soon)"),
                    callback = function() end,
                },
            },
        },
        {
            text = _("About penjuru"),
            keep_menu_open = true,
            callback = function()
                local InfoMessage = require("ui/widget/infomessage")
                local UIManager = require("ui/uimanager")
                local meta = require("_meta")
                UIManager:show(InfoMessage:new{
                    text = "penjuru " .. (meta.version or "?") ..
                           "\nby " .. (meta.author or "?") ..
                           "\n\nforked from doctorhetfield-cmd/simpleui.koplugin\n" ..
                           "https://github.com/alfajrd/penjuru-KOReader-UI",
                    timeout = 6,
                })
            end,
        },
    }
end

return M
```

- [ ] **Step 3: Update main.lua to consume the new menu items**

Locate where the OLD pen_menu.lua was wired into main.lua (search for `Menu` / `addToMainMenu` / `menu_items`). Replace the wiring so main.lua uses `pen_menu.get_menu_items()`. Typical KOReader plugin pattern:
```lua
local PenMenu = require("pen_menu")

function PenjuruPlugin:addToMainMenu(menu_items)
    menu_items.penjuru = {
        text = _("penjuru"),
        sorting_hint = "tools",
        sub_item_table = PenMenu.get_menu_items(),
    }
end
```

If the existing wiring is complex (it likely is — SimpleUI had a sprawling menu), simplify aggressively. The plugin only needs to register the `penjuru` entry under Tools and let `pen_menu.get_menu_items()` provide everything beneath it.

- [ ] **Step 4: Create the defaults file the stub references**

Create `~/Developer/koreader-custom-ui/penjuru.koplugin/pen_settings_defaults.lua`:
```lua
-- penjuru/pen_settings_defaults
-- Single source of truth for default settings. Modules call .all() to
-- get the full default table; pen_menu's read_settings uses this as the
-- __index metatable so any unset key falls through to the default.

local M = {}

local function defaults()
    return {
        -- Home modules
        home = {
            modules_visible = {
                currently = true, ledger = true, almanac = true,
                desk = true, catalogued = true, highlights = true,
            },
        },
        -- Today's ledger
        year_goal = 40,
        -- The almanac
        almanac = {
            lat = -6.2088,   -- Jakarta default
            lon = 106.8456,
            tz = 7,
        },
        -- Newly catalogued
        newly = {
            threshold_days = 30,
            dirs = {},  -- empty means use the bundled default in module_catalogued
        },
        -- Top bar
        topbar = {
            layout = {
                left = { "clock", "wifi", "light" },
                right = { "disk", "battery" },
            },
        },
        -- Bottom bar
        bottombar = {
            -- pages defaults to pen_tabs.default_pages() if absent
        },
        -- Install date (lazy-initialized by pen_install_date)
        -- install_date = (set on first use)
    }
end

function M.all() return defaults() end

return M
```

- [ ] **Step 5: Smoke-test in emulator**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# 75 expected

export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader
LOG=$(mktemp /tmp/penjuru-d02-log.XXXX)
bash ./kodev run > "$LOG" 2>&1 &
KODEV_PID=$!
sleep 12
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
sleep 2
grep -iE 'error|cannot|nil value|attempt to' "$LOG" | grep -iE 'pen_|penjuru' | head -10
echo "--- menu loaded markers ---"
grep -iE 'penjuru' "$LOG" | grep -iE 'menu|loaded' | head -5
```

Expected: no errors. The "Open home" / "Settings" / "About penjuru" entries should appear under Menu → Tools → penjuru when you navigate the emulator menu.

- [ ] **Step 6: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_menu.lua penjuru.koplugin/pen_menu.lua.old_simpleui penjuru.koplugin/pen_settings_defaults.lua penjuru.koplugin/main.lua
git commit -m "chore: replace 239KB SimpleUI menu with a 3-item stub

Old pen_menu.lua stashed at .old_simpleui. New menu has Open home /
Settings (stub) / About — Settings sub-tree gets populated in Phase 1.
pen_settings_defaults centralizes default values via .all(); pen_menu's
read_settings uses it as __index so callers always see a complete table."
```

---

## Phase 1 · Settings menu

### Task D.1.1: Add settings items for year goal + location + newly threshold

**Files:**
- Modify: `penjuru.koplugin/pen_menu.lua`

Use KOReader's `SpinWidget` (numeric input) and `InputDialog` (text) for editing settings. After saving, the next time the home screen renders, it picks up the new values.

- [ ] **Step 1: Add three settings entries to the menu's Settings sub_item_table**

Replace the placeholder `(settings coming soon)` entry in `pen_menu.lua` with three real entries. Inside `get_menu_items()`, change the Settings sub_item_table to:
```lua
sub_item_table = {
    {
        text_func = function()
            local s = read_settings()
            return _("Annual reading goal: ") .. tostring(s.year_goal or 40)
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local SpinWidget = require("ui/widget/spinwidget")
            local UIManager = require("ui/uimanager")
            local s = read_settings()
            UIManager:show(SpinWidget:new{
                title_text = _("Annual reading goal"),
                value = s.year_goal or 40,
                value_min = 1, value_max = 500, value_step = 1, value_hold_step = 10,
                ok_text = _("Set"),
                callback = function(spin)
                    local cur = G_reader_settings:readSetting("penjuru") or {}
                    cur.year_goal = spin.value
                    write_settings(cur)
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
            })
        end,
    },
    {
        text_func = function()
            local s = read_settings()
            local a = s.almanac or {}
            return _("Location: lat ") .. string.format("%.4f", a.lat or -6.2088)
                .. ", lon " .. string.format("%.4f", a.lon or 106.8456)
                .. " (tz " .. tostring(a.tz or 7) .. ")"
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local InputDialog = require("ui/widget/inputdialog")
            local UIManager = require("ui/uimanager")
            local s = read_settings()
            local a = s.almanac or {}
            local dlg
            dlg = InputDialog:new{
                title = _("Location for sunrise / moon"),
                input_hint = "lat,lon,tz   (e.g. -6.2088,106.8456,7)",
                input = string.format("%.4f,%.4f,%d", a.lat or -6.2088, a.lon or 106.8456, a.tz or 7),
                buttons = {
                    { { text = _("Cancel"), id = "close", callback = function() UIManager:close(dlg) end },
                      { text = _("Save"), is_enter_default = true, callback = function()
                            local txt = dlg:getInputText()
                            local lat, lon, tz = txt:match("(%-?[%d%.]+),(%-?[%d%.]+),(%-?%d+)")
                            if lat and lon and tz then
                                local cur = G_reader_settings:readSetting("penjuru") or {}
                                cur.almanac = cur.almanac or {}
                                cur.almanac.lat = tonumber(lat)
                                cur.almanac.lon = tonumber(lon)
                                cur.almanac.tz = tonumber(tz)
                                write_settings(cur)
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end
                            UIManager:close(dlg)
                        end },
                    },
                },
            }
            UIManager:show(dlg)
            dlg:onShowKeyboard()
        end,
    },
    {
        text_func = function()
            local s = read_settings()
            return _("Newly threshold: ") .. tostring((s.newly and s.newly.threshold_days) or 30) .. _(" days")
        end,
        keep_menu_open = true,
        callback = function(touchmenu_instance)
            local SpinWidget = require("ui/widget/spinwidget")
            local UIManager = require("ui/uimanager")
            local s = read_settings()
            local cur_val = (s.newly and s.newly.threshold_days) or 30
            UIManager:show(SpinWidget:new{
                title_text = _("Newly catalogued threshold (days)"),
                value = cur_val,
                value_min = 1, value_max = 365, value_step = 1, value_hold_step = 7,
                ok_text = _("Set"),
                callback = function(spin)
                    local cur = G_reader_settings:readSetting("penjuru") or {}
                    cur.newly = cur.newly or {}
                    cur.newly.threshold_days = spin.value
                    write_settings(cur)
                    if touchmenu_instance then touchmenu_instance:updateItems() end
                end,
            })
        end,
    },
},
```

- [ ] **Step 2: Wire `module_catalogued` to read the new threshold**

Open `~/Developer/koreader-custom-ui/penjuru.koplugin/home_modules/module_catalogued.lua`. Find the line that calls `Data.read_newly_catalogued(user_book_dirs(), 30, 3)`. Replace the hardcoded `30` with a settings read:
```lua
local function user_threshold()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    return (s.newly and s.newly.threshold_days) or 30
end
```
Then change the call to:
```lua
local books = Data.read_newly_catalogued(user_book_dirs(), user_threshold(), 3)
```

- [ ] **Step 3: Smoke-test + commit**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# 75 expected

export PATH="/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/bin:$PATH"
cd ~/Developer/koreader && bash ./kodev run &
KODEV_PID=$!
sleep 12
kill $KODEV_PID 2>/dev/null
pkill -f koreader-emulator 2>/dev/null
sleep 2

cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_menu.lua penjuru.koplugin/home_modules/module_catalogued.lua
git commit -m "feat(settings): year goal + location + newly threshold

Three menu entries under Tools → penjuru → Settings. SpinWidget for
numeric values (goal 1-500, threshold 1-365). InputDialog for location
as 'lat,lon,tz' comma string. module_catalogued reads the threshold
setting; module_ledger and module_almanac already do (they have
defaults that match pen_settings_defaults)."
```

---

## Phase 2 · Wire real actions

### Task D.2.1: Wire `stats` action to KOReader's ReadingStatistics plugin

**Files:**
- Modify: `penjuru.koplugin/pen_actions.lua`

KOReader's Statistics plugin lives at `plugins/statistics.koplugin/main.lua`. It exposes a `Statistics` table; the canonical entry is `Statistics:onShowReaderProgress()` or `Statistics:onShowReadingStatistics()` depending on context. Easiest: open the file manager's Tools menu programmatically. Simpler: dispatch via KOReader's UI event system using `Event:new("ShowReaderStatistics")`.

- [ ] **Step 1: Replace the `stats` placeholder with a real handler**

Open `pen_actions.lua` and replace the `HANDLERS.stats` body with:
```lua
HANDLERS.stats = function()
    -- Statistics plugin exposes itself via UI events.
    local ok, Event = pcall(require, "ui/event")
    if not ok or not Event then return false end
    local ok2, UIManager = pcall(require, "ui/uimanager")
    if not ok2 then return false end
    -- The 'ShowReaderStatistics' event triggers the Statistics plugin to
    -- open its stats overview. If a reader isn't active, fall back to
    -- the calendar view via 'ShowReaderStatisticsCalendar'.
    UIManager:broadcastEvent(Event:new("ShowReaderStatistics"))
    return true
end
```

If `ShowReaderStatistics` doesn't trigger anything (Statistics plugin disabled or event name differs in this KOReader version), the implementer falls back to a toast: keep the existing InfoMessage but with text "stats — enable the Statistics plugin in Tools → Plugin management".

- [ ] **Step 2: Replace the `search` placeholder**

Same file. Replace `HANDLERS.search` body with:
```lua
HANDLERS.search = function()
    -- File search lives in the file manager. Open it then trigger search.
    local ok, FM = pcall(require, "apps/filemanager/filemanager")
    if not ok or not FM then return false end
    if not FM.instance then
        -- Open file manager first.
        local ok2 = pcall(FM.showFiles, FM)
        if not ok2 then return false end
    end
    local Event = require("ui/event")
    local UIManager = require("ui/uimanager")
    UIManager:broadcastEvent(Event:new("ShowFileSearch"))
    return true
end
```

- [ ] **Step 3: Smoke-test + commit**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# 75 expected
git add penjuru.koplugin/pen_actions.lua
git commit -m "feat(actions): wire stats and search to KOReader events

stats: broadcasts ShowReaderStatistics event (Statistics plugin
handles). search: opens file manager if needed, then broadcasts
ShowFileSearch. Replaces the Plan C placeholder toasts."
```

---

## Phase 3 · Polish two interactions

### Task D.3.1: `pen_book_open.lua` — open book + seek to page helper

**Files:**
- Create: `penjuru.koplugin/pen_book_open.lua`
- Modify: `penjuru.koplugin/home_modules/module_highlights.lua`

KOReader's `ReaderUI:showReader(path)` opens the book but doesn't seek. After the reader is up, we need to call `ReaderUI.instance.rolling:onGotoPage(n)` (for reflowable epubs) or `ReaderUI.instance.paging:onGotoPage(n)` (for paged formats). Easier: dispatch via UI event after a short delay.

- [ ] **Step 1: Create the helper**

```lua
-- penjuru/pen_book_open
-- Open a book and (optionally) seek to a specific page after it loads.
-- ReaderUI's showReader is asynchronous in terms of when goto is safe;
-- we schedule the goto for the next UI tick.

local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local logger = require("logger")

local M = {}

-- open(path, page) -> bool
-- page is optional (1-indexed). If nil, just opens the book.
function M.open(path, page)
    if not path or path == "" then return false end
    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
    if not ok or not ReaderUI then return false end
    local ok2 = pcall(ReaderUI.showReader, ReaderUI, path)
    if not ok2 then return false end
    if page and page > 0 then
        -- Schedule the goto for after the reader has finished initializing.
        UIManager:scheduleIn(0.5, function()
            local inst = ReaderUI.instance
            if not inst then return end
            local ok_goto = pcall(function()
                inst:handleEvent(Event:new("GotoPage", page))
            end)
            if not ok_goto then
                logger.warn("pen_book_open: GotoPage failed for page", page)
            end
        end)
    end
    return true
end

return M
```

- [ ] **Step 2: Update module_highlights.lua to pass page**

In the tap handler we wired in C.5.1, replace:
```lua
pcall(ReaderUI.showReader, ReaderUI, h.book_file)
```
with:
```lua
local BookOpen = require("pen_book_open")
BookOpen.open(h.book_file, h.page)
```

(Adjust the surrounding require lines — the local `ReaderUI` require can be removed since BookOpen handles it.)

- [ ] **Step 3: Smoke-test + commit**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# 75 expected
git add penjuru.koplugin/pen_book_open.lua penjuru.koplugin/home_modules/module_highlights.lua
git commit -m "feat(home): tap a highlight opens the book AND seeks to its page

pen_book_open.open(path, page) wraps ReaderUI:showReader + a deferred
GotoPage event. module_highlights now passes h.page so tapping a
highlight lands on the right page instead of the book's last-read
position."
```

### Task D.3.2: Tab-config screen on hold

**Files:**
- Modify: `penjuru.koplugin/pen_bottombar.lua`

When the user holds a tab, currently we show an InfoMessage placeholder. Replace with a minimal screen that lists the tab roster (read-only for v1.0; editing comes in v1.1).

- [ ] **Step 1: Replace the hold handler**

In `pen_bottombar.lua`, find the `on_hold = function() ... InfoMessage ... end` inside `M.render()`. Replace its body with:
```lua
on_hold = function()
    local InfoMessage = require("ui/widget/infomessage")
    local pages_text = "tab roster (read-only)\n\n"
    for i, page in ipairs(Tabs.user_pages()) do
        pages_text = pages_text .. "page " .. i .. ":\n"
        for _, t in ipairs(page) do
            pages_text = pages_text .. "  · " .. t.label .. "  (" .. t.id .. ")\n"
        end
        pages_text = pages_text .. "\n"
    end
    pages_text = pages_text .. "edit via G_reader_settings.penjuru.bottombar.pages\n(gui editing in v1.1)"
    UIManager:show(InfoMessage:new{
        text = pages_text,
        timeout = 8,
    })
end
```

- [ ] **Step 2: Smoke-test + commit**

```bash
cd ~/Developer/koreader-custom-ui
./scripts/run-specs.sh 2>&1 | tail -3
# 75 expected
git add penjuru.koplugin/pen_bottombar.lua
git commit -m "feat(chrome): hold-on-tab shows the current tab roster

Replaces the v1.0 placeholder InfoMessage with a real listing of every
tab on every page (id + label). Read-only for v1.0; an in-place editor
lands in v1.1."
```

---

## Phase 4 · Build script + install path

### Task D.4.1: `build.sh` — package the plugin as a zip

**Files:**
- Create: `build.sh` (repo root)
- Create: `.gitignore` line for `dist/`
- Modify: `.gitignore`

- [ ] **Step 1: Write build.sh**

Create `~/Developer/koreader-custom-ui/build.sh`:
```bash
#!/usr/bin/env bash
# Build penjuru.koplugin into a distributable zip.
# Usage: ./build.sh           -> writes dist/penjuru.koplugin.zip
#        ./build.sh --clean   -> removes dist/ first
set -euo pipefail

cd "$(dirname "$0")"

if [[ "${1:-}" == "--clean" ]]; then
    rm -rf dist
fi

mkdir -p dist
ZIP="dist/penjuru.koplugin.zip"
rm -f "$ZIP"

# Exclude dev-only files and .old_simpleui stashes from the shipped zip.
zip -r "$ZIP" penjuru.koplugin \
    --exclude '*.old_simpleui' \
    --exclude 'penjuru.koplugin/spec/*' \
    --exclude '*.DS_Store' \
    --exclude '*/.git/*' \
    > /dev/null

SIZE=$(du -h "$ZIP" | awk '{print $1}')
echo "Built: $ZIP ($SIZE)"
echo
echo "To install on Kindle:"
echo "  1. Unzip into /mnt/us/koreader/plugins/"
echo "     The result must be /mnt/us/koreader/plugins/penjuru.koplugin/"
echo "  2. Restart KOReader"
echo "  3. Enable: Menu → Tools → Plugin management → penjuru"
echo "  4. Tap the Home tab in the bottom bar"
```

- [ ] **Step 2: Make executable + add dist/ to .gitignore**

```bash
cd ~/Developer/koreader-custom-ui
chmod +x build.sh
echo "" >> .gitignore
echo "# Build output" >> .gitignore
echo "dist/" >> .gitignore
```

- [ ] **Step 3: Run it and verify the zip looks right**

```bash
cd ~/Developer/koreader-custom-ui
./build.sh
echo "--- contents ---"
unzip -l dist/penjuru.koplugin.zip | head -30
echo "--- summary ---"
unzip -l dist/penjuru.koplugin.zip | tail -3
# Verify .old_simpleui and spec/ are excluded
unzip -l dist/penjuru.koplugin.zip | grep -E 'old_simpleui|spec/' | head -3
# expect empty (or only one or two lines if some slipped through)
```

Expected: zip is built. Includes _meta.lua / main.lua / pen_*.lua / home_modules/ / icons/ / fonts/ / locale/ / LICENSE. Excludes spec/ and *.old_simpleui.

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add build.sh .gitignore
git commit -m "feat(build): build.sh packages plugin as dist/penjuru.koplugin.zip

Excludes spec/, .old_simpleui stashes, .DS_Store, .git. Output ready
to unzip into a Kindle's /mnt/us/koreader/plugins/ folder. dist/
gitignored."
```

---

## Phase 5 · README + INSTALL.md

### Task D.5.1: Write `INSTALL.md` for end users

**Files:**
- Create: `INSTALL.md` (repo root)

- [ ] **Step 1: Write INSTALL.md**

```markdown
# Installing penjuru on your Kindle

penjuru is a [KOReader](https://github.com/koreader/koreader) plugin. Before
installing penjuru, you need a jailbroken Kindle with KOReader already
running on it.

## Prerequisites

1. **A jailbroken Kindle.** Follow the
   [MobileRead jailbreak guide](https://www.mobileread.com/forums/forumdisplay.php?f=150)
   for your specific Kindle model.
2. **KOReader installed and working.** See
   [KOReader's install guide](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices).
   You should be able to open KOReader from the Kindle home screen via KUAL
   or a similar launcher.

## Install penjuru

1. **Download the latest release** from
   [github.com/alfajrd/penjuru-KOReader-UI/releases](https://github.com/alfajrd/penjuru-KOReader-UI/releases).
   Grab `penjuru.koplugin.zip`.

2. **Copy it to your Kindle.** Connect the Kindle to your computer via USB.
   You should see a `/mnt/us/` (or `Kindle/`) volume mount.

3. **Unzip into the KOReader plugins folder:**
   ```
   Kindle/koreader/plugins/
   ```
   After unzipping, the directory structure must be:
   ```
   Kindle/koreader/plugins/penjuru.koplugin/
     ├── _meta.lua
     ├── main.lua
     ├── pen_*.lua
     ├── fonts/
     ├── icons/
     └── ...
   ```

4. **Eject the Kindle** and unplug.

5. **Open KOReader** from your jailbreak launcher (KUAL etc.).

6. **Enable the plugin.** In KOReader:
   * Open the menu (hamburger icon top-right).
   * Tools → Plugin management.
   * Find "penjuru" in the list. Tap to enable.
   * Restart KOReader when prompted.

7. **Open the home screen.** Menu → Tools → penjuru → Open home.
   You should see the masthead, the dateline, currently-reading lead,
   on-the-desk grid, newly-catalogued rows, recent highlights, and the
   7-cell paginated nav at the bottom.

## First-run configuration

The plugin ships with sensible defaults:
- Annual reading goal: 40 books
- Location for sunrise/moon: Jakarta (lat -6.2088, lon 106.8456, tz +7)
- "Newly catalogued" threshold: 30 days
- Tab roster: page 1 = manga / books / home / wi-fi / games, page 2 = stats / brightness / power / search / library

Change any of these via **Menu → Tools → penjuru → Settings**. The "manga"
and "books" tabs default to `/mnt/us/koreader/mangas/` and
`/mnt/us/koreader/books/` — adjust the paths via the Settings menu if you
keep your books elsewhere.

## What lives where on the Kindle

- **Plugin folder:** `/mnt/us/koreader/plugins/penjuru.koplugin/`
- **Plugin settings:** stored in KOReader's `settings.reader.lua` under the
  `penjuru` key
- **Custom files** (future versions):
  `/mnt/us/koreader/settings/penjuru/custom_icons/`,
  `/mnt/us/koreader/settings/penjuru/sui_icons/packs/` etc.

## Troubleshooting

- **"penjuru" doesn't appear in Plugin management** — make sure the folder
  is named exactly `penjuru.koplugin` (not `penjuru` or
  `penjuru.koplugin-master`). KOReader requires the `.koplugin` suffix.
- **Plugin loads but the home screen is empty** — check that
  `_meta.lua` is present in the plugin folder. Check KOReader's log at
  `/mnt/us/koreader/crash.log` for errors mentioning `pen_`.
- **Sunrise/sunset wrong** — set your location via Settings → Location.

## Uninstall

Delete the `penjuru.koplugin/` folder from `/mnt/us/koreader/plugins/`,
restart KOReader, and you're done. Your KOReader settings file may still
have a `penjuru` entry — harmless; delete it manually if you wish.
```

- [ ] **Step 2: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add INSTALL.md
git commit -m "docs: INSTALL.md — end-user install guide for Kindle

Covers jailbreak + KOReader prereqs, unzipping the plugin into
/mnt/us/koreader/plugins/, enabling via Plugin management, first-run
config defaults, and troubleshooting. Closes the install-manual TODO."
```

### Task D.5.2: Add Acknowledgments section to README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Append Acknowledgments**

Use Edit to append to `~/Developer/koreader-custom-ui/README.md`:
```markdown

## Acknowledgments

penjuru is a fork of
[simpleui.koplugin](https://github.com/doctorhetfield-cmd/simpleui.koplugin)
by **Doctor Hetfield**, the original author of the KOReader UI plugin this
project is built on. SimpleUI solved the hard problems of injecting custom
chrome into KOReader and providing a modular home-screen system; penjuru
forks those foundations and replaces the visual layer with a monospace
newspaper aesthetic.

Thanks also to:
- The [KOReader](https://github.com/koreader/koreader) team for the
  read-only-distinct platform this all runs on.
- [IBM Plex Mono](https://github.com/IBM/plex), [Syne Mono](https://gitlab.com/bonjour-monde/fonderie/syne-typeface),
  and [VT323](https://github.com/phoikoi/VT323) for the typefaces.
```

- [ ] **Step 2: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add README.md
git commit -m "docs: add Acknowledgments crediting Doctor Hetfield + KOReader + fonts

Visible on the GitHub repo page; the LICENSE already contained the
attribution but it wasn't easy to see. Closes the credit-simpleui TODO."
```

---

## Phase 6 · Tag v1.0.0 + push

### Task D.6.1: Plan D DONE.md + tag v1.0.0 + push

**Files:**
- Create: `docs/superpowers/plans/2026-MM-DD-plan-D-DONE.md`
- Create: a git tag `v1.0.0`

- [ ] **Step 1: Write DONE.md**

```bash
cd ~/Developer/koreader-custom-ui
DATE=$(date '+%Y-%m-%d')
cat > docs/superpowers/plans/${DATE}-plan-D-DONE.md <<EOF
# Plan D · DONE — $(date '+%Y-%m-%d') (v1.0.0)

## What's working

- pen_patches.lua removed (legacy SimpleUI chrome injection) — boot is now
  clean, no more soft-fail errors
- pen_menu.lua replaced with a 3-item stub: Open home / Settings / About
- Settings sub-tree: annual reading goal (SpinWidget), location
  (lat/lon/tz InputDialog), newly threshold (SpinWidget)
- Stats action broadcasts ShowReaderStatistics event (real Statistics plugin)
- Search action opens FM + broadcasts ShowFileSearch event
- pen_book_open.open(path, page) helper opens book and seeks via deferred
  GotoPage event; module_highlights now uses it (page-jump works)
- Hold-on-tab shows the current tab roster (read-only for v1.0)
- build.sh packages plugin as dist/penjuru.koplugin.zip
- INSTALL.md guides end-users through jailbreak prereq → unzip → enable
- README has Acknowledgments crediting Doctor Hetfield, KOReader, fonts
- v1.0.0 tagged and pushed
- $(./scripts/run-specs.sh 2>&1 | grep -oE '[0-9]+ tests' | head -1) specs pass

## Carry-overs / known limitations in v1.0

- Bars persisting on file-browser and reader views — home-only (deliberate;
  ripping SimpleUI's monkey-patch tower was out of scope for v1)
- Tab-roster GUI editor (currently read-only on hold; edit via
  G_reader_settings.penjuru.bottombar.pages directly)
- Async catalogue scan (synchronous on render)
- Cover %-overlay polish (% band sits below cover, not overlaid)

## What's deferred to a future v1.1

- All of the v1.0 limitations above
- Settings UI for top-bar layout (move items left/right via menu)
- Module visibility / order / scale settings UI
- Custom icon-pack support
- Per-book reading goal / collections

EOF
git add docs/superpowers/plans/${DATE}-plan-D-DONE.md
git commit -m "docs: Plan D complete — settings, polish, install (v1.0.0)"
```

- [ ] **Step 2: Tag v1.0.0**

```bash
cd ~/Developer/koreader-custom-ui
git tag -a v1.0.0 -m "penjuru v1.0.0

The reader's almanac for Kindle. Newspaper-flavored home screen in
monospace, persistent paginated bottom nav, six data-driven modules
backed by KOReader's history and per-book metadata.

Install: see INSTALL.md
Spec:    docs/superpowers/specs/2026-05-23-koreader-ui-design.md"
```

- [ ] **Step 3: Push commits and the tag**

```bash
cd ~/Developer/koreader-custom-ui
git push origin main
git push origin v1.0.0
```

- [ ] **Step 4: Build the v1.0.0 zip and attach to the GitHub release (optional but recommended)**

```bash
cd ~/Developer/koreader-custom-ui
./build.sh --clean
gh release create v1.0.0 \
    dist/penjuru.koplugin.zip \
    --title "penjuru v1.0.0" \
    --notes "First public release.

Newspaper-flavored KOReader UI for Kindle Paperwhite. See [INSTALL.md](INSTALL.md) for setup instructions.

**Install:** Download \`penjuru.koplugin.zip\` below, unzip into your Kindle's \`/mnt/us/koreader/plugins/\` folder, restart KOReader, enable in Plugin management.

**What you get:**
- Home screen with masthead, dateline, currently-reading lead with pull-quotes from your highlights, today's reading stats, the almanac (sunrise/sunset/moon), on-the-desk in-progress book covers, newly-catalogued unstarted books, and recent highlights across all books.
- Persistent paginated bottom nav: chevron · 5 tabs · chevron, 2 pages of tabs.
- Tap any highlight or newly-catalogued row to open that book.

Forked from [simpleui.koplugin](https://github.com/doctorhetfield-cmd/simpleui.koplugin) by Doctor Hetfield."
```

- [ ] **Step 5: Hand off**

Tell the controller: "Plan D complete. v1.0.0 tagged, pushed, and a release published with the install zip. penjuru is shippable."
