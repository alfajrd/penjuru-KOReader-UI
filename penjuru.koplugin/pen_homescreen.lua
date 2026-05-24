-- penjuru/pen_homescreen
-- v0: masthead-only placeholder so we can verify typography end-to-end
-- before building the full module set in Plan B.
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

local InputContainer = require("ui/widget/container/inputcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local Geom = require("ui/geometry")

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
    local S          = _style()
    local screen_w   = Screen:getWidth()
    local screen_h   = Screen:getHeight()

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

    local masthead = VerticalGroup:new{
        align = "center",
        name_widget,
        tagline_widget,
    }

    self[1] = FrameContainer:new{
        background  = S.colors.paper,
        bordersize  = 0,
        padding     = 0,
        margin      = 0,
        width       = screen_w,
        height      = screen_h,
        CenterContainer:new{
            dimen   = Geom:new{ w = screen_w, h = screen_h },
            masthead,
        },
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
