local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_icons", function()
    local Icons
    setup(function() Icons = require("pen_icons") end)

    it("resolves a known icon path", function()
        local p = Icons.path("tab-home")
        assert.is_string(p)
        assert.is_true(p:match("tab%-home%.svg$") ~= nil)
    end)

    it("errors on unknown icon name", function()
        assert.has_error(function() Icons.path("nonexistent-icon-xyz") end)
    end)

    it("returns an IconWidget for a known icon", function()
        local w = Icons.widget("tab-home", 62)
        assert.is_not_nil(w)
        local size = w:getSize()
        assert.is_number(size.w)
        assert.is_number(size.h)
    end)
end)
