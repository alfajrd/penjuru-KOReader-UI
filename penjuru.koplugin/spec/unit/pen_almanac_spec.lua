local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_almanac", function()
    local A
    setup(function() A = require("pen_almanac") end)

    describe("sun_times", function()
        -- Jakarta on 2026-05-23: published sunrise ~05:51, sunset ~17:39
        -- (local time, UTC+7). ±5 min tolerance for NOAA formula precision.
        it("computes sunrise within 5 minutes for Jakarta on 2026-05-23", function()
            local r = A.sun_times(2026, 5, 23, -6.2088, 106.8456, 7)
            assert.is_not_nil(r.sunrise_min)
            assert.is_true(math.abs(r.sunrise_min - (5 * 60 + 51)) < 5,
                "expected sunrise ~351 min, got " .. tostring(r.sunrise_min))
        end)
        it("computes sunset within 5 minutes for Jakarta on 2026-05-23", function()
            local r = A.sun_times(2026, 5, 23, -6.2088, 106.8456, 7)
            assert.is_not_nil(r.sunset_min)
            assert.is_true(math.abs(r.sunset_min - (17 * 60 + 39)) < 5,
                "expected sunset ~1059 min, got " .. tostring(r.sunset_min))
        end)
    end)

    describe("format_hhmm", function()
        it("formats minutes-since-midnight as HH:MM", function()
            assert.equals("05:47", A.format_hhmm(5 * 60 + 47))
            assert.equals("18:02", A.format_hhmm(18 * 60 + 2))
            assert.equals("00:00", A.format_hhmm(0))
        end)
        it("returns --:-- for nil", function()
            assert.equals("--:--", A.format_hhmm(nil))
        end)
    end)
end)
