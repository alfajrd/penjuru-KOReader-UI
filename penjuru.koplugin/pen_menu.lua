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
                    text_func = function()
                        local s = read_settings()
                        return _("Annual reading goal: ") .. tostring(s.year_goal or 40)
                    end,
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        local SpinWidget = require("ui/widget/spinwidget")
                        local UIManager = require("ui/uimanager")
                        local s = read_settings()
                        UIManager:show(SpinWidget:new{
                            title_text = _("Annual reading goal"),
                            value = s.year_goal or 40,
                            value_min = 1, value_max = 500, value_step = 1, value_hold_step = 10,
                            ok_text = _("Set"),
                            callback = function(spin)
                                local cur = G_reader_settings:readSetting("penjuru") or {}
                                cur.year_goal = spin.value
                                write_settings(cur)
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end,
                        })
                    end,
                },
                {
                    text_func = function()
                        local s = read_settings()
                        local a = s.almanac or {}
                        return _("Location: lat ") .. string.format("%.4f", a.lat or -6.2088)
                            .. ", lon " .. string.format("%.4f", a.lon or 106.8456)
                            .. " (tz " .. tostring(a.tz or 7) .. ")"
                    end,
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        local InputDialog = require("ui/widget/inputdialog")
                        local UIManager = require("ui/uimanager")
                        local s = read_settings()
                        local a = s.almanac or {}
                        local dlg
                        dlg = InputDialog:new{
                            title = _("Location for sunrise / moon"),
                            input_hint = "lat,lon,tz   (e.g. -6.2088,106.8456,7)",
                            input = string.format("%.4f,%.4f,%d", a.lat or -6.2088, a.lon or 106.8456, a.tz or 7),
                            buttons = {
                                {
                                    {
                                        text = _("Cancel"),
                                        id = "close",
                                        callback = function() UIManager:close(dlg) end,
                                    },
                                    {
                                        text = _("Save"),
                                        is_enter_default = true,
                                        callback = function()
                                            local txt = dlg:getInputText()
                                            local lat, lon, tz = txt:match("(%-?[%d%.]+),(%-?[%d%.]+),(%-?%d+)")
                                            if lat and lon and tz then
                                                local cur = G_reader_settings:readSetting("penjuru") or {}
                                                cur.almanac = cur.almanac or {}
                                                cur.almanac.lat = tonumber(lat)
                                                cur.almanac.lon = tonumber(lon)
                                                cur.almanac.tz = tonumber(tz)
                                                write_settings(cur)
                                                if touchmenu_instance then touchmenu_instance:updateItems() end
                                            end
                                            UIManager:close(dlg)
                                        end,
                                    },
                                },
                            },
                        }
                        UIManager:show(dlg)
                        dlg:onShowKeyboard()
                    end,
                },
                {
                    text_func = function()
                        local s = read_settings()
                        return _("Newly threshold: ") .. tostring((s.newly and s.newly.threshold_days) or 30) .. _(" days")
                    end,
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        local SpinWidget = require("ui/widget/spinwidget")
                        local UIManager = require("ui/uimanager")
                        local s = read_settings()
                        local cur_val = (s.newly and s.newly.threshold_days) or 30
                        UIManager:show(SpinWidget:new{
                            title_text = _("Newly catalogued threshold (days)"),
                            value = cur_val,
                            value_min = 1, value_max = 365, value_step = 1, value_hold_step = 7,
                            ok_text = _("Set"),
                            callback = function(spin)
                                local cur = G_reader_settings:readSetting("penjuru") or {}
                                cur.newly = cur.newly or {}
                                cur.newly.threshold_days = spin.value
                                write_settings(cur)
                                if touchmenu_instance then touchmenu_instance:updateItems() end
                            end,
                        })
                    end,
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
