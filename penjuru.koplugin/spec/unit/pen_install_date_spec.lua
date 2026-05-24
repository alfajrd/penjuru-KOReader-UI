local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_install_date", function()
    local ID
    setup(function() ID = require("pen_install_date") end)

    describe("vol_and_no_for", function()
        it("returns vol=1, no=1 on the install date itself", function()
            local install = os.time{year=2026, month=5, day=24, hour=12}
            local r = ID.vol_and_no_for(install, install)
            assert.equals(1, r.vol)
            assert.equals(1, r.no)
        end)
        it("returns vol=1, no=10 nine days after install", function()
            local install = os.time{year=2026, month=5, day=24, hour=12}
            local r = ID.vol_and_no_for(install, install + 9 * 86400)
            assert.equals(1, r.vol)
            assert.equals(10, r.no)
        end)
        it("returns vol=2 after 365 days", function()
            local install = os.time{year=2026, month=5, day=24, hour=12}
            local r = ID.vol_and_no_for(install, install + 365 * 86400)
            assert.equals(2, r.vol)
            assert.equals(1, r.no)
        end)
        it("clamps negative deltas to vol=1 no=1", function()
            local install = os.time{year=2026, month=5, day=24, hour=12}
            local r = ID.vol_and_no_for(install, install - 86400)
            assert.equals(1, r.vol)
            assert.equals(1, r.no)
        end)
    end)

    describe("roman", function()
        it("converts 1..10 to lowercase roman", function()
            assert.equals("i",   ID.roman(1))
            assert.equals("ii",  ID.roman(2))
            assert.equals("iii", ID.roman(3))
            assert.equals("iv",  ID.roman(4))
            assert.equals("v",   ID.roman(5))
            assert.equals("ix",  ID.roman(9))
            assert.equals("x",   ID.roman(10))
        end)
    end)
end)
