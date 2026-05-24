-- home_modules/module_ledger
-- Renders today's stats sidebar: reading min / pages / streak / year goal.

local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local function user_year_goal()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    return s.year_goal or 40
end

local function stat_row(w, label_text, value_text)
    local label = TextWidget:new{
        text = label_text,
        face = Style.fonts.body(Style.size.stat_label - 2),
        fgcolor = Style.colors.ink_2,
    }
    local value = TextWidget:new{
        text = value_text,
        face = Style.fonts.numerals(Style.size.stat_value),
        fgcolor = Style.colors.ink,
    }
    return Widgets.spaced_row(w, { label, value })
end

function M.render(content_width)
    local s = Data.read_today_stats()
    local now = os.date("*t")
    local goal = user_year_goal()
    return VerticalGroup:new{
        align = "left",
        Widgets.section_head(content_width, "today's ledger"),
        stat_row(content_width, "reading", s.reading_minutes .. "m"),
        VerticalSpan:new{ width = 2 },
        stat_row(content_width, "pages", tostring(s.pages)),
        VerticalSpan:new{ width = 2 },
        stat_row(content_width, "streak", s.streak_days .. "d"),
        VerticalSpan:new{ width = 2 },
        stat_row(content_width, tostring(now.year), s.year_finished .. "/" .. goal),
    }
end

return M
