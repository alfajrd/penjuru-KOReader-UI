local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_actions", function()
    local Actions
    setup(function() Actions = require("pen_actions") end)

    it("exposes a dispatch function", function()
        assert.is_function(Actions.dispatch)
    end)

    it("dispatch with nil returns false (no crash)", function()
        assert.is_false(Actions.dispatch(nil))
    end)

    it("dispatch with unknown action returns false", function()
        local ok = Actions.dispatch({ id = "x", action = "nonexistent" })
        assert.is_false(ok)
    end)

    it("dispatch with folder action missing target returns false", function()
        local ok = Actions.dispatch({ id = "manga", action = { type = "folder" } })
        assert.is_false(ok)
    end)

    it("dispatch with folder action pointing at nonexistent dir returns false", function()
        local ok = Actions.dispatch({
            id = "manga",
            action = { type = "folder", target = "/nonexistent_dir_xyz" }
        })
        assert.is_false(ok)
    end)
end)
