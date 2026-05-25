-- penjuru/pen_settings_defaults
-- Single source of truth for default settings values. Modules call .all()
-- to get the full default table; pen_menu's read_settings uses it as the
-- __index metatable so any unset key falls through to the default.

local M = {}

local function defaults()
    return {
        home = {
            modules_visible = {
                currently = true, ledger = true, almanac = true,
                desk = true, catalogued = true, highlights = true,
            },
        },
        year_goal = 40,
        almanac = {
            lat = -7.7167,   -- Sleman (Yogyakarta region, Indonesia)
            lon = 110.3500,
            tz = 7,
        },
        newly = {
            threshold_days = 30,
            dirs = {},  -- empty means use module_catalogued's bundled default
        },
        topbar = {
            layout = {
                -- v1.2.13: light intentionally omitted per user spec.
                -- v1.2.13.2: "exit" pill appended on the right; tapping
                -- it calls UIManager:quit() to leave KOReader cleanly.
                left = { "clock", "wifi" },
                right = { "disk", "battery", "exit" },
            },
        },
        bottombar = {
            -- pages defaults to pen_tabs.default_pages() if absent
        },
        -- install_date is lazy-initialized by pen_install_date on first call
    }
end

function M.all() return defaults() end

return M
