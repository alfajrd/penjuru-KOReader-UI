local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") .. "../../"
package.path = plugin_dir .. "?.lua;" .. package.path

require("commonrequire")

describe("pen_tabs", function()
    local Tabs
    setup(function() Tabs = require("pen_tabs") end)

    describe("default_pages", function()
        it("returns 2 pages", function()
            local pages = Tabs.default_pages()
            assert.equals(2, #pages)
        end)

        it("each page has exactly 5 tabs", function()
            local pages = Tabs.default_pages()
            assert.equals(5, #pages[1])
            assert.equals(5, #pages[2])
        end)

        it("page 1 has tabs in the spec'd order", function()
            local p1 = Tabs.default_pages()[1]
            assert.equals("manga", p1[1].id)
            assert.equals("books", p1[2].id)
            assert.equals("home", p1[3].id)
            assert.equals("wifi", p1[4].id)
            assert.equals("games", p1[5].id)
        end)

        it("page 2 has utilities", function()
            -- v1.2.14.9: slot 1 swapped from "stats" to "usb" (mass-storage).
            local p2 = Tabs.default_pages()[2]
            assert.equals("usb", p2[1].id)
            assert.equals("brightness", p2[2].id)
            assert.equals("power", p2[3].id)
            assert.equals("search", p2[4].id)
            assert.equals("library", p2[5].id)
        end)

        it("every tab has id, label, icon fields", function()
            local pages = Tabs.default_pages()
            for _, page in ipairs(pages) do
                for _, tab in ipairs(page) do
                    assert.is_string(tab.id)
                    assert.is_string(tab.label)
                    assert.is_string(tab.icon)
                end
            end
        end)
    end)

    describe("clamp_page", function()
        it("returns 1 when input is below range", function()
            assert.equals(1, Tabs.clamp_page(0, 2))
            assert.equals(1, Tabs.clamp_page(-5, 2))
        end)
        it("returns n when input is above range", function()
            assert.equals(2, Tabs.clamp_page(99, 2))
        end)
        it("returns input when in range", function()
            assert.equals(1, Tabs.clamp_page(1, 2))
            assert.equals(2, Tabs.clamp_page(2, 2))
        end)
    end)
end)
