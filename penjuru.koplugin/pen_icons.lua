-- penjuru/pen_icons
-- Loads SVG icons from our bundled icons/penjuru/ directory.
-- Returns IconWidget instances (KOReader handles SVG -> BlitBuffer via NanoSVG).
--
-- API note: IconWidget resolves `icon` by name through its search dirs.
-- For absolute paths we use `file` instead, which bypasses name resolution
-- and makes IconWidget behave as a plain ImageWidget.

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
        file = M.path(name),
        width = size_px,
        height = size_px,
    }
end

return M
