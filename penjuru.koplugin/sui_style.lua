-- sui_style.lua — SimpleUI  ▸  Style  ▸  Icons  ▸  System Icons
--
-- Manages custom icon overrides for:
--   • KOReader FM menu tabs (appbar.filebrowser / settings / tools / search / menu)
--   • FM titlebar home button  (KO built-in "home" icon)
--   • SimpleUI menu button     (ko_menu  — the right titlebar button)
--   • SimpleUI search button   (ko_search — injected search button)
--   • SimpleUI injected menu   (sub_menu  — injected menu in widgets)
--
-- How it works
-- ────────────
-- Icons are stored as full SVG/PNG paths in SUISettings under the key
-- "simpleui_sysicon_<slot_id>".  nil means "use the default".
--
-- For FM tab icons: we patch FileManagerMenu.setUpdateItemTable so that every
-- time the menu is rebuilt the tab icons are replaced with the user's choices.
-- The patch is installed by installTabIconPatch() and removed on teardown.
--
-- For titlebar / search / back icons: sui_titlebar.apply() calls
-- SUIStyle.getIcon(slot_id) when it assigns image.file to each button, and
-- sui_titlebar.lua is modified to call the overrides.  This file therefore
-- also exposes helper methods
-- that sui_titlebar.lua invokes after building each button so the icons can be
-- swapped without duplicating the button-construction logic.
--
-- Public API
-- ──────────
--   SUIStyle.SLOTS            — ordered list of slot descriptors
--   SUIStyle.getIcon(id)      — stored path or nil
--   SUIStyle.setIcon(id, path)— save (nil = reset to default)
--   SUIStyle.resetAll()       — clear every override
--   SUIStyle.applyTabIcons(fm)— push overrides into live tab_item_table
--   SUIStyle.installTabIconPatch(plugin) — persistent FM-menu patch
--   SUIStyle.removeTabIconPatch()        — undo persistent patch
--   SUIStyle.makeMenuItems(plugin)       — returns sub_item_table for the menu
--   SUIStyle.applyIconToBtn(id, btn)     — overwrite image.file on a live button
--                                          (called by sui_titlebar.lua)
--   SUIStyle.applyPaginationIcons(widget) — apply pg_icons overrides to a live
--                                          Menu/FileChooser widget's chevron btns
--   SUIStyle.applyCollBackIcon(widget)   — apply coll_back override to the
--                                          page_return_arrow of a collections widget
--
-- Theme Colors API
-- ──────────────
--   SUIStyle.getThemeColor(role)         — Blitbuffer color for "bg"|"fg", or nil
--   SUIStyle.setThemeColor(role, hex)    — save "#RRGGBB" or nil to reset
--   SUIStyle.resetTheme()               — clear all theme color overrides
--   SUIStyle.makeThemeMenuItems()        — returns sub_item_table for Style ▸ Theme Colors

local SUISettings = require("sui_store")
local logger      = require("logger")
local _           = require("sui_i18n").translate
local Blitbuffer  = require("ffi/blitbuffer")

-- ---------------------------------------------------------------------------
-- Slot catalogue
-- ---------------------------------------------------------------------------
-- Each slot describes one configurable icon position.
--   id          key suffix for SUISettings ("simpleui_sysicon_<id>")
--   label       display name shown in the picker menu
--   group       "sui_titlebar" | "bm_icons"
--   default_ko  KOReader built-in name (used only as documentation / preview)
-- ---------------------------------------------------------------------------

local M = {}

M.SLOTS = {
    -- ── SimpleUI titlebar buttons ────────────────────────────────────────
    {
        id        = "sui_menu",
        label     = function() return _("Menu Button") end,
        group     = "sui_titlebar",
        default_ko = "appbar.menu",
    },
    {
        id        = "sui_search",
        label     = function() return _("Search Button") end,
        group     = "sui_titlebar",
        default_ko = "appbar.search",
    },
    {
        id        = "sui_back",
        label     = function() return _("Back Button") end,
        group     = "sui_titlebar",
        default_ko = "appbar.menu",   -- hamburger is the default inj_back icon
    },
    -- ── Browse Meta titlebar icons ───────────────────────────────────────
    -- These override the four icons used by the Browse button in the FM
    -- titlebar (normal/author/series/tags mode).
    {
        id        = "sui_browse_normal",
        label     = function() return _("Browse Button (default)") end,
        group     = "sui_browse_icons",
        default_ko = "icons/default.svg",
    },
    {
        id        = "sui_browse_author",
        label     = function() return _("Browse Button (author)") end,
        group     = "sui_browse_icons",
        default_ko = "icons/author.svg",
    },
    {
        id        = "sui_browse_series",
        label     = function() return _("Browse Button (series)") end,
        group     = "sui_browse_icons",
        default_ko = "icons/series.svg",
    },
    {
        id        = "sui_browse_tags",
        label     = function() return _("Browse Button (tags)") end,
        group     = "sui_browse_icons",
        default_ko = "icons/tags.svg",
    },
    -- ── Native pagination bar chevrons ───────────────────────────────────
    -- Override the four chevron Buttons in KOReader's native pagination row
    -- (page_info_{left,right,first,last}_chev).  Applied after every
    -- Menu:init / FileChooser:init via M.applyPaginationIcons().
    {
        id        = "sui_pager_prev",
        label     = function() return _("Pagination: Previous Page") end,
        group     = "sui_pager_icons",
        default_ko = "chevron.left",
    },
    {
        id        = "sui_pager_next",
        label     = function() return _("Pagination: Next Page") end,
        group     = "sui_pager_icons",
        default_ko = "chevron.right",
    },
    {
        id        = "sui_pager_first",
        label     = function() return _("Pagination: First Page") end,
        group     = "sui_pager_icons",
        default_ko = "chevron.first",
    },
    {
        id        = "sui_pager_last",
        label     = function() return _("Pagination: Last Page") end,
        group     = "sui_pager_icons",
        default_ko = "chevron.last",
    },
    -- ── Navpager arrows (bottom bar) ─────────────────────────────────────
    {
        id        = "sui_navpager_prev",
        label     = function() return _("Navpager: Previous") end,
        group     = "sui_navpager_icons",
        default_ko = "chevron.left",
    },
    {
        id        = "sui_navpager_next",
        label     = function() return _("Navpager: Next") end,
        group     = "sui_navpager_icons",
        default_ko = "chevron.right",
    },
    -- ── Collections back button ──────────────────────────────────────────
    -- Overrides the page_return_arrow ("appbar.back") in Collections /
    -- coll_list widgets.  Applied after Menu:init via M.applyCollBackIcon().
    {
        id        = "sui_coll_back",
        label     = function() return _("Collections: Back Button") end,
        group     = "sui_coll_icons",
        default_ko = "appbar.back",
    },
    -- ── Quick Actions Defaults ───────────────────────────────────────────
    {
        id        = "sui_qa_folder",
        label     = function() return _("Default: Folder") end,
        group     = "sui_qa_defaults",
        default_ko = "icons/custom.svg",
    },
    {
        id        = "sui_qa_plugin",
        label     = function() return _("Default: Plugin") end,
        group     = "sui_qa_defaults",
        default_ko = "icons/plugin.svg",
    },
    {
        id        = "sui_qa_system",
        label     = function() return _("Default: System") end,
        group     = "sui_qa_defaults",
        default_ko = "appbar.settings",
    },
    -- ── Folder Covers ────────────────────────────────────────────────────
    {
        id        = "sui_fc_empty",
        label     = function() return _("Folder Covers: Empty Folder") end,
        group     = "sui_fc_icons",
        default_ko = "icons/custom.svg",
    },
}

