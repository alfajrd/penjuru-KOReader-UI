-- penjuru/pen_homescreen
-- v1.1-safe: MINIMAL masthead-only home with a proven tap-to-close.
--
-- v1.0 tried to ship the full design (modules + bottom nav + top bar)
-- in one shot and got the user stuck on their Kindle three times because
-- our gesture-to-close handlers used a `handler` field that KOReader's
-- InputContainer dispatch silently ignores. KOReader actually dispatches
-- by METHOD name derived from the ges_events table key
-- (key "TapClose" -> method ":onTapClose()"). This file uses the EXACT
-- pattern from ui/widget/infomessage.lua, which is the most-tested
-- dismissable overlay in KOReader.
--
-- The full home design lives at .old_v1 (committed in git history).
-- v1.2 will re-add modules one at a time, each verified in the emulator
-- before deploy.
--
-- API contract preserved from the original so existing callers
-- (pen_quickactions, pen_bottombar, main.lua, pen_menu) keep working:
--
--   Homescreen.show(on_qa_tap, on_goal_tap)
--   Homescreen.refresh()
--   Homescreen.refreshImmediate()
--   Homescreen.close()
--   Homescreen._instance
--   Homescreen._current_page

local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local GestureRange    = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InputContainer  = require("ui/widget/container/inputcontainer")
local LineWidget      = require("ui/widget/linewidget")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local Device          = require("device")
local Screen          = Device.screen
local Style           = require("pen_style")
local Dates           = require("pen_dates")
local InstallDate     = require("pen_install_date")
local Almanac         = require("home_modules/module_almanac")
local Ledger          = require("home_modules/module_ledger")
-- v1.2.11: module_currently is retired — recent highlights occupies its
-- lead slot. v1.2.12: module_catalogued is also dropped from the home.
local Desk            = require("home_modules/module_desk")
local Highlights      = require("home_modules/module_highlights")
-- v1.2.13: persistent top status row (clock · wi-fi · disk · battery).
local Topbar          = require("pen_topbar")
-- v1.2.14: persistent 7-tab paginated bottom nav (the v1.0 lock-up
-- widget). Mounted only after the bottombar's broken handler= antipattern
-- was refactored onto Widgets.tappable (see pen_bottombar_tap_spec).
local Bottombar       = require("pen_bottombar")
local Actions         = require("pen_actions")

local Homescreen = {
    _instance      = nil,
    _current_page  = 1,
}

local MastheadWidget = InputContainer:extend{
    name              = "homescreen",
    covers_fullscreen = true,
    -- _navbar_closing_intentionally kept for compatibility with pen_bottombar
    -- detection of "is the home open?" — see pen_quickactions.
    _navbar_closing_intentionally = false,
}

