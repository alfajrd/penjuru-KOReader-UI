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
    -- v1.2.14.9: kindle USB mass-storage toggle, lives in slot 1 of page 2.
    usb        = { id="usb",        label="usb",        icon="tab-usb",        action="usbms" },
    -- Folder shortcuts and KUAL: need target paths; defaults match the
    -- typical Kindle layout (books and manga at /mnt/us/ root, not under
    -- /mnt/us/koreader/). Users can override via settings; v1.1 will add a
    -- first-run onboarding flow to detect/pick these paths.
    manga      = { id="manga", label="mangas", icon="tab-manga",
                   action = { type="folder", target="/mnt/us/mangas" } },
    books      = { id="books", label="books", icon="tab-books",
                   action = { type="folder", target="/mnt/us/books" } },
    -- v1.2.14.10: games now opens the gnomegames KUAL extension folder
    -- (where the user keeps emulator/game launchers). Was a non-functional
    -- type="kual" placeholder that just showed an InfoMessage.
    games      = { id="games", label="games", icon="tab-games",
                   action = { type="folder", target="/mnt/us/extensions/gnomegames" } },
}
M.catalog = DEFAULT_TABS

function M.default_pages()
    -- v1.2.14.9: page-2 slot 1 swapped from `stats` to `usb` per user. The
    -- stats descriptor is still in the catalog so a settings-driven page
    -- editor (v1.1 onboarding) can restore it without a code change.
    return {
        { DEFAULT_TABS.manga, DEFAULT_TABS.books, DEFAULT_TABS.home, DEFAULT_TABS.wifi, DEFAULT_TABS.games },
        { DEFAULT_TABS.usb,   DEFAULT_TABS.brightness, DEFAULT_TABS.power, DEFAULT_TABS.search, DEFAULT_TABS.library },
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
