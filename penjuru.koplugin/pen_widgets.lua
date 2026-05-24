-- penjuru/pen_widgets
-- Shared widget primitives reused across home modules.
-- One source of truth for rule construction, section-head styling, and
-- space-between row layout.

local BlitBuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local Style = require("pen_style")

local M = {}

-- TappableArea — generic tap-target wrapper used by home modules to make
-- a region clickable. CRITICAL design notes (see penjuru-plan-a-state.md):
--
--   1. KOReader dispatches gestures by METHOD NAME derived from the key
--      in ges_events. Key "TapArea" → method ":onTapArea()". The
--      `handler` field inside the table value is silently IGNORED. v1.0
--      used `handler = function()...end` and the user got stuck on the
--      Kindle three times.
--
--   2. self.dimen is the SAME Geom table referenced by the gesture
--      range. WidgetContainer:paintTo() mutates dimen.x/.y to absolute
--      screen coords during paint, so the range tracks the widget's
--      painted position automatically — no per-frame wiring needed.
local TappableArea = InputContainer:extend{
    on_tap = nil,  -- callback set per-instance
}
function TappableArea:init()
    if not self.dimen then
        self.dimen = Geom:new{ x = 0, y = 0, w = 0, h = 0 }
    end
    self.ges_events.TapArea = {
        GestureRange:new{ ges = "tap", range = self.dimen },
    }
end
function TappableArea:onTapArea()
    if self.on_tap then self.on_tap() end
    return true
end

-- tappable(child, width, height, on_tap) -> InputContainer
-- Wraps `child` in a tap-target sized w×h. `on_tap` fires on tap.
function M.tappable(child, w, h, on_tap)
    return TappableArea:new{
        dimen = Geom:new{ x = 0, y = 0, w = w, h = h },
        child,
        on_tap = on_tap,
    }
end

-- rule(width, weight, color)  -- solid rule, full width
function M.rule(w, weight, color)
    return LineWidget:new{
        dimen = { w = w, h = weight },
        background = color or Style.colors.ink,
    }
end

-- dashed_rule(width, weight, color, dash_len, gap_len)
-- KOReader's LineWidget supports `style = "dashed"`; we wrap it for clarity.
function M.dashed_rule(w, weight, color, dash_len, gap_len)
    return LineWidget:new{
        dimen = { w = w, h = weight },
        background = color or Style.colors.ink,
        style = "dashed",
        dash_length = dash_len or 8,
        gap_length = gap_len or 4,
    }
end

-- DottedLineWidget — custom widget that paints a row of small black squares.
-- Used for the spec's "minor rule" (1.5px dotted #aaa within sections).
local DottedLineWidget = Widget:extend{
    width = 0,
    weight = 1,
    color = BlitBuffer.COLOR_BLACK,
    dot_size = 2,
    gap = 4,
}

function DottedLineWidget:getSize()
    return { w = self.width, h = self.weight }
end

function DottedLineWidget:paintTo(bb, x, y)
    local step = self.dot_size + self.gap
    local i = 0
    while i + self.dot_size <= self.width do
        bb:paintRect(x + i, y, self.dot_size, self.weight, self.color)
        i = i + step
    end
end

-- dotted_rule(width, weight, color)
function M.dotted_rule(w, weight, color)
    return DottedLineWidget:new{
        width = w,
        weight = weight,
        color = color or Style.colors.rule,
    }
end

-- section_head(width, label)  -- VT323 underlined section heading
function M.section_head(w, label)
    local txt = TextWidget:new{
        text = label,
        face = Style.fonts.numerals(Style.size.section_head),
        fgcolor = Style.colors.ink,
    }
    return VerticalGroup:new{
        align = "left",
        txt,
        VerticalSpan:new{ width = 2 },
        M.rule(w, Style.rules.section, Style.colors.ink),
        VerticalSpan:new{ width = Style.gap.sm },
    }
end

-- spaced_row(width, items)  -- distribute items with space-between
function M.spaced_row(w, items)
    if #items == 0 then return HorizontalGroup:new{} end
    local total_text_w = 0
    for _, item in ipairs(items) do total_text_w = total_text_w + item:getSize().w end
    local gap = (#items > 1) and math.floor((w - total_text_w) / (#items - 1)) or 0
    local row = HorizontalGroup:new{ align = "center" }
    for i, item in ipairs(items) do
        table.insert(row, item)
        if i < #items then table.insert(row, HorizontalSpan:new{ width = gap }) end
    end
    return row
end

return M
