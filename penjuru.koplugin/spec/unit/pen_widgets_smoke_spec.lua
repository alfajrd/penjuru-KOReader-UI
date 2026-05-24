require("commonrequire")

describe("pen_widgets loads", function()
    setup(function()
        local plugin_dir = require("lfs").currentdir() .. "/plugins/penjuru.koplugin"
        package.path = plugin_dir .. "/?.lua;" .. package.path
    end)

    it("requires without error", function()
        assert.is_table(require("pen_widgets"))
    end)
end)
