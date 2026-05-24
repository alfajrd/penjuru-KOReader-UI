-- home_modules/module_almanac
-- Renders the "the almanac" section: day of year, week, sun times, moon.
-- Pulls user location from KOReader settings (lat/lon/tz) — defaults to
-- Jakarta if unset. Plan D wires up a settings UI for these values.

local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Almanac = require("pen_almanac")
local Dates = require("pen_dates")

local M = {}

-- Default location: Sleman (Yogyakarta region, Indonesia).
-- Kept in sync with pen_settings_defaults.lua so callers that bypass the
-- settings table still get sensible coordinates.
local DEFAULT_LAT = -7.7167
local DEFAULT_LON = 110.3500
local DEFAULT_TZ = 7

local function user_location()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    local a = s.almanac or {}
    return a.lat or DEFAULT_LAT, a.lon or DEFAULT_LON, a.tz or DEFAULT_TZ
end

local function stat_line(w, label_text, value_text)
    local label = TextWidget:new{
        text = label_text,
        face = Style.fonts.body(Style.size.body - 4),
        fgcolor = Style.colors.ink_2,
    }
    local value = TextWidget:new{
        text = value_text,
        face = Style.fonts.numerals(Style.size.almanac_value),
        fgcolor = Style.colors.ink,
    }
    return Widgets.spaced_row(w, { label, value })
end

-- render(content_width) -> widget
function M.render(content_width)
    local t = os.time()
    local d = os.date("*t", t)
    local lat, lon, tz = user_location()
    local sun = Almanac.sun_times(d.year, d.month, d.day, lat, lon, tz)
    local moon = Almanac.moon_phase(d.year, d.month, d.day)

    return VerticalGroup:new{
        align = "left",
        Widgets.section_head(content_width, "the almanac"),
        stat_line(content_width, "day of year", tostring(Dates.day_of_year(t))),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "week no.", tostring(Dates.iso_week(t))),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "sun rises", Almanac.format_hhmm(sun.sunrise_min)),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "sun sets", Almanac.format_hhmm(sun.sunset_min)),
        VerticalSpan:new{ width = 2 },
        stat_line(content_width, "moon", moon.name),
    }
end

return M
