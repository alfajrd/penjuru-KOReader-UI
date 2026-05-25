-- v1.2.14 regression spec: every cell in pen_bottombar must use the
-- correct method-name dispatch (ges_events.TapArea → :onTapArea),
-- NOT the broken `handler = function()` antipattern that locked
-- the Kindle three times in v1.0.

local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_bottombar tap dispatch", function()
    local Bottombar, Geom, Event

    setup(function()
        Bottombar = require("pen_bottombar")
        Geom = require("ui/geometry")
        Event = require("ui/event")
    end)

    it("renders without error", function()
        local widget = Bottombar.render(1116, function() end)
        assert.is_not_nil(widget)
    end)

    it("every interactive cell has ges_events.TapArea (method-name dispatch)", function()
        local widget = Bottombar.render(1116, function() end)

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
        -- 5 content tabs always tappable; prev/next chevrons tappable on
        -- non-edge pages (only the active page determines this — for
        -- page 1 default, prev is disabled, so 5 + 1 = 6 tap targets).
        assert.is_true(#tappables >= 5,
            "expected at least 5 tap targets, got " .. #tappables)

        -- Every tap target must define both the gesture range AND the
        -- matching method (TapArea → :onTapArea). If onTapArea were
        -- missing, taps would silently fail.
        for _, t in ipairs(tappables) do
            assert.is_function(t.onTapArea)
        end
    end)

    it("no cell uses the broken handler= antipattern", function()
        local widget = Bottombar.render(1116, function() end)

        -- Walk the entire widget tree and ensure no ges_events entry
        -- contains a `handler` key (that's the v1.0 lock-up pattern).
        local function check(w)
            if w.ges_events then
                for _, gsseq in pairs(w.ges_events) do
                    -- gsseq is { GestureRange, optionally event = "...", args = ... }
                    -- It must NOT have a `handler` field — KOReader ignores
                    -- that and the cell becomes silently dead.
                    assert.is_nil(gsseq.handler,
                        "found handler= antipattern in ges_events; "
                        .. "use method-name dispatch instead")
                end
            end
            for i = 1, #w do
                if type(w[i]) == "table" then check(w[i]) end
            end
        end
        check(widget)
    end)
end)
