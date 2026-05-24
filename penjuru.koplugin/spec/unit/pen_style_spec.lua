require("commonrequire")

describe("pen_style", function()
    local Style
    setup(function()
        -- Add plugin dir to package.path so bare require("pen_style") works.
        -- The plugin is symlinked into the emulator at plugins/penjuru.koplugin/
        local plugin_dir = require("lfs").currentdir() .. "/plugins/penjuru.koplugin"
        package.path = plugin_dir .. "/?.lua;" .. package.path
        Style = require("pen_style")
    end)

    it("exposes color tokens", function()
        assert.is_not_nil(Style.colors.paper)
        assert.is_not_nil(Style.colors.ink)
        assert.is_not_nil(Style.colors.rule)
    end)

    it("exposes font factories that return faces", function()
        assert.is_not_nil(Style.fonts.headline(48))
        assert.is_not_nil(Style.fonts.body(22))
        assert.is_not_nil(Style.fonts.numerals(32))
    end)

    it("exposes a complete size table covering home-screen roles", function()
        local required = {
            "masthead_name", "masthead_tagline", "dateline", "section_head",
            "headline", "body", "byline", "pull", "pull_dropcap", "caption",
            "stat_label", "stat_value", "almanac_value", "cat_title",
            "cat_author", "cat_age", "highlight_q", "highlight_src",
            "nav_label", "nav_meta", "top_bar",
        }
        for _, key in ipairs(required) do
            assert.is_number(Style.size[key], "size." .. key .. " must be a number")
        end
    end)

    it("exposes rule weights", function()
        for _, key in ipairs({"major", "minor", "soft", "masthead", "section", "nav_top", "active"}) do
            assert.is_number(Style.rules[key])
        end
    end)
end)
