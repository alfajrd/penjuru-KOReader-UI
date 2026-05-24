-- penjuru/pen_status
-- Reads device state for the top status bar. Each accessor returns the
-- short label string the bar will render. Robust to missing subsystems —
-- if KOReader can't report something (e.g. no battery on desktop emulator),
-- returns "--%" / empty / nil and the bar omits or shows a placeholder.

local M = {}

function M.clock()
    return os.date("%H:%M")
end

function M.battery_pct()
    local ok, Device = pcall(require, "device")
    if not ok or not Device then return nil end
    local p = Device:getPowerDevice()
    if not p or not p.capacity then return nil end
    local ok2, pct = pcall(p.capacity, p)
    if not ok2 then return nil end
    return pct
end

function M.battery_label()
    local p = M.battery_pct()
    if not p then return "--%" end
    return string.format("%d%%", p)
end

function M.wifi_label()
    local ok, NetworkMgr = pcall(require, "ui/network/manager")
    if not ok or not NetworkMgr then return "wi-fi" end
    local ok2, on = pcall(NetworkMgr.isWifiOn, NetworkMgr)
    if ok2 and on then return "wi-fi" end
    return "wi-fi off"
end

function M.frontlight_label()
    local ok, Device = pcall(require, "device")
    if not ok or not Device then return nil end
    local ok2, has = pcall(Device.hasFrontlight, Device)
    if not ok2 or not has then return nil end
    local fl = Device:getPowerDevice()
    if not fl or not fl.frontlight_intensity then return nil end
    return string.format("light %d", fl.frontlight_intensity)
end

function M.disk_label()
    -- Free space on the settings volume. macOS emulator: ~/Developer/koreader.
    local ok, DataStorage = pcall(require, "datastorage")
    if not ok then return "" end
    local path = DataStorage:getSettingsDir()
    local ok2, util = pcall(require, "util")
    if not ok2 or not util or not util.getFilesystemInfo then
        return ""  -- older KOReader; skip
    end
    local ok3, info = pcall(util.getFilesystemInfo, path)
    if not ok3 or not info or not info.free then return "" end
    local gb = info.free / (1024 * 1024 * 1024)
    if gb >= 10 then return string.format("%d gb", math.floor(gb)) end
    return string.format("%.1f gb", gb)
end

return M