-- Quick lookup by id.
local _SLOT_BY_ID = {}
for _, s in ipairs(M.SLOTS) do _SLOT_BY_ID[s.id] = s end

-- ---------------------------------------------------------------------------
-- Settings helpers
-- ---------------------------------------------------------------------------

local function _key(id) return "simpleui_sysicon_" .. id end

--- Returns the stored icon path for `id`, or nil if using the default.
function M.getIcon(id)
    local v = SUISettings:get(_key(id))
    return (type(v) == "string" and v ~= "") and v or nil
end

--- Saves `path` as the icon for `id`.  Pass nil to reset to default.
function M.setIcon(id, path)
    if type(path) == "string" and path ~= "" then
        SUISettings:set(_key(id), path)
    else
        SUISettings:del(_key(id))
    end
end

-- ---------------------------------------------------------------------------
-- Icon path guard
-- ---------------------------------------------------------------------------
-- SUPPORTED_ICON_EXTS: formats that imagewidget.lua can actually load.
-- SVG requires librsvg (available on most KOReader builds).
-- PNG is always safe (liblodepng is always present).
-- JPG/JPEG are supported but not recommended for icons (no transparency).
local _SUPPORTED_ICON_EXTS = { png = true, svg = true, jpg = true, jpeg = true }

--- Validates `path` as a loadable icon file.
--- Returns `path` when valid, `fallback` otherwise.
--- Also clears the stored setting for `slot_id` (when given) so a bad path
--- is not retried on the next startup.
---
--- @param path      string|any   candidate icon path
--- @param fallback  string|nil   path to return when `path` is invalid (nil = no icon)
--- @param slot_id   string|nil   SUISettings key suffix; when given, a bad path
---                               is deleted from settings so it is not retried.
--- @return string|nil
function M.safeIconPath(path, fallback, slot_id)
    -- Type check — nil/non-string means "no override", not an error.
    if type(path) ~= "string" or path == "" then
        return fallback
    end

    -- Extension check — fast, no I/O.
    local ext = path:match("%.([^.]+)$")
    if not ext or not _SUPPORTED_ICON_EXTS[ext:lower()] then
        logger.warn("simpleui/style: unsupported icon format '" .. tostring(ext)
                    .. "' in path: " .. path)
        if slot_id then M.setIcon(slot_id, nil) end
        return fallback
    end

    -- Existence check — requires lfs; skip gracefully when unavailable.
    -- Note: _reqLFS() is defined later in this file (Lua forward-reference
    -- limitation), so we inline the pcall here instead of calling it.
    local lfs_ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if lfs_ok and lfs then
        if lfs.attributes(path, "mode") ~= "file" then
            logger.warn("simpleui/style: icon file not found: " .. path)
            if slot_id then M.setIcon(slot_id, nil) end
            return fallback
        end
    else
        -- lfs unavailable: trust the extension check, warn once.
        logger.warn("simpleui/style: lfs unavailable, skipping existence check for: " .. path)
    end

    return path
end

--- Clears every system icon override.
function M.resetAll()
    for _, s in ipairs(M.SLOTS) do
        if s.group ~= "sui_qa_defaults" then
            SUISettings:del(_key(s.id))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Apply helpers — called by sui_titlebar.lua
-- ---------------------------------------------------------------------------

--- Replaces image.file on a live button widget with the stored override for
--- `id`.  Does nothing when no override is set or the button has no image.
--- Returns true when an override was applied.
function M.applyIconToBtn(id, btn)
    local raw = M.getIcon(id)
    if not raw then return false end
    if not (btn and btn.image) then return false end
    local path = M.safeIconPath(raw, nil, id)
    if not path then return false end
    -- CRITICAL: clear .icon before setting .file.
    -- KOReader ImageWidget:init() gives precedence to .icon over .file.
    -- Buttons created with icon="appbar.search" keep that name in .icon
    -- after :new{}. Without this nil, init() ignores .file and resolves
    -- the old symbolic name -- causing the search icon path to appear on
    -- the up/back button after a reapply cycle.
    btn.image.icon = nil
    btn.image.file = path
    pcall(btn.image.free, btn.image)
    pcall(btn.image.init, btn.image)
    return true
end

-- ---------------------------------------------------------------------------
-- Native Button icon replacement helper
-- ---------------------------------------------------------------------------
-- KOReader has two icon-button widget types with different internal structures:
--
--   • IconButton  → self.image is an IconWidget created in IconButton:init().
--                   We can swap the icon by setting .icon=nil / .file=path on
--                   that ImageWidget and calling :free() + :init().
--
--   • Button{icon=…} → self.label_widget is an IconWidget created inside
--                   Button:init() when self.text is nil.  There is NO self.image
--                   on a plain Button.  The label_widget must be patched the
--                   same way (nil the .icon, set .file) so IconWidget:init()
--                   skips the symbol-lookup branch and loads the file directly.
--                   Setting btn.icon to a file path and re-calling btn:init()
--                   does NOT work: Button:init() creates a fresh IconWidget with
--                   icon=<path> and IconWidget:init() treats that value as a
--                   symbolic name, fails the directory scan, and falls back to
--                   ICON_NOT_FOUND (the warning triangle).
--
-- Strategy:
--   1. If btn.image exists  → it's an IconButton  → patch btn.image directly.
--   2. If btn.label_widget exists → it's a Button → patch btn.label_widget.
--   Both cases: set .icon = nil, .file = path, then :free() + :init().
-- ---------------------------------------------------------------------------

local function _applyNativeBtn(id, btn)
    local raw = M.getIcon(id)
    if not raw then return false end
    if not btn then return false end
    local path = M.safeIconPath(raw, nil, id)
    if not path then return false end

    -- Path 1: IconButton exposes self.image (an IconWidget / ImageWidget).
    if btn.image then
        btn.image.icon = nil
        btn.image.file = path
        pcall(btn.image.free, btn.image)
        pcall(btn.image.init, btn.image)
        return true
    end

    -- Path 2: Plain Button{icon=…} stores its rendered icon in self.label_widget
    -- (an IconWidget built by Button:init() when self.text is nil).
    -- Patch the live label_widget directly: clear .icon so IconWidget:init()
    -- skips the symbol-lookup branch, then set .file to our custom path.
    if btn.label_widget then
        btn.label_widget.icon = nil
        btn.label_widget.file = path
        pcall(btn.label_widget.free, btn.label_widget)
        pcall(btn.label_widget.init, btn.label_widget)
        return true
    end

    return false
end

-- ---------------------------------------------------------------------------
-- Pagination chevron icon application  (pg_icons group)
-- ---------------------------------------------------------------------------

-- Slot-id → button field name on the widget.
local _PG_CHEV_FIELDS = {
    sui_pager_prev  = "page_info_left_chev",
    sui_pager_next  = "page_info_right_chev",
    sui_pager_first = "page_info_first_chev",
    sui_pager_last  = "page_info_last_chev",
}

