-- penjuru/pen_menu
-- Registers the Menu → Tools → penjuru sub-tree. Phase 1 of Plan D
-- expands this into a real settings UI; D.0.2 ships with stubs.

local _ = require("gettext")
local Defaults = require("pen_settings_defaults")

local M = {}

local function read_settings()
    if not rawget(_G, "G_reader_settings") then return Defaults.all() end
    local s = G_reader_settings:readSetting("penjuru") or {}
    return setmetatable(s, { __index = Defaults.all() })
end

local function write_settings(s)
    if rawget(_G, "G_reader_settings") then
        G_reader_settings:saveSetting("penjuru", s)
    end
end
M._read_settings = read_settings
M._write_settings = write_settings

-- get_menu_items() -> array
-- Called by main.lua during plugin init to register under Tools → penjuru.
function M.get_menu_items()
    return {
        {
            text = _("Open home"),
            callback = function()
                local Home = require("pen_homescreen")
                if Home.refresh then pcall(Home.refresh) end
                if Home.show then pcall(Home.show) end
            end,
        },
        {
            text = _("Settings"),
            sub_item_table = {
                {
                    text = _("(settings coming in D.1.1)"),
                    callback = function() end,
                },
            },
        },
        {
            text = _("About penjuru"),
            keep_menu_open = true,
            callback = function()
                local InfoMessage = require("ui/widget/infomessage")
                local UIManager = require("ui/uimanager")
                local ok, meta = pcall(require, "_meta")
                local version = (ok and meta and meta.version) or "?"
                local author = (ok and meta and meta.author) or "?"
                UIManager:show(InfoMessage:new{
                    text = "penjuru " .. version ..
                           "\nby " .. author ..
                           "\n\nforked from doctorhetfield-cmd/simpleui.koplugin\n" ..
                           "https://github.com/alfajrd/penjuru-KOReader-UI",
                    timeout = 6,
                })
            end,
        },
    }
end

return M
