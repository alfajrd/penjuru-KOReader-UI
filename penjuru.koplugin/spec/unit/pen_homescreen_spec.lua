local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_homescreen v1.1-safe", function()
    local Homescreen
    setup(function() Homescreen = require("pen_homescreen") end)

    it("exposes the expected public API", function()
        assert.is_function(Homescreen.show)
        assert.is_function(Homescreen.refresh)
        assert.is_function(Homescreen.refreshImmediate)
        assert.is_function(Homescreen.close)
    end)

    it("has the SimpleUI-compat state fields", function()
        assert.equals(1, Homescreen._current_page)
        assert.is_nil(Homescreen._instance)
    end)

    -- v1.2.14.3: dismiss-by-tap-anywhere was removed. The masthead no
    -- longer registers TapClose / HoldClose / SwipeClose; the user
    -- dismisses the home via the bottom-nav buttons (each tap closes
    -- the home before dispatching) or the "× exit" pill in the topbar
    -- (exits KOReader entirely). The previous regression spec asserted
    -- the OLD behaviour (TapClose present + onTapClose method); the
    -- new equivalent asserts the OPPOSITE — none of those handlers
    -- should be on the widget after show().
    describe("no tap-anywhere-to-exit handlers (v1.2.14.3)", function()
        local widget
        setup(function()
            Homescreen.show()
            widget = Homescreen._instance
        end)
        teardown(function() Homescreen.close() end)

        it("widget instance exists after .show()", function()
            assert.is_not_nil(widget)
        end)

        it("does NOT register TapClose / HoldClose / SwipeClose", function()
            assert.is_nil(widget.ges_events.TapClose)
            assert.is_nil(widget.ges_events.HoldClose)
            assert.is_nil(widget.ges_events.SwipeClose)
        end)
    end)

    it("onCloseWidget clears Homescreen._instance", function()
        Homescreen.show()
        local w = Homescreen._instance
        w:onCloseWidget()
        assert.is_nil(Homescreen._instance)
    end)
end)
