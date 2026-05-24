local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_status", function()
    local S
    setup(function() S = require("pen_status") end)

    it("clock() returns HH:MM string", function()
        local s = S.clock()
        assert.is_string(s)
        assert.is_true(s:match("^%d%d:%d%d$") ~= nil, "got '" .. s .. "'")
    end)

    it("battery_pct() returns a number 0-100 or nil", function()
        local p = S.battery_pct()
        if p ~= nil then
            assert.is_number(p)
            assert.is_true(p >= 0 and p <= 100)
        end
    end)

    it("battery_label() always returns a string", function()
        assert.is_string(S.battery_label())
    end)

    it("wifi_label() returns a short string", function()
        local s = S.wifi_label()
        assert.is_string(s)
    end)

    it("frontlight_label() returns a string or nil", function()
        local s = S.frontlight_label()
        if s ~= nil then assert.is_string(s) end
    end)

    it("disk_label() returns a string", function()
        local s = S.disk_label()
        assert.is_string(s)
    end)
end)
