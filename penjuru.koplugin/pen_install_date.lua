-- penjuru/pen_install_date
-- Tracks when penjuru was first activated so the dateline can show
-- vol = years since install + 1, no = days since install + 1.

local M = {}

-- Pure helper: compute vol/no for any install and now timestamps.
function M.vol_and_no_for(install_ts, now_ts)
    if not install_ts then return { vol = 1, no = 1 } end
    local days = math.floor((now_ts - install_ts) / 86400)
    if days < 0 then days = 0 end
    return {
        vol = math.floor(days / 365) + 1,
        no  = (days % 365) + 1,
    }
end

local ROMAN = {
    { 10, "x" }, { 9, "ix" }, { 5, "v" }, { 4, "iv" }, { 1, "i" }
}
function M.roman(n)
    local s = ""
    for _, pair in ipairs(ROMAN) do
        while n >= pair[1] do
            s = s .. pair[2]
            n = n - pair[1]
        end
    end
    return s
end

-- get_install_ts(settings, now_ts) -> number
-- Reads or initializes the install timestamp in the provided settings
-- (typically KOReader's G_reader_settings). On first call, persists
-- now_ts as the install date. Returns the stored timestamp.
function M.get_install_ts(settings, now_ts)
    if not settings then return now_ts end
    local s = settings:readSetting("penjuru") or {}
    if not s.install_date then
        s.install_date = now_ts
        settings:saveSetting("penjuru", s)
    end
    return s.install_date
end

return M
