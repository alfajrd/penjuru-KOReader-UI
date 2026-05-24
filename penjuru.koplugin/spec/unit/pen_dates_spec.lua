require("commonrequire")

describe("pen_dates", function()
    local Dates
    setup(function()
        -- Add plugin dir to package.path so bare require("pen_dates") works.
        -- The plugin is symlinked into the emulator at plugins/penjuru.koplugin/
        local plugin_dir = require("lfs").currentdir() .. "/plugins/penjuru.koplugin"
        package.path = plugin_dir .. "/?.lua;" .. package.path
        Dates = require("pen_dates")
    end)

    describe("edition", function()
        it("returns 'morning' before noon", function()
            assert.equals("morning", Dates.edition_for_hour(0))
            assert.equals("morning", Dates.edition_for_hour(11))
        end)
        it("returns 'afternoon' from 12 to 17", function()
            assert.equals("afternoon", Dates.edition_for_hour(12))
            assert.equals("afternoon", Dates.edition_for_hour(17))
        end)
        it("returns 'evening' from 18 to 23", function()
            assert.equals("evening", Dates.edition_for_hour(18))
            assert.equals("evening", Dates.edition_for_hour(23))
        end)
    end)

    describe("day_of_year", function()
        it("returns 1 for Jan 1", function()
            assert.equals(1, Dates.day_of_year(os.time{year=2026, month=1, day=1, hour=12}))
        end)
        it("returns 143 for May 23 in a non-leap year", function()
            assert.equals(143, Dates.day_of_year(os.time{year=2026, month=5, day=23, hour=12}))
        end)
    end)

    describe("iso_week", function()
        it("returns 21 for 2026-05-23 (Saturday of ISO week 21)", function()
            assert.equals(21, Dates.iso_week(os.time{year=2026, month=5, day=23, hour=12}))
        end)
    end)

    describe("format_long", function()
        it("renders 'saturday · 23 may 2026' lowercase", function()
            local t = os.time{year=2026, month=5, day=23, hour=10, min=42}
            assert.equals("saturday \xc2\xb7 23 may 2026", Dates.format_long(t))
        end)
    end)
end)
