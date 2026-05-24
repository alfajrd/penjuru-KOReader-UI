-- penjuru/pen_homescreen
-- v0.2: full body composition — six Phase 1-6 modules in two-column layout.
-- Replaces the Plan A italic placeholder with the real module tree.
--
-- API contract preserved from the SimpleUI-derived original so that all
-- existing callers (pen_quickactions, pen_bottombar, main.lua, pen_menu)
-- keep working without modification:
--
--   Homescreen.show(on_qa_tap, on_goal_tap)   -- open / reopen
--   Homescreen.refresh(...)                    -- no-op until Plan B
--   Homescreen.refreshImmediate(...)           -- no-op until Plan B
--   Homescreen.close()                         -- close the widget
--   Homescreen._instance                       -- live widget or nil
--   Homescreen._current_page                   -- page cursor (always 1 here)

local InputContainer  = require("ui/widget/container/inputcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer  = require("ui/widget/container/framecontainer")
local TextWidget      = require("ui/widget/textwidget")
local VerticalGroup   = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local VerticalSpan    = require("ui/widget/verticalspan")
local LineWidget      = require("ui/widget/linewidget")
local Screen          = require("device").screen
local UIManager       = require("ui/uimanager")
local Geom            = require("ui/geometry")
local TopBar          = require("pen_topbar")
local BottomBar       = require("pen_bottombar")
local Actions         = require("pen_actions")
local Dates           = require("pen_dates")
local InstallDate     = require("pen_install_date")
local Currently       = require("home_modules/module_currently")
local Ledger          = require("home_modules/module_ledger")
local Almanac         = require("home_modules/module_almanac")
local Desk            = require("home_modules/module_desk")
local Catalogued      = require("home_modules/module_catalogued")
local Highlights      = require("home_modules/module_highlights")

-- Lazy-load Style so that any early requires (before pen_style is ready) do
-- not crash the whole plugin.  Each call will succeed because by the time
-- show() is invoked all dependencies are initialised.
local function _style()
    local ok, S = pcall(require, "pen_style")
    if ok then return S end
    -- Minimal fallback so the widget can still render without Style
    local BB = require("ffi/blitbuffer")
    local ff = require("ui/fontface")
    return {
        colors = { paper = BB.COLOR_WHITE, ink = BB.COLOR_BLACK, ink_soft = BB.Color8(0x55) },
        fonts  = {
            headline = function(sz) return ff.loadFace("NotoSans", sz) end,
            body     = function(sz) return ff.loadFace("NotoSans", sz) end,
        },
        size = { masthead_name = 56, masthead_tagline = 20 },
    }
end

-- ---------------------------------------------------------------------------
-- MastheadWidget — the full-screen placeholder widget
-- ---------------------------------------------------------------------------
local MastheadWidget = InputContainer:extend{
    name = "homescreen",   -- keeps the HS-open detection in pen_bottombar happy
    covers_fullscreen = true,
    -- Called by pen_bottombar / main.lua to know the tab is active.
    _navbar_closing_intentionally = false,
}

function MastheadWidget:init()
    local S        = _style()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()

    -- Horizontal padding on each side; content width = screen_w - 2 * PAD.
    local PAD      = 36
    local content_w = screen_w - 2 * PAD

    -- -----------------------------------------------------------------------
    -- Helper: build a horizontal rule line.
    -- NOTE: LineWidget supports style = "solid" and style = "dashed" only.
    -- "dotted" is NOT supported — the dateline rule falls back to solid with
    -- a lighter color (Style.colors.rule_soft) to visually distinguish it from
    -- the masthead dashed rule.  A proper dotted LineWidget can be added in
    -- Plan B if the visual difference is needed on-device.
    -- -----------------------------------------------------------------------
    local function rule(w, weight, color, style)
        return LineWidget:new{
            dimen      = Geom:new{ w = w, h = math.max(1, math.floor(weight)) },
            background = color,
            style      = style or "solid",
        }
    end

    -- -----------------------------------------------------------------------
    -- Helper: three-cell space-between row.
    -- items: array of TextWidgets laid out with equal gaps between them.
    -- -----------------------------------------------------------------------
    local function spaced_row(w, items)
        local total_text_w = 0
        for _, item in ipairs(items) do
            total_text_w = total_text_w + item:getSize().w
        end
        local gap = (#items > 1)
            and math.floor((w - total_text_w) / (#items - 1))
            or 0
        local row = HorizontalGroup:new{ align = "baseline" }
        for i, item in ipairs(items) do
            table.insert(row, item)
            if i < #items then
                table.insert(row, HorizontalSpan:new{ width = gap })
            end
        end
        return row
    end

    -- -----------------------------------------------------------------------
    -- 1. Masthead: name + tagline
    -- -----------------------------------------------------------------------
    local name_widget = TextWidget:new{
        text    = "penjuru pikiran",
        face    = S.fonts.headline(S.size.masthead_name),
        fgcolor = S.colors.ink,
    }
    local tagline_widget = TextWidget:new{
        text    = "a reader\xe2\x80\x99s almanac \xc2\xb7 mind-wide",
        face    = S.fonts.body(S.size.masthead_tagline),
        fgcolor = S.colors.ink_soft,
    }

    -- -----------------------------------------------------------------------
    -- 2. Masthead dashed rule  (Style.rules.masthead = 2.5 → 2px, dashed)
    -- -----------------------------------------------------------------------
    local masthead_rule = rule(content_w, S.rules.masthead, S.colors.ink, "dashed")

    -- -----------------------------------------------------------------------
    -- 3. Dateline row — three cells with space-between layout
    --    Left  : "vol. <roman> · no. <day>"  (computed from install date)
    --    Center: full long date via Dates.format_long
    --    Right : "<edition> edition"
    -- -----------------------------------------------------------------------
    local now       = os.time()
    local d         = os.date("*t", now)
    local date_face = S.fonts.body(S.size.dateline)
    local date_color = S.colors.ink_2

    local install_ts = InstallDate.get_install_ts(
        rawget(_G, "G_reader_settings"), now)
    local vn = InstallDate.vol_and_no_for(install_ts, now)
    local vol_text = "vol. " .. InstallDate.roman(vn.vol) .. " \xc2\xb7 no. " .. vn.no
    local vol_widget = TextWidget:new{
        text    = vol_text,
        face    = date_face,
        fgcolor = date_color,
    }
    local date_widget = TextWidget:new{
        text    = Dates.format_long(now),
        face    = date_face,
        fgcolor = date_color,
    }
    local edition_widget = TextWidget:new{
        text    = Dates.edition_for_hour(d.hour) .. " edition",
        face    = date_face,
        fgcolor = date_color,
    }

    local dateline_row = spaced_row(content_w, {
        vol_widget,
        date_widget,
        edition_widget,
    })

    -- -----------------------------------------------------------------------
    -- 4. Dateline dotted rule  (Style.rules.minor = 1.5 → 1px, solid #aaa)
    --    Dotted style is unsupported by LineWidget; using solid + rule color.
    -- -----------------------------------------------------------------------
    local dateline_rule = rule(content_w, S.rules.minor, S.colors.rule, "solid")

    -- -----------------------------------------------------------------------
    -- 5. Body — two-column module composition
    --    Columns: 1.5fr (left) / 1fr (right), 30px gap between them.
    -- -----------------------------------------------------------------------
    local col_gap = 30
    local left_w  = math.floor((content_w - col_gap) * 0.6)
    local right_w = content_w - col_gap - left_w

    -- Row 1: currently-reading (left) | ledger + almanac stacked (right)
    local body_row1 = HorizontalGroup:new{
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

    -- Row 2: on the desk (left) | newly catalogued (right)
    local body_row2 = HorizontalGroup:new{
        align = "top",
        Desk.render(left_w),
        HorizontalSpan:new{ width = col_gap },
        Catalogued.render(right_w),
    }

    -- Row 3: recent highlights — full width
    local body_row3 = Highlights.render(content_w)

    -- -----------------------------------------------------------------------
    -- Compose into a VerticalGroup, centered on screen.
    -- -----------------------------------------------------------------------
    local body = VerticalGroup:new{
        align = "center",
        -- masthead block
        name_widget,
        VerticalSpan:new{ width = S.gap.sm },
        tagline_widget,
        VerticalSpan:new{ width = S.gap.lg },
        -- dashed rule under masthead
        masthead_rule,
        VerticalSpan:new{ width = S.gap.sm },
        -- dateline row
        dateline_row,
        VerticalSpan:new{ width = S.gap.sm },
        -- solid rule under dateline (dotted fallback)
        dateline_rule,
        VerticalSpan:new{ width = S.gap.xl },
        -- body modules
        body_row1,
        VerticalSpan:new{ width = 18 },
        body_row2,
        VerticalSpan:new{ width = 18 },
        body_row3,
    }

    -- -------------------------------------------------------------------
    -- Chrome: top bar (full width) + padded body + bottom bar (full width)
    -- -------------------------------------------------------------------
    local top_bar = TopBar.render(screen_w)

    BottomBar.set_active("home")
    BottomBar.set_page(1)
    BottomBar.set_on_paginate(function()
        local HS = package.loaded["pen_homescreen"]
        if HS and HS.refresh then pcall(HS.refresh) end
    end)
    local bottom_bar = BottomBar.render(screen_w, function(tab)
        Actions.dispatch(tab)
    end)

    -- Wrap the body content in a padded FrameContainer so it keeps its
    -- existing horizontal indent.  Width is screen_w; the FrameContainer
    -- handles the left/right PAD internally via padding_left/padding_right.
    local inner = FrameContainer:new{
        background    = S.colors.paper,
        bordersize    = 0,
        padding_left  = PAD,
        padding_right = PAD,
        padding_top   = 0,
        padding_bottom = 0,
        margin        = 0,
        width         = screen_w,
        body,
    }

    -- Outer VerticalGroup: top bar, padded body, bottom bar — all left-aligned
    -- so each child starts at x=0 (full screen width).
    local outer = VerticalGroup:new{
        align = "left",
        top_bar,
        inner,
        bottom_bar,
    }

    self[1] = FrameContainer:new{
        background = S.colors.paper,
        bordersize = 0,
        padding    = 0,
        margin     = 0,
        width      = screen_w,
        height     = screen_h,
        outer,
    }
    -- Give the widget its own bounding box so UIManager can paint it.
    self.dimen = Geom:new{ x = 0, y = 0, w = screen_w, h = screen_h }
end

-- Tapping anywhere closes the homescreen (returns to FM).
function MastheadWidget:onTapClose()
    UIManager:close(self)
    return true
end

-- Keep the widget closeable via the back gesture / close event.
function MastheadWidget:onClose()
    UIManager:close(self)
    return true
end

-- Update the module-level _instance reference when the widget is closed.
function MastheadWidget:onCloseWidget()
    local HS = package.loaded["pen_homescreen"]
    if HS and HS._instance == self then
        HS._instance = nil
    end
end

-- ---------------------------------------------------------------------------
-- Module table — same shape as the original so all callers work unchanged.
-- ---------------------------------------------------------------------------
local Homescreen = {
    _instance     = nil,
    _current_page = 1,
}

--- Open (or reopen) the homescreen.
--- on_qa_tap  : function(action_id) called when a QA button is tapped (unused v0)
--- on_goal_tap: function()          called when the goal widget is tapped (unused v0)
function Homescreen.show(_on_qa_tap, _on_goal_tap)
    if Homescreen._instance then
        UIManager:close(Homescreen._instance)
        Homescreen._instance = nil
    end
    local w = MastheadWidget:new{}
    Homescreen._instance = w
    UIManager:show(w)
end

--- Refresh the homescreen content.  No-op in v0 — there is no dynamic content.
function Homescreen.refresh(_keep_cache, _books_only, _stats_only)
    -- no-op: full data modules ship in Plan B
end

--- Synchronous immediate refresh.  No-op in v0.
function Homescreen.refreshImmediate(_keep_cache)
    -- no-op: full data modules ship in Plan B
end

--- Close the homescreen widget if it is open.
function Homescreen.close()
    if Homescreen._instance then
        UIManager:close(Homescreen._instance)
        Homescreen._instance = nil
    end
end

-- Stub out the style helpers called by pen_menu so those menu items degrade
-- gracefully instead of crashing on require("pen_homescreen").styleXxx().
function Homescreen.styleFreeBgCache() end
function Homescreen.rebuildLayout()    end
function Homescreen.styleGetWallpaper()         return nil end
function Homescreen.styleSetWallpaper(_p)       end
function Homescreen.styleStatusbarTransparent() return false end
function Homescreen.styleSetStatusbarTransparent(_on) end
function Homescreen.styleNavbarTransparent()    return false end
function Homescreen.styleSetNavbarTransparent(_on) end
function Homescreen.styleGetWallpapersDir()     return nil end
function Homescreen.styleScanWallpapers()       return {} end
function Homescreen.styleGetBgWidget()          return nil end
function Homescreen.styleGetWallpaperOpacityValue() return 100 end
function Homescreen.styleGetWallpaperShowInFM() return false end
function Homescreen.styleSetWallpaperShowInFM(_on) end
function Homescreen.styleGetWallpaperEnabled()  return false end
function Homescreen.styleSetWallpaperEnabled(_on) end
function Homescreen.styleGetWallpaperStretch()  return false end
function Homescreen.styleSetWallpaperStretch(_on) end
function Homescreen.invalidateLabelCache()      end

-- Stub pagination constants / methods referenced from pen_menu.
Homescreen.PAGE_BREAK_ID = "__page_break__"

return Homescreen
