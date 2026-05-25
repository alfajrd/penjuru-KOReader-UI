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
    -- v1.2.13.4: public API is :getCapacity(), not .capacity. The old
    -- p.capacity field doesn't exist on Kindle's PowerD, so the call
    -- silently returned nil and the topbar rendered "--%".
    if not p or not p.getCapacity then return nil end
    local ok2, pct = pcall(p.getCapacity, p)
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
    -- v1.2.13.4: util.getFilesystemInfo doesn't exist in KOReader. The
    -- right call is util.diskUsage(path) → table with .available,
    -- .used, .total (in bytes). Same function the calibre plugin uses
    -- for free-space checks.
    local ok, DataStorage = pcall(require, "datastorage")
    if not ok then return "" end
    local path = DataStorage:getDataDir()
    local ok2, util = pcall(require, "util")
    if not ok2 or not util or not util.diskUsage then
        return ""
    end
    local ok3, info = pcall(util.diskUsage, path)
    if not ok3 or not info or not info.available then return "" end
    local gb = tonumber(info.available) / (1024 * 1024 * 1024)
    if gb >= 10 then return string.format("%d gb", math.floor(gb)) end
    return string.format("%.1f gb", gb)
end

return M
