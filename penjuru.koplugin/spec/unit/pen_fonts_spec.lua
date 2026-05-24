require("commonrequire")  -- koreader test bootstrap

describe("pen_fonts", function()
    local Fonts
    setup(function()
        -- Add plugin dir to package.path so bare require("pen_fonts") works.
        -- The plugin is symlinked into the emulator at plugins/penjuru.koplugin/
        local plugin_dir = require("lfs").currentdir() .. "/plugins/penjuru.koplugin"
        package.path = plugin_dir .. "/?.lua;" .. package.path
        Fonts = require("pen_fonts")
    end)

    it("returns a face for the headline role", function()
        local face = Fonts:get("headline", 48)
        assert.is_not_nil(face)
        assert.is_not_nil(face.ftsize)  -- koreader Face objects expose ftsize
    end)

    it("returns a face for the body role", function()
        local face = Fonts:get("body", 22)
        assert.is_not_nil(face)
    end)

    it("returns a face for the numerals role", function()
        local face = Fonts:get("numerals", 32)
        assert.is_not_nil(face)
    end)

    it("caches faces by (role, size)", function()
        local a = Fonts:get("body", 22)
        local b = Fonts:get("body", 22)
        assert.equals(a, b)
    end)

    it("errors loudly on unknown role", function()
        assert.has_error(function() Fonts:get("nonexistent", 14) end)
    end)
end)
