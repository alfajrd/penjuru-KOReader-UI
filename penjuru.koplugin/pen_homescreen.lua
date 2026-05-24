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

    -- v1.2.2 — almanac module (pure-math, no I/O). day-of-year, week,
    -- sunrise/sunset (NOAA), moon phase. Defaults to Jakarta location;
    -- user can override via G_reader_settings.penjuru.almanac{lat,lon,tz}.
    local almanac_widget = Almanac.render(body_w)

    local stack = VerticalGroup:new{
        align = "center",
        name,
        VerticalSpan:new{ width = 8 },
        tagline,
        VerticalSpan:new{ width = 14 },
        masthead_rule,
        VerticalSpan:new{ width = 12 },
        dateline_row,
        VerticalSpan:new{ width = 30 },
        almanac_widget,
        VerticalSpan:new{ width = 40 },
        exit_hint,
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

    -- KOReader's proven dismissable pattern (verbatim from infomessage.lua):
    -- the ges_events table KEY must match a method NAME on this widget
    -- (key "TapClose" → method ":onTapClose()"). The `handler` field in
    -- the table value is IGNORED. v1.0 used `handler = function()...end`
    -- and got the user stuck because the methods never fired.
    if Device:isTouchDevice() then
        local fullscreen = Geom:new{
            x = 0, y = 0,
            w = Screen:getWidth(),
            h = Screen:getHeight(),
        }
        self.ges_events.TapClose = {
            GestureRange:new{ ges = "tap", range = fullscreen },
        }
        self.ges_events.HoldClose = {
            GestureRange:new{ ges = "hold", range = fullscreen },
        }
        self.ges_events.SwipeClose = {
            GestureRange:new{ ges = "swipe", range = fullscreen },
        }
    end
end

function MastheadWidget:onTapClose()
    UIManager:close(self)
    return true
end
-- Aliases so Hold and Swipe also close (the table keys above map to these).
MastheadWidget.onHoldClose = MastheadWidget.onTapClose
MastheadWidget.onSwipeClose = MastheadWidget.onTapClose
MastheadWidget.onAnyKeyPressed = MastheadWidget.onTapClose

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