function MastheadWidget:init()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    -- Body content width (the bars + masthead span screen; the dateline row
    -- gets the same content area as future modules will).
    local body_pad_x = 60
    local body_w = screen_w - 2 * body_pad_x

    -- Masthead stack (centered).
    local name = TextWidget:new{
        text    = "penjuru pikiran",
        face    = Style.fonts.headline(Style.size.masthead_name),
        fgcolor = Style.colors.ink,
    }
    local tagline = TextWidget:new{
        text    = "a reader's almanac · mind-wide",
        face    = Style.fonts.body(Style.size.masthead_tagline),
        fgcolor = Style.colors.ink_soft,
    }

    -- v1.2.1 — dateline row, three cells laid out with space-between.
    -- Pure-data; uses pen_install_date + pen_dates which are spec-tested.
    local install_ts = InstallDate.get_install_ts(
        rawget(_G, "G_reader_settings"), os.time())
    local vn = InstallDate.vol_and_no_for(install_ts, os.time())
    local d = os.date("*t")
    local vol_w = TextWidget:new{
        text    = "vol. " .. InstallDate.roman(vn.vol) .. " · no. " .. vn.no,
        face    = Style.fonts.body(Style.size.dateline),
        fgcolor = Style.colors.ink_2,
    }
    local date_w = TextWidget:new{
        text    = Dates.format_long(os.time()),
        face    = Style.fonts.body(Style.size.dateline),
        fgcolor = Style.colors.ink_2,
    }
    local edition_w = TextWidget:new{
        text    = Dates.edition_for_hour(d.hour) .. " edition",
        face    = Style.fonts.body(Style.size.dateline),
        fgcolor = Style.colors.ink_2,
    }
    -- Space-between layout: insert two HorizontalSpans sized to fill.
    local left_w = vol_w:getSize().w
    local mid_w = date_w:getSize().w
    local right_w = edition_w:getSize().w
    local total_text = left_w + mid_w + right_w
    local gap = math.max(0, math.floor((body_w - total_text) / 2))
    local dateline_row = HorizontalGroup:new{
        align = "center",
        vol_w,
        HorizontalSpan:new{ width = gap },
        date_w,
        HorizontalSpan:new{ width = gap },
        edition_w,
    }

    -- Dashed rule under masthead (between masthead/tagline and dateline).
    local masthead_rule = LineWidget:new{
        dimen = { w = body_w, h = 2 },
        background = Style.colors.ink,
        style = "dashed",
        dash_length = 8,
        gap_length = 4,
    }

    local exit_hint = TextWidget:new{
        text    = "tap anywhere to exit",
        face    = Style.fonts.italic(Style.size.byline),
        fgcolor = Style.colors.ink_faint,
    }

    -- v1.2.2 — almanac module (pure-math, no I/O).
    local almanac_widget = Almanac.render(body_w)

    -- v1.2.3 — today's ledger (reading min / pages / streak / year goal).
    -- Reads from KOReader's statistics.sqlite3 via pen_data.read_today_stats;
    -- falls back to zeros if the Statistics plugin isn't installed.
    local ledger_widget = Ledger.render(body_w)

    -- v1.2.12 — home modules:
    --   highlights: 3 most recent annotations across all books (lead slot,
    --               tap → open book at that page)
    --   desk:       5 cover thumbnails of in-progress books (tap → open)
    --   ledger + almanac: side-by-side bottom row, each gets ~half body_w
    -- Each module degrades gracefully when its data source is empty.
    local highlights_widget = Highlights.render(body_w)
    local desk_widget       = Desk.render(body_w)

    -- Side-by-side stats: split the body into two columns with a small gap
    -- and a thin vertical rule between them. Matches the user's sketch:
    --   today's ledger  |  the almanac
    local col_gap = 30
    local col_w = math.floor((body_w - col_gap) / 2)
    local ledger_widget  = Ledger.render(col_w)
    local almanac_widget = Almanac.render(col_w)
    local stats_row_h = math.max(
        ledger_widget:getSize().h, almanac_widget:getSize().h)
    local stats_row = HorizontalGroup:new{
        align = "top",
        ledger_widget,
        HorizontalSpan:new{ width = math.floor(col_gap / 2) },
        LineWidget:new{
            dimen = { w = 2, h = stats_row_h },
            background = Style.colors.ink_dim or Style.colors.ink,
        },
        HorizontalSpan:new{ width = math.floor(col_gap / 2) },
        almanac_widget,
    }

    -- v1.2.13: persistent status row sits above the masthead — pure
    -- render, no gestures. Refreshes whenever the home opens.
    local topbar_widget = Topbar.render(body_w)

    -- v1.2.14: persistent paginated bottom nav. Tap a tab → dispatch via
    -- pen_actions (folder jumps, wifi toggle, etc.). Tap a chevron →
    -- bottombar updates its _current_page and calls on_paginate, which
    -- re-renders the entire home so the new page's cells appear.
    --
    -- v1.2.14.3: close the home BEFORE dispatching the action. Otherwise
    -- the overlay sits on top of whatever the action navigates to (e.g.
    -- the file manager jumps to /mnt/us/mangas but you can't see it
    -- because the home is in the way). For modal actions (wifi toggle,
    -- brightness widget, power confirm) the action's own UI pops above
    -- the FM beneath the home, but closing first keeps the visual flow
    -- predictable.
    Bottombar.set_on_paginate(function() Homescreen.refresh() end)
    Bottombar.set_active("home")
    local bottombar_widget = Bottombar.render(body_w, function(tab)
        Homescreen.close()
        Actions.dispatch(tab)
    end)

    -- v1.2.11: currently-reading card retired. v1.2.12: newly-catalogued
    -- dropped; ledger + almanac paired side-by-side per user sketch.
    -- v1.2.13: top status bar prepended above the masthead.
    -- v1.2.14: bottom nav appended below the stats row, replacing the
    -- "tap anywhere to exit" hint (the nav itself has a hold-for-settings
    -- hint baked into its meta row).
    local stack = VerticalGroup:new{
        align = "center",
        topbar_widget,
        VerticalSpan:new{ width = 20 },
        name,
        VerticalSpan:new{ width = 8 },
        tagline,
        VerticalSpan:new{ width = 14 },
        masthead_rule,
        VerticalSpan:new{ width = 12 },
        dateline_row,
        VerticalSpan:new{ width = 30 },
        highlights_widget,
        VerticalSpan:new{ width = 22 },
        desk_widget,
        VerticalSpan:new{ width = 22 },
        stats_row,
        VerticalSpan:new{ width = 24 },
        bottombar_widget,
    }

    self[1] = FrameContainer:new{
        background = Style.colors.paper,
        bordersize = 0,
        padding    = 0,
        margin     = 0,
        width      = screen_w,
        height     = screen_h,
        CenterContainer:new{
            dimen = Geom:new{ w = screen_w, h = screen_h },
            stack,
        },
    }

    self.dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h }

    -- v1.2.14.3: tap-anywhere-to-exit removed. Reasons:
    --   1. Tapping the disabled "next" chevron on page 2 of the bottom
    --      nav fell through to the masthead's TapClose and crashed the
    --      app (still tracing the exact race; remove the trigger so it
    --      can't happen).
    --   2. The "× exit" pill in the top-right of the status bar lets
    --      the user leave KOReader; the bound gesture "Simple UI:
    --      Toggle Homescreen / Library" dismisses the home overlay.
    --      Tap-anywhere-to-exit is redundant.
    -- (Old TapClose / HoldClose / SwipeClose / AnyKeyPressed handlers
    -- and their gesture range registrations all removed.)
end

function MastheadWidget:onCloseWidget()
    if Homescreen._instance == self then
        Homescreen._instance = nil
    end
end

-- ---------------------------------------------------------------------------
-- Public API (matches what pen_quickactions / pen_bottombar / main.lua call)

function Homescreen.show(_on_qa_tap, _on_goal_tap)
    -- Single-instance: tear down any existing overlay before showing a new one.
    if Homescreen._instance then
        UIManager:close(Homescreen._instance)
        Homescreen._instance = nil
    end
    local w = MastheadWidget:new{}
    Homescreen._instance = w
    UIManager:show(w)
end

function Homescreen.refresh()
    Homescreen.show()
end
Homescreen.refreshImmediate = Homescreen.refresh

function Homescreen.close()
    if Homescreen._instance then
        UIManager:close(Homescreen._instance)
        Homescreen._instance = nil
    end
end

return Homescreen
