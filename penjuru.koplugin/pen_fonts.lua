-- penjuru/pen_fonts
-- Maps role names to bundled TTFs and caches loaded Face objects.
--
-- We use Freetype directly because Font:getFace() prepends FontList.fontdir
-- to any name that isn't in its fontmap, making absolute paths unusable.
-- Freetype.newFaceSize(absolute_path, px) works fine and returns the same
-- ftsize object that Font:getFace wraps.

local Freetype = require("ffi/freetype")
local Screen = require("device").screen
local logger = require("logger")

-- Resolve our plugin's font directory regardless of where KOReader is run from.
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local font_dir = plugin_dir .. "fonts/"

local ROLE_TO_FILE = {
    headline   = "SyneMono-Regular.ttf",
    display    = "SyneMono-Regular.ttf",
    body       = "IBMPlexMono-Regular.ttf",
    italic     = "IBMPlexMono-Italic.ttf",
    medium     = "IBMPlexMono-Medium.ttf",
    bold       = "IBMPlexMono-Bold.ttf",
    numerals   = "VT323-Regular.ttf",
}

local M = { _cache = {} }

function M:get(role, size)
    local file = ROLE_TO_FILE[role]
    if not file then
        error("pen_fonts: unknown role '" .. tostring(role) .. "'")
    end
    local key = role .. "@" .. tostring(size)
    if not self._cache[key] then
        local path = font_dir .. file
        local px = Screen:scaleBySize(size)
        local ftsize = Freetype.newFaceSize(path, px)
        self._cache[key] = {
            orig_font  = role,
            realname   = file,
            size       = px,
            orig_size  = size,
            ftsize     = ftsize,
            hash       = file .. px,
        }
        logger.dbg("pen_fonts: loaded", role, size, path)
    end
    return self._cache[key]
end

return M