--- Applies stored pg_icons overrides to the pagination buttons of `widget`.
--- `widget` may be a FileChooser or any Menu instance (Collections, History…).
--- Returns true when at least one override was applied.
function M.applyPaginationIcons(widget)
    if not widget then return false end
    local applied = false
    for id, field in pairs(_PG_CHEV_FIELDS) do
        local btn = widget[field]
        if btn then
            applied = _applyNativeBtn(id, btn) or applied
        end
    end
    return applied
end

-- ---------------------------------------------------------------------------
-- Collections back-button icon application  (coll_icons group)
-- ---------------------------------------------------------------------------

--- Applies the stored coll_back override to the page_return_arrow of `widget`.
--- `widget` should be a collections or coll_list Menu instance.
--- Returns true when an override was applied.
function M.applyCollBackIcon(widget)
    if not widget then return false end
    local btn = widget.page_return_arrow
    if not btn then return false end
    return _applyNativeBtn("sui_coll_back", btn)
end

-- ---------------------------------------------------------------------------
-- FM tab icon application
-- ---------------------------------------------------------------------------

-- Build a tab_key → slot_id map for fast lookup.
local _TAB_KEY_TO_ID = {}
for _, s in ipairs(M.SLOTS) do
    if s.tab_key then _TAB_KEY_TO_ID[s.tab_key] = s.id end
end

--- Iterates the live tab_item_table of a FileManager instance and replaces
--- icons whose slot has a user override.  Also accepts a raw tab_item_table.
function M.applyTabIcons(fm_or_table)
    local tab_table
    if type(fm_or_table) == "table" then
        -- Could be a FM instance or a raw table.
        if fm_or_table.file_manager_menu
           and fm_or_table.file_manager_menu.tab_item_table then
            tab_table = fm_or_table.file_manager_menu.tab_item_table
        elseif fm_or_table[1] and fm_or_table[1].icon ~= nil then
            -- raw tab_item_table passed directly
            tab_table = fm_or_table
        end
    end
    if not tab_table then return end

    for _, tab in ipairs(tab_table) do
        local slot_id = tab.key and _TAB_KEY_TO_ID[tab.key]
        if slot_id then
            local path = M.getIcon(slot_id)
            if path then
                tab.icon = path
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Persistent FM-menu patch
-- ---------------------------------------------------------------------------
-- Wraps FileManagerMenu.setUpdateItemTable so icons survive every menu rebuild.

local _patch_installed = false

function M.installTabIconPatch(plugin)
    if _patch_installed then return end
    local FMMenu = package.loaded["apps/filemanager/filemanagermenu"]
    if not FMMenu then
        local ok, m = pcall(require, "apps/filemanager/filemanagermenu")
        FMMenu = ok and m or nil
    end
    if not FMMenu then return end
    if FMMenu._simpleui_sysicon_patched then return end

    local orig = FMMenu.setUpdateItemTable
    FMMenu._simpleui_sysicon_orig    = orig
    FMMenu._simpleui_sysicon_patched = true
    plugin._sysicon_fmmenu_patched   = true

    FMMenu.setUpdateItemTable = function(fmm_self, ...)
        orig(fmm_self, ...)
        -- After the table is built, replace icons.
        if fmm_self.tab_item_table then
            M.applyTabIcons(fmm_self.tab_item_table)
        end
    end

    _patch_installed = true
    logger.dbg("simpleui/style: FM tab icon patch installed")
end

function M.removeTabIconPatch()
    if not _patch_installed then return end
    local FMMenu = package.loaded["apps/filemanager/filemanagermenu"]
    if FMMenu and FMMenu._simpleui_sysicon_patched then
        FMMenu.setUpdateItemTable           = FMMenu._simpleui_sysicon_orig
        FMMenu._simpleui_sysicon_orig       = nil
        FMMenu._simpleui_sysicon_patched    = nil
    end
    _patch_installed = false
    logger.dbg("simpleui/style: FM tab icon patch removed")
end

-- ---------------------------------------------------------------------------
-- Live FM icon refresh
-- ---------------------------------------------------------------------------
-- Pushes current overrides into the live menu and asks it to redraw.

local function _refreshFMTabBar(fm)
    if not (fm and fm.file_manager_menu) then return end
    local fmm = fm.file_manager_menu
    if fmm.tab_item_table then
        M.applyTabIcons(fmm.tab_item_table)
    end
    -- Tell TouchMenu to repaint if it's open.
    local tm = fmm._menu
    if tm then
        local ok_ui, UIManager = pcall(require, "ui/uimanager")
        if ok_ui then UIManager:setDirty(tm, "ui") end
    end
end

-- ---------------------------------------------------------------------------
-- Menu builder
-- ---------------------------------------------------------------------------

--- Returns the sub_item_table for Style ▸ Icons ▸ System Icons.
function M.makeMenuItems(plugin)
    local QA = require("sui_quickactions")

    -- Helper: get the current FM instance (may be nil).
    local function _fm()
        local FM = package.loaded["apps/filemanager/filemanager"]
        return FM and FM.instance
    end

    -- Helper: reapply titlebar icons to the live FM and all injected widgets.
