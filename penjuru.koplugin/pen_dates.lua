-- penjuru/pen_dates
-- Pure-data date helpers — no KOReader deps, easy to unit-test.

local M = {}

local MONTHS = {
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
}
local SHORT_MONTHS = {
    "jan", "feb", "mar", "apr", "may", "jun",
    "jul", "aug", "sep", "oct", "nov", "dec",
}
local DAYS = {
    "sunday", "monday", "tuesday", "wednesday",
    "thursday", "friday", "saturday",
}

function M.edition_for_hour(h)
    if h < 12 then return "morning"
    elseif h < 18 then return "afternoon"
    else return "evening" end
end

function M.day_of_year(t)
    return tonumber(os.date("%j", t))
end

function M.iso_week(t)
    -- ISO 8601 week number.  %V is supported by glibc/musl strftime (used in
    -- KOReader's LuaJIT on Linux/arm).  On platforms where %V returns "%V"
    -- literally (some macOS libc+LuaJIT combos), fall back to a pure-Lua
    -- calculation so specs pass everywhere.
    local v = os.date("%V", t)
    local n = tonumber(v)
    if n then return n end

    -- Pure-Lua ISO-8601 week fallback.
    -- ISO week 1 = the week containing the first Thursday of the year.
    local d   = os.date("*t", t)
    local doy = tonumber(os.date("%j", t))          -- 1-based day of year
    -- Weekday: ISO Monday=1 … Sunday=7; Lua wday Sunday=1 … Saturday=7.
    local iso_wd = (d.wday == 1) and 7 or (d.wday - 1)
    -- Ordinal of the nearest Thursday.
    local thursday_doy = doy + (4 - iso_wd)
    if thursday_doy < 1 then
        -- Thursday is in the previous year — find that year's week count.
        local prev_year_t = os.time{year = d.year - 1, month = 1, day = 1, hour = 12}
        local prev_year_days = tonumber(os.date("%j", os.time{year = d.year - 1, month = 12, day = 31, hour=12}))
        thursday_doy = thursday_doy + prev_year_days
        -- Recurse into previous year (one level only).
        return M.iso_week(prev_year_t + (thursday_doy - 1) * 86400)
    end
    -- Days per year for the year that owns this Thursday.
    local this_year_days = tonumber(os.date("%j", os.time{year = d.year, month = 12, day = 31, hour=12}))
    if thursday_doy > this_year_days then
        return 1   -- first week of next year
    end
    return math.floor((thursday_doy - 1) / 7) + 1
end

function M.format_long(t)
    local d = os.date("*t", t)
    -- Middle dot U+00B7, encoded as UTF-8 \xc2\xb7
    return string.format("%s \xc2\xb7 %d %s %d",
        DAYS[d.wday], d.day, SHORT_MONTHS[d.month], d.year)
end

function M.month_name(month_1_to_12)
    return MONTHS[month_1_to_12]
end

return M
