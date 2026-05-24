-- penjuru/pen_tabs
-- Tab descriptor catalog, default page layout, pagination helpers.
-- A tab descriptor is pure data:
--   { id, label, icon, action }
-- where `action` is either a string action id understood by pen_actions,
-- or a table { type = "folder"|"kual"|"plugin", target = "..." } for
-- parameterized actions.

local M = {}

local DEFAULT_TABS = {
    home       = { id="home",       label="home",       icon="tab-home",       action="home" },
    library    = { id="library",    label="library",    icon="tab-library",    action="library" },
    wifi       = { id="wifi",       label="wi-fi",      icon="tab-wifi",       action="wifi_toggle" },
    brightness = { id="brightness", label="brightness", icon="tab-brightness", action="brightness" },
    power      = { id="power",      label="power",      icon="tab-power",      action="power_menu" },
    search     = { id="search",     label="search",     icon="tab-search",     action="search" },
    stats      = { id="stats",      label="stats",      icon="tab-stats",      action="stats" },
    -- Folder shortcuts and KUAL: need target paths; defaults below match
    -- a typical Kindle install. User can override via settings (Plan D).
    manga      = { id="manga", label="manga", icon="tab-manga",
                   action = { type="folder", target="/mnt/us/koreader/mangas" } },
    books      = { id="books", label="books", icon="tab-books",
                   action = { type="folder", target="/mnt/us/koreader/books" } },
    games      = { id="games", label="games", icon="tab-games",
                   action = { type="kual" } },
}
M.catalog = DEFAULT_TABS

function M.default_pages()
    return {
        { DEFAULT_TABS.manga, DEFAULT_TABS.books, DEFAULT_TABS.home, DEFAULT_TABS.wifi, DEFAULT_TABS.games },
        { DEFAULT_TABS.stats, DEFAULT_TABS.brightness, DEFAULT_TABS.power, DEFAULT_TABS.search, DEFAULT_TABS.library },
    }
end

-- user_pages() -> array of pages
-- Reads from G_reader_settings.penjuru.bottombar.pages; defaults if absent.
function M.user_pages()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    local stored = s.bottombar and s.bottombar.pages
    if stored and #stored > 0 then return stored end
    return M.default_pages()
end

function M.clamp_page(n, total)
    if n < 1 then return 1 end
    if n > total then return total end
    return n
end

return M