local function _reapplyTitlebar()
        local ok_tb, TB = pcall(require, "sui_titlebar")
        if not ok_tb or not TB then return end
        
        local fm = _fm()
        local ok_ui, UIManager = pcall(require, "ui/uimanager")
        pcall(TB.reapplyAll, fm, ok_ui and UIManager._window_stack or nil)
    end

    -- Helper: reapply pagination icons on all live fullscreen menus and FM.
    local function _reapplyPaginationIcons()
        local ok_ui, UIManager = pcall(require, "ui/uimanager")
        if not ok_ui then return end
        -- Apply to FM's FileChooser.
        local fm = _fm()
        if fm and fm.file_chooser then
            M.applyPaginationIcons(fm.file_chooser)
        end
        -- Apply to any fullscreen menu currently on the stack (History, etc.).
        for _, entry in ipairs(UIManager._window_stack or {}) do
            local w = entry.widget
            if w and w.page_info_left_chev then
                M.applyPaginationIcons(w)
            end
        end
    end

    -- Helper: reapply collections back icon on live collections widgets.
    local function _reapplyCollBackIcon()
        local ok_ui, UIManager = pcall(require, "ui/uimanager")
        if not ok_ui then return end
        for _, entry in ipairs(UIManager._window_stack or {}) do
            local w = entry.widget
            if w and (w.name == "collections" or w.name == "coll_list") then
                M.applyCollBackIcon(w)
            end
        end
    end

    -- Helper: after a change, reapply everything that is affected.
    local function _refresh(group)
        if group == "sui_titlebar" then
            _reapplyTitlebar()
        elseif group == "pg_icons" then
            _reapplyPaginationIcons()
        elseif group == "coll_icons" then
            _reapplyCollBackIcon()
        elseif group == "sui_navpager_icons" then
            if plugin then plugin:_rebuildAllNavbars() end
        elseif group == "sui_qa_defaults" then
            local ok_qa, QA = pcall(require, "sui_quickactions")
            if ok_qa and QA.invalidateCustomQACache then QA.invalidateCustomQACache() end
            if plugin then plugin:_rebuildAllNavbars() end
            local ok_hs, HS = pcall(require, "sui_homescreen")
            if ok_hs and HS and HS._instance then HS._instance:_refreshImmediate(false) end
        elseif group == "sui_fc_icons" then
            local ok_fc, FC = pcall(require, "sui_foldercovers")
            if ok_fc and FC and FC.invalidateCache then FC.invalidateCache() end
            local fm = _fm()
            if fm and fm.file_chooser then
                fm._navbar_suppress_path_change = true
                fm.file_chooser:refreshPath()
                fm._navbar_suppress_path_change = nil
            end
        end
    end

    -- ── Section heading helper ───────────────────────────────────────────
    local function _sep(label)
        return { text = label, is_title = true }
    end

    -- ── One row per slot ─────────────────────────────────────────────────
    local function _makeRow(slot)
        return {
            text_func = function()
                local path = M.getIcon(slot.id)
                local label = type(slot.label) == "function" and slot.label() or slot.label
                if path then
                    return label .. "  \u{270E}"
                end
                return label
            end,
            keep_menu_open = true,
            callback = function()
                QA.showIconPicker(
                    M.getIcon(slot.id),
                    function(new_path)
                        -- Guard: validate format/existence before persisting.
                        -- nil = "reset to default", always valid.
                        if new_path == nil then
                            M.setIcon(slot.id, nil)
                            _refresh(slot.group)
                            return
                        end
                        local safe = M.safeIconPath(new_path, nil)
                        if safe then
                            M.setIcon(slot.id, safe)
                            _refresh(slot.group)
                        else
                            local _InfoMessage = require("ui/widget/infomessage")
                            UIManager:show(_InfoMessage:new{
                                text    = _("Unsupported icon format.\nPlease use a PNG or SVG file."),
                                timeout = 3,
                            })
                        end
                    end,
                    type(slot.label) == "function" and slot.label() or slot.label,
                    plugin,
                    "_sysicon_picker_" .. slot.id
                )
            end,
        }
    end

    -- ── Group the slots ───────────────────────────────────────────────────
    local items = {}

    -- Reset all item at the top.
    items[#items + 1] = {
        text           = _("Reset All System Icons"),
        keep_menu_open = true,
        callback       = function()
            M.resetAll()
            _reapplyTitlebar()
            -- Refresh browse-mode icons in the live FM titlebar.
            local ok_tb, TB = pcall(require, "sui_titlebar")
            if ok_tb and TB and TB.refreshBrowseIcons then
                TB.refreshBrowseIcons(_fm())
            end
            -- Refresh pagination chevrons and collections back button.
            _reapplyPaginationIcons()
            _reapplyCollBackIcon()

            -- Invalidate Quick Actions & Folder Covers caches
            local ok_qa, QA2 = pcall(require, "sui_quickactions")
            if ok_qa and QA2 and QA2.invalidateCustomQACache then QA2.invalidateCustomQACache() end
            local ok_fc, FC = pcall(require, "sui_foldercovers")
            if ok_fc and FC and FC.invalidateCache then FC.invalidateCache() end
            local fm = _fm()
            if fm and fm.file_chooser then
                fm._navbar_suppress_path_change = true
                fm.file_chooser:refreshPath()
                fm._navbar_suppress_path_change = nil
            end

            if plugin then plugin:_rebuildAllNavbars() end
        end,
        separator      = true,
    }

    -- ── sui_titlebar group ────────────────────────────────────────────────
    for _, slot in ipairs(M.SLOTS) do
        if slot.group == "sui_titlebar" then
            items[#items + 1] = _makeRow(slot)
        end
    end

    -- ── bm_icons group ───────────────────────────────────────────────────
    for _, slot in ipairs(M.SLOTS) do
        if slot.group == "sui_browse_icons" then
            local row = _makeRow(slot)
            -- After changing a browse icon, refresh the live browse button.
            local orig_cb = row.callback
            row.callback = function()
                orig_cb()
                local ok_tb, TB = pcall(require, "sui_titlebar")
                if ok_tb and TB and TB.refreshBrowseIcons then
                    TB.refreshBrowseIcons(_fm())
                end
            end
            items[#items + 1] = row
        end
    end

    -- ── pg_icons group (pagination chevrons) ─────────────────────────────
    for _, slot in ipairs(M.SLOTS) do
        if slot.group == "sui_pager_icons" then
            items[#items + 1] = _makeRow(slot)
        end
    end

    -- ── sui_navpager_icons group (Navpager) ──────────────────────────────
    for _, slot in ipairs(M.SLOTS) do
        if slot.group == "sui_navpager_icons" then
            items[#items + 1] = _makeRow(slot)
        end
    end

    -- ── coll_icons group (collections back) ──────────────────────────────
    for _, slot in ipairs(M.SLOTS) do
        if slot.group == "sui_coll_icons" then
            items[#items + 1] = _makeRow(slot)
        end
    end

    -- ── sui_fc_icons group ───────────────────────────────────────────────
    for _, slot in ipairs(M.SLOTS) do
        if slot.group == "sui_fc_icons" then
            items[#items + 1] = _makeRow(slot)
        end
    end

    return items
end

-- ---------------------------------------------------------------------------
-- UI Font face picker
-- ---------------------------------------------------------------------------
-- Allows the user to replace KOReader's built-in UI font with any font
-- installed on the system.
--
-- Settings keys (all via SUISettings):
--   simpleui_ui_font_name     string   — selected font family name
--   simpleui_ui_font_enabled  bool     — true = custom font active
--
-- The font path is resolved at apply-time via cre.getFontFaceFilenameAndFaceIndex
-- so the setting stores the human-readable family name, not a raw file path.
--
-- Public API:
--   M.applyUIFont()          — restore saved font (called from main.lua init)
--   M.makeFontMenuItems()    — returns sub_item_table for Style ▸ UI Font
-- ---------------------------------------------------------------------------

-- Settings keys
local _FONT_KEY_NAME    = "simpleui_ui_font_name"
local _FONT_KEY_ENABLED = "simpleui_ui_font_enabled"
local _FONT_DEFAULT     = "Noto Sans"

-- Module-level lazy caches — populated once by _initFonts().
local _font_list     = nil   -- ordered list of font family names (strings)
local _fonts         = nil   -- map: family name → { regular=path, bold=path }
local _replaced      = nil   -- map: Font.fontmap slot → "regular"|"bold"

-- ── Lazy module accessors ────────────────────────────────────────────────

local function _reqFont()
    local ok, m = pcall(require, "ui/font"); return ok and m or nil
end
local function _reqFontList()
    local ok, m = pcall(require, "fontlist"); return ok and m or nil
end
local function _reqCRE()
    -- Primary path: via CreDocument:engineInit() which loads and returns the
    -- cre C module.  This works in both the reader and the file manager.
    local ok, m = pcall(function()
        return require("document/credocument"):engineInit()
    end)
    if ok and m then return m end
    -- Fallback: the cre library may already be loaded as a standalone module
    -- (happens in some KOReader builds where it is pre-required).
    local ok2, m2 = pcall(require, "libs/libkoreader-cre")
    return ok2 and m2 or nil
end
local function _reqUIManager()
    local ok, m = pcall(require, "ui/uimanager"); return ok and m or nil
end
local function _reqLFS()
    local ok, m = pcall(require, "libs/libkoreader-lfs"); return ok and m or nil
end
local function _reqDataStorage()
    local ok, m = pcall(require, "datastorage"); return ok and m or nil
end

-- ── Path helpers ─────────────────────────────────────────────────────────

-- Heuristic: try "Font-Regular.ext" → "Font-Bold.ext",
-- then "Font.ext" → "Font-Bold.ext".
local function _boldPath(path_regular)
    if not path_regular then return nil end
    local p, n = path_regular:gsub("%-Regular%.", "-Bold.", 1)
    if n > 0 then return p end
    p, n = path_regular:gsub("(%.)([^.]+)$", "-Bold.%2", 1)
    return n > 0 and p or nil
end

-- ── Font list initialisation ──────────────────────────────────────────────

-- Builds _font_list, _fonts, _replaced.
local function _initFonts()
    local Font     = _reqFont()
    local FontList = _reqFontList()
    local cre      = _reqCRE()
    local lfs      = _reqLFS()
    if not (Font and FontList and cre) then
        _font_list = {}; _fonts = {}; _replaced = {}
        logger.warn("simpleui/style: font modules unavailable, font picker disabled")
        return
    end

    _font_list = {}
    _fonts     = {}
    _replaced  = {}

    -- Build the set of paths that will be accepted as valid font sources.
    local path_set = {}
    for _, p in ipairs(FontList.fontlist) do 
        -- Verify the file still exists on disk, as FontList caches paths across restarts.
        if not lfs or lfs.attributes(p, "mode") == "file" then
            path_set[p] = true 
        end
    end

    -- Walk CRE's font face list and keep only those whose file is in path_set.
    for _, name in ipairs(cre.getFontFaces()) do
        local path_regular = cre.getFontFaceFilenameAndFaceIndex(name)
        if path_regular and path_set[path_regular] then
            local path_bold  = _boldPath(path_regular)
            local bold_ok    = path_set[path_bold]
            table.insert(_font_list, name)
            if bold_ok then
                _fonts[name] = { regular = path_regular, bold = path_bold }
            else
                _fonts[name] = { regular = path_regular, bold = path_regular }
            end
        end
    end

    -- Record which Font.fontmap slots map to the two built-in Noto variants
    -- so we know exactly which entries to overwrite on apply.
    local type_font = {
        ["NotoSans-Regular.ttf"] = "regular",
        ["NotoSans-Bold.ttf"]    = "bold",
    }
    for slot, font_file in pairs(Font.fontmap) do
        local typ = type_font[font_file]
        if typ then _replaced[slot] = typ end
    end

    logger.dbg("simpleui/style: font list built,", #_font_list, "faces")
end

-- Ensures the cache is valid for the current setting value.
-- Wrapped in pcall internally so any unexpected error leaves the caches in a
-- safe (empty) state instead of propagating to the caller.
local function _ensureFonts()
    if _font_list ~= nil then return end
    local ok, err = pcall(_initFonts)
    if not ok then
        logger.warn("simpleui/style: _initFonts error:", err)
        _font_list    = _font_list    or {}
        _fonts        = _fonts        or {}
        _replaced     = _replaced     or {}
    end
end

-- ── Apply ────────────────────────────────────────────────────────────────

-- Refreshes the class-level font face defaults on KOReader's TitleBar widget.
--
-- TitleBar (ui/widget/titlebar.lua) evaluates Font:getFace("smalltfont") etc.
-- at require()-time as default field values in the OverlapGroup:extend{} table.
-- After _applyFont() updates Font.fontmap, those frozen face objects still point
-- to the old NotoSans paths, so every new TitleBar instance inherits the wrong
-- font regardless of the fontmap change.
--
-- Fix: after updating fontmap, call Font:getFace() again for each frozen slot
-- to get a face object bound to the new path, and overwrite the class default.
-- Safe to call even if titlebar.lua was never required (pcall + check).
local function _refreshTitleBarFaces()
    local ok_tb, TitleBar = pcall(require, "ui/widget/titlebar")
    if not ok_tb or not TitleBar then return end
    local Font = _reqFont()
    if not Font then return end
    -- These are the four slots frozen as class-level defaults in TitleBar.
    -- Re-fetching them forces Font to resolve the new fontmap path and cache
    -- a face under the new hash, then we replace the class default.
    local slots = {
        { field = "title_face_fullscreen",     face = "smalltfont"     },
        { field = "title_face_not_fullscreen", face = "x_smalltfont"   },
        { field = "subtitle_face",             face = "xx_smallinfofont"},
        { field = "info_text_face",            face = "x_smallinfofont" },
    }
    for _, s in ipairs(slots) do
        local ok_f, face = pcall(Font.getFace, Font, s.face)
        if ok_f and face then
            TitleBar[s.field] = face
        end
    end
end

-- Writes the chosen font paths into Font.fontmap.
local function _applyFont(name)
    local Font = _reqFont()
    if not Font then return end
    _ensureFonts()
    if not SUISettings:isTrue(_FONT_KEY_ENABLED) then return end
    if not (_fonts and _fonts[name]) then return end
    for slot, typ in pairs(_replaced) do
        Font.fontmap[slot] = _fonts[name][typ]
    end
    logger.dbg("simpleui/style: UI font applied →", name)
    -- Refresh TitleBar class defaults so new instances use the updated font.
    _refreshTitleBarFaces()
end

--- Restore the saved font preference.  Called from main.lua at plugin init.
function M.applyUIFont()
    _ensureFonts()
    if SUISettings:isTrue(_FONT_KEY_ENABLED) then
        local name = SUISettings:get(_FONT_KEY_NAME) or _FONT_DEFAULT
        if _fonts and _fonts[name] then
            _applyFont(name)
        else
            logger.warn("simpleui/style: active UI font not found on disk, disabling custom font:", name)
            SUISettings:set(_FONT_KEY_ENABLED, false)
        end
    end
end

-- ── Menu builder ─────────────────────────────────────────────────────────

--- Returns the sub_item_table for Style ▸ UI Font.
--- Never throws: any internal error is caught and surfaced as a disabled
--- "unavailable" entry so the menu always opens.
function M.makeFontMenuItems()
    local ok_ef, err_ef = pcall(_ensureFonts)
    if not ok_ef then
        logger.warn("simpleui/style: makeFontMenuItems – _ensureFonts error:", err_ef)
        _font_list = _font_list or {}
        _fonts     = _fonts     or {}
        _replaced  = _replaced  or {}
    end
    local Font      = _reqFont()
    local UIManager = _reqUIManager()

    local function _isEnabled()
        return SUISettings:isTrue(_FONT_KEY_ENABLED)
    end
    local function _currentName()
        return SUISettings:get(_FONT_KEY_NAME) or _FONT_DEFAULT
    end

    local items = {}

    -- ── Toggle: enable custom font ────────────────────────────────────────
    items[#items + 1] = {
        text         = _("Enable custom UI font"),
        checked_func = _isEnabled,
        callback     = function()
            local new_val = not _isEnabled()
            SUISettings:set(_FONT_KEY_ENABLED, new_val)
            if new_val then _applyFont(_currentName()) end
            if UIManager then
                UIManager:askForRestart(_("Restart to fully apply the UI font change."))
            end
        end,
    }

    -- ── One entry per available font face ────────────────────────────────
    if #_font_list == 0 then
        items[#items + 1] = {
            text    = _("No fonts found."),
            enabled_func = function() return false end,
            callback     = function() end,
        }
    else
        for _k, name in ipairs(_font_list) do
            local _name = name   -- upvalue capture
            items[#items + 1] = {
                text_func = function()
                    local label = _name
                    if _fonts[_name] and _fonts[_name].regular == _fonts[_name].bold then
                        label = label .. "  (no bold)"
                    end
                    if _isEnabled() and _name == _currentName() then
                        label = "\u{2713}  " .. label
                    end
                    return label
                end,
                -- Render the menu entry in that font face when supported.
                font_func = Font and function(size)
                    local fd = _fonts[_name]
                    if not fd then return nil end
                    return Font:getFace(fd.regular, size)
                end or nil,
                -- Grey-out the currently selected entry.
                enabled_func = function()
                    return not (_isEnabled() and _name == _currentName())
                end,
                keep_menu_open = true,
                callback = function()
                    SUISettings:set(_FONT_KEY_NAME, _name)
                    SUISettings:set(_FONT_KEY_ENABLED, true)
                    _applyFont(_name)
                    if UIManager then
                        UIManager:askForRestart(_("Restart to fully apply the UI font change."))
                    end
                end,
            }
        end
    end

    return items
end

-- ===========================================================================
-- Theme Colors
-- ===========================================================================
-- Granular per-role colour overrides for every SimpleUI surface.
-- All keys use the "simpleui_style_" prefix so that homescreen presets
-- capture them automatically (HS_PREFIXES in sui_presets.lua covers it).
--
-- Color storage
-- ─────────────
-- Hex strings (#RRGGBB) are stored in settings.  At read-time they are
-- converted to Blitbuffer colors via Blitbuffer.colorFromString(), which
-- preserves the full RGB value.  On a greyscale e-ink panel the hardware
-- renders the perceived luminance — the user can therefore enter any HTML
-- color and it will look "right" without us forcing a luma conversion.
--
-- Role catalogue
-- ──────────────
-- "bg"              Homescreen background (also fallback for bars when their
--                   own role is unset).
-- "fg"              Homescreen primary text (also fallback for bar text).
-- "bottombar_bg"    Bottom navigation bar background.
-- "bottombar_fg"    Bottom navigation bar icon / label text.
-- "statusbar_bg"    Top status bar background.
-- "statusbar_fg"    Top status bar text (clock, battery, …).
-- "text_secondary"  Secondary / dim text — inactive nav items, sub-labels,
--                   mid-tone homescreen captions.
-- "separator"       Thin divider line between bars and content.
-- "accent"          Active / highlighted element (active nav item, pager
--                   arrows, etc.).
--
-- Fallback chain (getThemeColor)
-- ───────────────────────────────
-- bottombar_bg  → bg  → nil (caller uses its own default)
-- bottombar_fg  → fg  → nil
-- statusbar_bg  → bg  → nil
-- statusbar_fg  → fg  → nil
-- text_secondary → nil  (callers have their own grey default)
-- separator      → nil
-- accent         → nil

-- Settings keys — all under simpleui_style_ so presets pick them up.
local _ROLE_KEYS = {
    bg              = "simpleui_style_theme_bg",
    fg              = "simpleui_style_theme_fg",
    bottombar_bg    = "simpleui_style_theme_bottombar_bg",
    bottombar_fg    = "simpleui_style_theme_bottombar_fg",
    statusbar_bg    = "simpleui_style_theme_statusbar_bg",
    statusbar_fg    = "simpleui_style_theme_statusbar_fg",
    text_secondary  = "simpleui_style_theme_text_secondary",
    separator       = "simpleui_style_theme_separator",
    accent          = "simpleui_style_theme_accent",
}

-- Fallback chain: if role has no value, try these roles in order.
local _FALLBACKS = {
    bottombar_bg = { "bg" },
    bottombar_fg = { "fg" },
    statusbar_bg = { "bg" },
    statusbar_fg = { "fg" },
}

-- In-memory cache: role → Blitbuffer color OR false ("tested, not set").
-- false avoids a store lookup on every paintTo().
-- Invalidated by setThemeColor() / resetTheme().
local _color_cache = {}

--- Converts "#RRGGBB" or "RRGGBB" to a full-colour Blitbuffer color.
--- Uses colorFromString when available (KOReader ≥ 2022), falls back to
--- a manual ColorRGB32 construction so older builds still work.
--- Returns nil on any parse error.
local function _hexToColor(hex)
    if type(hex) ~= "string" then return nil end
    local s = hex:match("^#?(%x%x%x%x%x%x)$")
    if not s then return nil end
    -- Prefer the built-in parser — it handles device colour depth correctly.
    if Blitbuffer.colorFromString then
        local normalized = "#" .. s:upper()
        local ok, c = pcall(Blitbuffer.colorFromString, normalized)
        if ok and c then return c end
    end
    -- Fallback: construct via ColorRGB32.
    local r = tonumber(s:sub(1, 2), 16)
    local g = tonumber(s:sub(3, 4), 16)
    local b = tonumber(s:sub(5, 6), 16)
    local ok2, c2 = pcall(Blitbuffer.ColorRGB32, r, g, b, 0)
    return ok2 and c2 or nil
end

local function _invalidateColorCache()
    _color_cache = {}
end

--- Returns the Blitbuffer color for `role`, respecting the fallback chain,
--- or nil when no custom color is set anywhere in the chain.
---
--- NOTE on cache safety: Blitbuffer cdata colors have an __eq metamethod that
--- crashes LuaJIT when either operand is non-color.  We use type() checks and
--- the boolean sentinel (false) instead of equality comparisons.
function M.getThemeColor(role)
    -- 1. Check cache for this role.
    local cached = _color_cache[role]
    local ct = type(cached)
    if ct == "boolean" then
        -- sentinel false → already resolved to nil for this role
        return nil
    elseif ct ~= "nil" then
        return cached   -- valid color object
    end

    -- 2. Try the role's own key.
    local key = _ROLE_KEYS[role]
    if key then
        local c = _hexToColor(SUISettings:get(key))
        if c then
            _color_cache[role] = c
            return c
        end
    end

    -- 3. Walk fallback chain.
    local fallbacks = _FALLBACKS[role]
    if fallbacks then
        for _, fb_role in ipairs(fallbacks) do
            local fb_key = _ROLE_KEYS[fb_role]
            if fb_key then
                local c = _hexToColor(SUISettings:get(fb_key))
                if c then
                    _color_cache[role] = c
                    return c
                end
            end
        end
    end

    -- 4. Nothing found — cache the sentinel so we skip the store next time.
    _color_cache[role] = false
    return nil
end

--- Saves `hex` ("#RRGGBB" / "RRGGBB") for `role`.
--- [DISABLED — theme color write/UI not ready for release]
--[==[
--- Saves `hex` ("#RRGGBB" / "RRGGBB") for `role`.
--- Pass nil or "" to reset the role to its default.
--- Invalidates the full in-memory cache (roles may depend on each other via
--- the fallback chain, so we can't invalidate selectively).
function M.setThemeColor(role, hex)
    local key = _ROLE_KEYS[role]
    if not key then return end
    if type(hex) == "string" and hex:match("^#?%x%x%x%x%x%x$") then
        SUISettings:set(key, hex:upper():gsub("^([^#])", "#%1"))
    else
        SUISettings:del(key)
    end
    _invalidateColorCache()
    logger.dbg("simpleui/style/theme: setThemeColor", role, "→", hex or "(reset)")
end

--- Clears every theme color override and invalidates the cache.
function M.resetTheme()
    for _, key in pairs(_ROLE_KEYS) do
        SUISettings:del(key)
    end
    _invalidateColorCache()
    logger.dbg("simpleui/style/theme: resetTheme")
end

-- ---------------------------------------------------------------------------
-- Preset palettes — shown as quick-fill shortcuts in the menu.
-- Each preset is a flat table of role → hex.
-- ---------------------------------------------------------------------------
local _PRESETS = {
    {
        label = "Warm Paper",
        colors = {
            bg             = "#F5F0E8",
            fg             = "#1A1008",
            bottombar_bg   = "#EDE8DF",
            bottombar_fg   = "#1A1008",
            statusbar_bg   = "#EDE8DF",
            statusbar_fg   = "#1A1008",
            text_secondary = "#6B5B45",
            separator      = "#C8C0B0",
            accent         = "#8B5E3C",
        },
    },
    {
        label = "Dark Slate",
        colors = {
            bg             = "#1C1C1E",
            fg             = "#E5E5EA",
            bottombar_bg   = "#2C2C2E",
            bottombar_fg   = "#E5E5EA",
            statusbar_bg   = "#2C2C2E",
            statusbar_fg   = "#E5E5EA",
            text_secondary = "#8E8E93",
            separator      = "#3A3A3C",
            accent         = "#0A84FF",
        },
    },
    {
        label = "Cool Mist",
        colors = {
            bg             = "#EEF2F7",
            fg             = "#1C2B3A",
            bottombar_bg   = "#E4EAF2",
            bottombar_fg   = "#1C2B3A",
            statusbar_bg   = "#E4EAF2",
            statusbar_fg   = "#1C2B3A",
            text_secondary = "#5A7080",
            separator      = "#C0CDD8",
            accent         = "#2D6A9F",
        },
    },
    {
        label = "Sepia Classic",
        colors = {
            bg             = "#FAEBD7",
            fg             = "#3B2A1A",
            bottombar_bg   = "#F0DFC0",
            bottombar_fg   = "#3B2A1A",
            statusbar_bg   = "#F0DFC0",
            statusbar_fg   = "#3B2A1A",
            text_secondary = "#7A5C40",
            separator      = "#D4B896",
            accent         = "#9B5B2A",
        },
    },
}

-- ---------------------------------------------------------------------------
-- Menu builder
-- ---------------------------------------------------------------------------

--- Returns the sub_item_table for Style ▸ Theme Colors.
--- Uses InputDialog (hex entry) — no external color picker widget required.
function M.makeThemeMenuItems()
    -- Ordered role definitions for the menu rows.
    -- Grouped by COLOR TYPE (not by UI location) so the user can find all
    -- "background" or "text" settings in one place regardless of which bar
    -- they belong to.  Section titles are kept to one per group; the old
    -- per-location titles (Homescreen / Bottom Bar / Status Bar / Details)
    -- have been removed as they were redundant with the label text itself.
    local _ROLES = {
        { role = "bg",             label = _("Home Screen — Background") },
        { role = "bottombar_bg",   label = _("Bottom Bar — Background") },
        { role = "statusbar_bg",   label = _("Status Bar — Background") },
        { role = "fg",             label = _("Home Screen — Text") },
        { role = "bottombar_fg",   label = _("Bottom Bar — Text and Icons") },
        { role = "statusbar_fg",   label = _("Status Bar — Text") },
        { role = "text_secondary", label = _("Secondary / Dim Text") },
        { role = "separator",      label = _("Separator Line") },
        { role = "accent",         label = _("Accent / Active Color") },
    }

    -- Shared helpers ------------------------------------------------------------
    local function _openInputDialog(role, label_str)
        local ok_id, InputDialog = pcall(require, "ui/widget/inputdialog")
        local ok_ui, UIManager   = pcall(require, "ui/uimanager")
        local ok_hs, HS          = pcall(require, "sui_homescreen")
        if not (ok_id and ok_ui) then return end

        local key     = _ROLE_KEYS[role]
        local current = (key and SUISettings:get(key)) or ""
        local dlg
        dlg = InputDialog:new{
            title       = label_str,
            input       = current,
            input_hint  = _("e.g. #F5F0E8  or #1C1C1E  (empty = reset)"),
            description = _("Enter a hex color (#RRGGBB). On greyscale e-ink the perceived brightness is used."),
            buttons     = {{
                {
                    text     = _("Cancel"),
                    callback = function() UIManager:close(dlg) end,
                },
                {
                    text             = _("Apply"),
                    is_enter_default = true,
                    callback         = function()
                        local v = dlg:getInputText():gsub("%s", "")
                        M.setThemeColor(role, v ~= "" and v or nil)
                        UIManager:close(dlg)
                        if ok_hs and HS and HS.rebuildLayout then
                            HS.rebuildLayout()
                        end
                    end,
                },
            }},
        }
        UIManager:show(dlg)
    end

    local function _makeRow(role_def)
        local role      = role_def.role
        local label_str = role_def.label
        return {
            text_func = function()
                local key = _ROLE_KEYS[role]
                local hex = key and SUISettings:get(key)
                -- Show the stored hex + edit pencil when a custom value is set.
                -- When using a fallback we show a subtle "(fallback)" note.
                if hex and hex ~= "" then
                    return label_str .. "  [" .. hex .. "]  \u{270E}"
                end
                -- Visual hint when this role inherits from a fallback.
                local fb = _FALLBACKS[role]
                if fb then
                    local fb_key = _ROLE_KEYS[fb[1]]
                    if fb_key and SUISettings:get(fb_key) then
                        return label_str .. "  \u{21B3}"   -- ↳ (inherits)
                    end
                end
                return label_str
            end,
            keep_menu_open = true,
            callback = function()
                _openInputDialog(role, label_str)
            end,
        }
    end

    -- ── Build item list ───────────────────────────────────────────────────
    local items = {}

    -- Quick-fill preset submenu at the top.
    items[#items + 1] = {
        text = _("Apply Palette…"),
        sub_item_table_func = function()
            local preset_items = {}
            for _, preset in ipairs(_PRESETS) do
                local _preset = preset
                preset_items[#preset_items + 1] = {
                    text           = _preset.label,
                    keep_menu_open = true,
                    callback       = function()
                        for role, hex in pairs(_preset.colors) do
                            M.setThemeColor(role, hex)
                        end
                        local ok_ui, UIManager = pcall(require, "ui/uimanager")
                        local ok_hs, HS        = pcall(require, "sui_homescreen")
                        if ok_ui and UIManager then UIManager:setDirty("all", "ui") end
                        if ok_hs and HS and HS.rebuildLayout then HS.rebuildLayout() end
                    end,
                }
            end
            return preset_items
        end,
    }

    -- Individual role rows — no section titles.
    for _, role_def in ipairs(_ROLES) do
        items[#items + 1] = _makeRow(role_def)
    end

    -- Reset all at the bottom.
    items[#items + 1] = {
        text     = _("Reset All Theme Colors"),
        callback = function()
            local ok_ui, UIManager = pcall(require, "ui/uimanager")
            local ok_hs, HS        = pcall(require, "sui_homescreen")
            M.resetTheme()
            if ok_ui and UIManager then UIManager:setDirty("all", "ui") end
            if ok_hs and HS and HS.rebuildLayout then HS.rebuildLayout() end
        end,
    }

--]==]
-- Disabled stubs so callers don't error:
function M.setThemeColor(role, hex) end  -- stub: disabled
function M.resetTheme() end              -- stub: disabled
function M.makeThemeMenuItems() return {} end  -- stub: disabled

-- ---------------------------------------------------------------------------
-- Icon Packs
-- ---------------------------------------------------------------------------

local function _isIconFile(fname)
    return fname:match("%.[Ss][Vv][Gg]$") ~= nil
        or fname:match("%.[Pp][Nn][Gg]$") ~= nil
end

local _ACTION_SET = {
    library=true, homescreen=true, collections=true, history=true, continue=true,
    favorites=true, bookmark_browser=true, wifi_toggle=true, wifi_toggle_off=true, frontlight=true,
    stats_calendar=true, power=true, browse_authors=true, browse_series=true, browse_tags=true,
}

-- Maps icon-pack filename identifiers to internal action ids when they differ.
-- "sui_action_library.svg" is the public icon name for the "home" (Library) action.
local _ICON_ID_ALIAS = { library = "home" }

local function _filenameToKey(fname)
    local stem = fname:match("^(.+)%.[^%.]+$") or fname
    for _, s in ipairs(M.SLOTS) do
        if s.id == stem then return "simpleui_sysicon_" .. stem, "sysicon" end
    end
    local action_id = stem:match("^sui_action_(.+)$")
    if action_id and _ACTION_SET[action_id] then
        local internal_id = _ICON_ID_ALIAS[action_id] or action_id
        return "simpleui_action_" .. internal_id .. "_icon", "action"
    end
    return nil, nil
end

function M.getPacksDir()
    local ok, DS = pcall(require, "datastorage")
    if not ok or not DS then return nil end
    local lfs = require("libs/libkoreader-lfs")
    local dir = DS:getSettingsDir() .. "/simpleui/sui_icons/packs"
    if lfs.attributes(dir, "mode") ~= "directory" then
        lfs.mkdir(dir)
    end
    return dir
end

local function _loadManifest(pack_dir)
    local lfs = require("libs/libkoreader-lfs")
    local path = pack_dir .. "/pack.lua"
    if lfs.attributes(path, "mode") ~= "file" then return {} end
    local ok, data = pcall(dofile, path)
    if ok and type(data) == "table" then return data end
    logger.warn("sui_style: invalid pack.lua in", pack_dir)
    return {}
end

function M.listPacks()
    local dir = M.getPacksDir()
    if not dir then return {} end
    local lfs = require("libs/libkoreader-lfs")
    if lfs.attributes(dir, "mode") ~= "directory" then return {} end

    local packs = {}
    for fname in lfs.dir(dir) do
        if fname ~= "." and fname ~= ".." then
            local full = dir .. "/" .. fname
            local attr = lfs.attributes(full)
            if attr then
                if attr.mode == "directory" then
                    local has_icon = false
                    for f2 in lfs.dir(full) do
                        if _isIconFile(f2) then has_icon = true; break end
                    end
                    if has_icon then
                        local manifest = _loadManifest(full)
                        packs[#packs + 1] = {
                            name   = (type(manifest.name) == "string" and manifest.name ~= "") and manifest.name or fname,
                            path   = full,
                            is_zip = false,
                        }
                    end
                end
            end
        end
    end
    table.sort(packs, function(a, b) return a.name:lower() < b.name:lower() end)
    return packs
end

local function _applyFromDir(pack_dir)
    local lfs = require("libs/libkoreader-lfs")
    local manifest  = _loadManifest(pack_dir)
    local file_map  = (type(manifest.map) == "table") and manifest.map or {}
    local result    = { applied = 0, skipped = 0, errors = 0 }
    local done_keys = {}

    for slot_id, rel_fname in pairs(file_map) do
        local settings_key = _filenameToKey(slot_id)
        if settings_key then
            local full_path    = pack_dir .. "/" .. rel_fname
            if lfs.attributes(full_path, "mode") == "file" then
                SUISettings:set(settings_key, full_path)
                done_keys[settings_key] = true
                result.applied = result.applied + 1
            else
                result.errors = result.errors + 1
            end
        else
            result.errors = result.errors + 1
        end
    end

    pcall(function()
        for fname in lfs.dir(pack_dir) do
            if fname ~= "." and fname ~= ".." and _isIconFile(fname) then
                local settings_key = _filenameToKey(fname)
                if settings_key then
                    if not done_keys[settings_key] then
                        local full_path = pack_dir .. "/" .. fname
                        if lfs.attributes(full_path, "mode") == "file" then
                            SUISettings:set(settings_key, full_path)
                            done_keys[settings_key] = true
                            result.applied = result.applied + 1
                        else
                            result.errors = result.errors + 1
                        end
                    end
                else
                    result.skipped = result.skipped + 1
                end
            end
        end
    end)
    return result
end

function M.installZip(zip_path)
    local lfs = require("libs/libkoreader-lfs")
    if lfs.attributes(zip_path, "mode") ~= "file" then return nil, _("File not found: ") .. tostring(zip_path) end
    local ok_arc, Archiver = pcall(require, "ffi/archiver")
    if not ok_arc or not Archiver then return nil, _("ffi/archiver not available in this KOReader version") end
    local packs_dir = M.getPacksDir()
    if not packs_dir then return nil, _("Could not determine packs folder") end
    local arc = Archiver.Reader:new()
    if not arc:open(zip_path) then return nil, _("Could not open zip (invalid format or corrupted)") end
    local root_prefix = nil
    for entry in arc:iterate() do
        if entry.mode == "file" then
            local first_seg = entry.path:match("^([^/]+)/")
            if first_seg then
                if root_prefix == nil then root_prefix = first_seg
                elseif root_prefix ~= first_seg then root_prefix = false; break end
            else
                root_prefix = false; break
            end
        end
    end
    local zip_stem  = zip_path:match("([^/\\]+)%.[Zz][Ii][Pp]$") or "pack"
    local pack_name = (root_prefix and root_prefix ~= "") and root_prefix or zip_stem
    local dest_dir  = packs_dir .. "/" .. pack_name
    if lfs.attributes(dest_dir, "mode") ~= "directory" then lfs.mkdir(dest_dir) end
    local n_extracted = 0
    for entry in arc:iterate() do
        if entry.mode == "file" then
            local rel = entry.path
            if root_prefix and root_prefix ~= "" then
                local stripped = rel:match("^" .. root_prefix .. "/(.+)$")
                if stripped then rel = stripped else goto continue_entry end
            end
            if not rel:match("/") and rel ~= "" then
                if _isIconFile(rel) or rel == "pack.lua" then
                    arc:extractToPath(entry.path, dest_dir .. "/" .. rel)
                    n_extracted = n_extracted + 1
                end
            end
        end
        ::continue_entry::
    end
    return pack_name, dest_dir
end

function M.applyPack(pack_path)
    local lfs = require("libs/libkoreader-lfs")
    if not pack_path then return nil, _("pack_path not provided") end
    local attr = lfs.attributes(pack_path)
    if not attr then return nil, _("Path does not exist: ") .. tostring(pack_path) end
    local pack_dir
    if attr.mode == "directory" then
        pack_dir = pack_path
    elseif attr.mode == "file" and pack_path:lower():match("%.zip$") then
        local _name, dest_or_err = M.installZip(pack_path)
        if not _name then return nil, _("Error extracting zip: ") .. tostring(dest_or_err) end
        pack_dir = dest_or_err
    else
        return nil, _("Unsupported format (use a folder or a .zip file)")
    end
    if lfs.attributes(pack_dir, "mode") ~= "directory" then return nil, _("Pack folder not accessible: ") .. tostring(pack_dir) end
    return _applyFromDir(pack_dir)
end

return M
