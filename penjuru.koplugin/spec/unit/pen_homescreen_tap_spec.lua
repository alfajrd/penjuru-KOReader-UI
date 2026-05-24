-- Integration spec: verifies that a Gesture event dispatched at the
-- masthead level actually reaches the TappableArea inside module_currently
-- (or any home module's tap target). Regression spec for v1.2.8 where the
-- user reported tap-to-open stopped working after the pen_widgets refactor.

local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("home tap dispatch through nested widget tree", function()
    local Homescreen, Geom, Event

    setup(function()
        Homescreen = require("pen_homescreen")
        Geom = require("ui/geometry")
        Event = require("ui/event")
    end)

    teardown(function() Homescreen.close() end)

    it("MastheadWidget propagates a Gesture event into its descendants", function()
        Homescreen.show()
        local widget = Homescreen._instance
        assert.is_not_nil(widget)

        -- Walk the tree and collect every InputContainer with ges_events.TapArea.
        local function collect_tappables(w, acc)
            acc = acc or {}
            if w.ges_events and w.ges_events.TapArea then
                table.insert(acc, w)
            end
            for i = 1, #w do
                if type(w[i]) == "table" then collect_tappables(w[i], acc) end
            end
            return acc
        end

        local tappables = collect_tappables(widget)
        -- The widget tree should have at least one TapArea — currently-reading
        -- card if history is non-empty.
        if #tappables == 0 then
            pending("no tappable cards rendered (empty history); skip dispatch test")
            return
        end

        local first = tappables[1]
        -- Force the dimen to a known fullscreen rect so range:match() succeeds
        -- without needing a real paintTo pass.
        first.dimen.x = 0
        first.dimen.y = 0
        first.dimen.w = 100
        first.dimen.h = 100
        -- Also reset the GestureRange.range to point at the freshly-set dimen.
        first.ges_events.TapArea[1].range = first.dimen

        -- Replace the on_tap callback so it doesn't actually try to open a book.
        local fired = false
        first.on_tap = function() fired = true end

        -- Synthesize a Gesture event at the centre of the rect.
        local ges_event = Event:new("Gesture", {
            ges = "tap",
            pos = Geom:new{ x = 50, y = 50, w = 0, h = 0 },
        })

        local consumed = widget:handleEvent(ges_event)
        assert.is_true(consumed)
        assert.is_true(fired, "TappableArea.on_tap callback never fired — the masthead's TapClose probably consumed the gesture first")
    end)
end)
