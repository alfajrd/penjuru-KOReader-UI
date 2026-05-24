-- penjuru/pen_style
-- Single source of truth for typography, color, rules, and spacing.
-- Every other module reads from here so there is one place to retune.

local Fonts = require("pen_fonts")
local Blitbuffer = require("ffi/blitbuffer")

local Style = {}

-- COLOR TOKENS (greyscale only — e-ink)
-- Blitbuffer.Color8(n) where 0 = black, 255 = white.
Style.colors = {
    paper     = Blitbuffer.COLOR_WHITE,        -- #fff
    ink       = Blitbuffer.COLOR_BLACK,        -- #111
    ink_2     = Blitbuffer.Color8(0x44),       -- #444
    ink_soft  = Blitbuffer.Color8(0x55),       -- #555
    ink_dim   = Blitbuffer.Color8(0x66),       -- #666
    ink_faint = Blitbuffer.Color8(0x77),       -- #777
    rule      = Blitbuffer.Color8(0xaa),       -- #aaa
    rule_soft = Blitbuffer.Color8(0xcc),       -- #ccc
    rule_dim  = Blitbuffer.Color8(0xdd),       -- #ddd
    divider   = Blitbuffer.Color8(0xee),       -- #eee
    disabled  = Blitbuffer.Color8(0xbb),       -- #bbb
}

-- FONT FACTORIES — call with size in px to get a Face.
Style.fonts = {
    headline = function(size) return Fonts:get("headline", size) end,
    display  = function(size) return Fonts:get("display", size) end,
    body     = function(size) return Fonts:get("body", size) end,
    italic   = function(size) return Fonts:get("italic", size) end,
    medium   = function(size) return Fonts:get("medium", size) end,
    bold     = function(size) return Fonts:get("bold", size) end,
    numerals = function(size) return Fonts:get("numerals", size) end,
}

-- TYPE SCALE — named sizes used across the home screen.
Style.size = {
    masthead_name    = 76,
    masthead_tagline = 20,
    dateline         = 20,
    section_head     = 36,  -- VT323
    headline         = 48,
    body             = 22,
    byline           = 21,
    pull             = 24,
    pull_dropcap     = 66,
    caption          = 18,
    stat_label       = 22,
    stat_value       = 34,  -- VT323
    almanac_value    = 32,  -- VT323
    cat_title        = 28,
    cat_author       = 20,
    cat_age          = 32,  -- VT323
    highlight_q      = 29,
    highlight_src    = 20,
    nav_label        = 22,
    nav_meta         = 19,
    top_bar          = 24,
}

-- RULES — line weights and styles for dividers.
Style.rules = {
    major     = 2,    -- solid #111 between sections
    minor     = 1.5,  -- dotted #aaa within section
    soft      = 1.5,  -- solid #eee between similar items
    masthead  = 2.5,  -- dashed #111 under masthead
    section   = 2.5,  -- solid #111 under section heads
    nav_top   = 3.5,  -- solid #111 above bottom nav
    active    = 7,    -- solid #111 top bar on active tab
}

-- SPACING — common gaps.
Style.gap = {
    xs = 4,
    sm = 8,
    md = 12,
    lg = 18,
    xl = 26,
}

-- LEGACY-API SHIM
-- Files inherited from SimpleUI (pen_titlebar, pen_bottombar, pen_menu, etc.)
-- still call methods that lived on the old style module (getIcon, etc.).
-- They'll be rewritten in Plans B/C/D, but until then we silently no-op any
-- unknown method/field call so the plugin keeps loading without crashing.
-- Reads return a stub function returning nil; this lets patterns like
-- `(_ss and _ss.getIcon("...")) or fallback` fall through to their fallback.
local function _stub() return nil end
setmetatable(Style, {
    __index = function(_, _key) return _stub end,
    __call  = function(t) return t end,  -- SUIStyle() pattern: returns the module table
})

return Style
