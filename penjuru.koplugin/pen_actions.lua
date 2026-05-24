-- penjuru/pen_actions
-- Maps tab actions to KOReader UI calls. Each handler returns true on
-- success, false on no-op or failure. Failures logged via KOReader's
-- logger; the bottombar caller doesn't act on the return value beyond
-- a possible toast.

local UIManager = require("ui/uimanager")
local logger = require("logger")

local M = {}

-- Lazy-loaded built-in handlers keyed by action id.
local HANDLERS = {}

HANDLERS.home = function()
    local ok, Home = pcall(require, "pen_homescreen")
    if not ok or not Home then return false end
    if Home.refresh then pcall(Home.refresh) end
    if Home.show then pcall(Home.show) end
    return true
end

HANDLERS.library = function()
    local ok, FM = pcall(require, "apps/filemanager/filemanager")
    if not ok or not FM then return false end
    if FM.instance then
        local ok2 = pcall(FM.instance.setupLayout, FM.instance)
        return ok2
    end
    return false
end

HANDLERS.wifi_toggle = function()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok or not NetworkMgr then return false end
    local on_ok, is_on = pcall(NetworkMgr.isWifiOn, NetworkMgr)
    if on_ok and is_on then
        pcall(NetworkMgr.turnOffWifi, NetworkMgr)
    else
        pcall(NetworkMgr.turnOnWifi, NetworkMgr)
    end
    return true
end

HANDLERS.brightness = function()
    local ok, Device = pcall(require, "device")
    if not ok or not Device then return false end
    local ok2, has = pcall(Device.hasFrontlight, Device)
    if not ok2 or not has then return false end
    local ok3, FL = pcall(require, "ui/widget/frontlightwidget")
    if not ok3 or not FL then return false end
    UIManager:show(FL:new{})
    return true
end

HANDLERS.power_menu = function()
    local ok, ConfirmBox = pcall(require, "ui/widget/confirmbox")
    if not ok or not ConfirmBox then return false end
    UIManager:show(ConfirmBox:new{
        text = "exit koreader?",
        ok_callback = function() UIManager:quit() end,
    })
    return true
end

HANDLERS.search = function()
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{
        text = "search — open library then tap the search icon",
        timeout = 2,
    })
    return true
end

HANDLERS.stats = function()
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{
        text = "stats — wire to ReadingStatistics in plan d",
        timeout = 2,
    })
    return true
end

local function dispatch_folder(target)
    if not target or target == "" then return false end
    local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok_lfs then return false end
    if not lfs.attributes(target) then
        local InfoMessage = require("ui/widget/infomessage")
        UIManager:show(InfoMessage:new{
            text = "folder not found: " .. target,
            timeout = 3,
        })
        return false
    end
    local ok, FM = pcall(require, "apps/filemanager/filemanager")
    if not ok or not FM then return false end
    if FM.instance and FM.instance.file_chooser then
        pcall(FM.instance.file_chooser.changeToPath, FM.instance.file_chooser, target)
        return true
    end
    return false
end

local function dispatch_kual()
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{
        text = "kual launcher — kindle-only",
        timeout = 2,
    })
    return true
end

local function dispatch_plugin(target)
    if not target then return false end
    local ok, plugin = pcall(require, target)
    if not ok or not plugin then return false end
    if plugin.show then pcall(plugin.show) end
    return true
end

-- dispatch(tab) -> bool
function M.dispatch(tab)
    if not tab then return false end
    local action = tab.action
    if type(action) == "string" then
        local h = HANDLERS[action]
        if not h then
            logger.warn("pen_actions: no handler for action", action)
            return false
        end
        local ok, result = pcall(h)
        if not ok then
            logger.warn("pen_actions: handler errored for", action, result)
            return false
        end
        return result and true or false
    end
    if type(action) == "table" then
        if action.type == "folder" then return dispatch_folder(action.target) end
        if action.type == "kual" then return dispatch_kual() end
        if action.type == "plugin" then return dispatch_plugin(action.target) end
    end
    return false
end

return M
