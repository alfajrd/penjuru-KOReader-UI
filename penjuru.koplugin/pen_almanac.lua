-- penjuru/pen_almanac
-- Pure-math astronomical helpers. No KOReader deps; fully unit-testable.
-- Sunrise/sunset uses NOAA's solar position formulas
-- (https://gml.noaa.gov/grad/solcalc/calcdetails.html).

local M = {}

local function rad(deg) return deg * math.pi / 180 end
local function deg(r) return r * 180 / math.pi end

-- Julian day for date at midnight UTC.
local function julian_day(y, m, d)
    if m <= 2 then y = y - 1; m = m + 12 end
    local a = math.floor(y / 100)
    local b = 2 - a + math.floor(a / 4)
    return math.floor(365.25 * (y + 4716))
         + math.floor(30.6001 * (m + 1))
         + d + b - 1524.5
end

-- Exposed for testing / reuse by moon_phase in next task.
M._julian_day = julian_day

-- sun_times(year, month, day, lat, lon, tz_hours)
-- Returns { sunrise_min, sunset_min } in local minutes-since-midnight.
function M.sun_times(year, month, day, lat, lon, tz_hours)
    local jd = julian_day(year, month, day)
    local jc = (jd - 2451545.0) / 36525.0  -- Julian century

    local geom_mean_long = (280.46646 + jc * (36000.76983 + jc * 0.0003032)) % 360
    local geom_mean_anom = 357.52911 + jc * (35999.05029 - 0.0001537 * jc)
    local eccent_earth   = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc)
    local sun_eq_ctr = math.sin(rad(geom_mean_anom)) *
            (1.914602 - jc * (0.004817 + 0.000014 * jc))
        + math.sin(rad(2 * geom_mean_anom)) * (0.019993 - 0.000101 * jc)
        + math.sin(rad(3 * geom_mean_anom)) * 0.000289
    local sun_true_long  = geom_mean_long + sun_eq_ctr
    local sun_app_long   = sun_true_long - 0.00569
        - 0.00478 * math.sin(rad(125.04 - 1934.136 * jc))

    local mean_obliq = 23 + (26 + ((21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813)))) / 60) / 60
    local obliq_corr = mean_obliq + 0.00256 * math.cos(rad(125.04 - 1934.136 * jc))

    local sun_decl = deg(math.asin(math.sin(rad(obliq_corr)) * math.sin(rad(sun_app_long))))

    local var_y = math.tan(rad(obliq_corr / 2)) * math.tan(rad(obliq_corr / 2))
    local eq_of_time = 4 * deg(
        var_y * math.sin(2 * rad(geom_mean_long))
      - 2 * eccent_earth * math.sin(rad(geom_mean_anom))
      + 4 * eccent_earth * var_y * math.sin(rad(geom_mean_anom)) * math.cos(2 * rad(geom_mean_long))
      - 0.5 * var_y * var_y * math.sin(4 * rad(geom_mean_long))
      - 1.25 * eccent_earth * eccent_earth * math.sin(2 * rad(geom_mean_anom))
    )

    -- Hour angle for sunrise/sunset (solar altitude = -0.833° accounts
    -- for atmospheric refraction + apparent solar radius).
    local cos_ha = (math.cos(rad(90.833)) / (math.cos(rad(lat)) * math.cos(rad(sun_decl))))
                 - math.tan(rad(lat)) * math.tan(rad(sun_decl))
    if cos_ha > 1 then return { sunrise_min = nil, sunset_min = nil } end  -- polar night
    if cos_ha < -1 then return { sunrise_min = 0, sunset_min = 24 * 60 } end  -- polar day
    local ha = deg(math.acos(cos_ha))

    local solar_noon = (720 - 4 * lon - eq_of_time + tz_hours * 60)
    return {
        sunrise_min = math.floor(solar_noon - 4 * ha),
        sunset_min  = math.floor(solar_noon + 4 * ha),
    }
end

function M.format_hhmm(mins)
    if not mins then return "--:--" end
    return string.format("%02d:%02d", math.floor(mins / 60) % 24, mins % 60)
end

return M
