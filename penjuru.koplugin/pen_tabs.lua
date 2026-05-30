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
    -- v1.2.14.16: REMOVED from default_pages entirely. The exec-launch
    -- path bricked the Kindle twice (v1.2.14.13, v1.2.14.15). Even with
    -- a trap + timeout, something about SIGSTOPping awesome/cvm from a
    -- detached subshell after koreader.sh's own SIGCONTs leaves the
    -- device unrecoverable. The descriptor stays in the catalog so a
    -- future safer launcher (e.g. a custom KUAL bridge extension) can
    -- restore it without code changes — but it does NOT appear on any
    -- visible page.
    games      = { id="games", label="games", icon="tab-games",
                   action = { type="exec", target="/mnt/us/extensions/gnomegames/shortcut_gnomine.sh" } },
}
M.catalog = DEFAULT_TABS

function M.default_pages()
    -- v1.2.14.17: `library` promoted from page-2 slot 5 to page-1 slot 5
    -- so page 1 is back to 5 content tabs (mangas / books / home / wifi /
    -- library — the "browsing & finding books" cluster). Page 2 is now
    -- 4 content tabs (stats / brightness / power / search — the
    -- "utility" cluster).
    return {
        { DEFAULT_TABS.manga, DEFAULT_TABS.books, DEFAULT_TABS.home, DEFAULT_TABS.wifi, DEFAULT_TABS.library },
        { DEFAULT_TABS.stats, DEFAULT_TABS.brightness, DEFAULT_TABS.power, DEFAULT_TABS.search },
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
