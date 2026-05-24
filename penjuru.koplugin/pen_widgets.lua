-- penjuru/pen_widgets
-- Shared widget primitives reused across home modules.
-- One source of truth for rule construction, section-head styling, and
-- space-between row layout.

local BlitBuffer = require("ffi/blitbuffer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Widget = require("ui/widget/widget")
local Style = require("pen_style")

local M = {}

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
    local row = HorizontalGroup:new{ align = "baseline" }
    for i, item in ipairs(items) do
        table.insert(row, item)
        if i < #items then table.insert(row, HorizontalSpan:new{ width = gap }) end
    end
    return row
end

return M
