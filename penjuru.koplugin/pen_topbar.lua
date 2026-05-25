-- penjuru/pen_topbar
-- Persistent status row. Layout-driven: each item is independently
-- placeable left or right via settings; defaults to:
--   left:  clock, wi-fi, light
--   right: disk, battery
-- Items returning empty/nil are silently dropped.

local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Status = require("pen_status")

local M = {}

-- v1.2.13.2: defaults pin clock + wi-fi on the left and a "exit" pill on
-- the right end so the user can leave KOReader from the home overlay.
local DEFAULT_LAYOUT = {
    left = { "clock", "wifi" },
    right = { "disk", "battery", "exit" },
}

local LABEL_FOR = {
    clock = function() return Status.clock() end,
    wifi = function() return Status.wifi_label() end,
    light = function() return Status.frontlight_label() end,
    disk = function() return Status.disk_label() end,
    battery = function() return Status.battery_label() end,
    exit = function() return "× exit" end,
}

-- Items that should render as tap targets (with their on_tap callbacks).
local TAPPABLE = {
    exit = function() UIManager:quit() end,
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
    local g = HorizontalGroup:new{ align = "center" }
    local first = true
    for _, key in ipairs(items) do
        local fn = LABEL_FOR[key]
        local txt = fn and fn()
        if txt and txt ~= "" then
            local widget = pill(txt, want_separator and not first)
            if TAPPABLE[key] then
                -- v1.2.13.2: wrap tappable pills (e.g. "× exit") in a
                -- Widgets.tappable so KOReader dispatches the tap by
                -- method name (TapArea → :onTapArea), the only proven
                -- pattern that doesn't lock up the device.
                local pw = widget:getSize().w
                local ph = widget:getSize().h
                widget = Widgets.tappable(widget, pw, ph, TAPPABLE[key])
            end
            table.insert(g, widget)
            table.insert(g, HorizontalSpan:new{ width = 18 })
            first = false
        end
    end
    return g
end

-- render(content_width) -> widget  -- top status bar with bottom rule
function M.render(content_width)
    local layout = user_layout()
    local left = cluster(layout.left or {}, true)
    local right = cluster(layout.right or {}, true)

    -- Spaced row: left to leading edge, right to trailing edge.
    local left_w = left:getSize().w
    local right_w = right:getSize().w
    local fill = math.max(0, content_width - left_w - right_w)
    local row = HorizontalGroup:new{ align = "center" }
    table.insert(row, left)
    table.insert(row, HorizontalSpan:new{ width = fill })
    table.insert(row, right)

    return VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = Style.gap.sm },
        row,
        VerticalSpan:new{ width = Style.gap.sm },
        Widgets.rule(content_width, Style.rules.major, Style.colors.ink),
    }
end

return M
