-- sui_presets.lua — SimpleUI Presets
--
-- This module contains two independent preset systems with the same
-- architecture: snapshot → storage in a single key → restore.
--
-- ══════════════════════════════════════════════════════════════════════════
-- 1. HOMESCREEN PRESETS  (SUIPresets)
-- ══════════════════════════════════════════════════════════════════════════
-- Saves and restores complete snapshots of the homescreen configuration.
-- Covers: modules, order, quick actions per slot, wallpaper, transparent bars.
-- Does NOT include: topbar/bottombar, the preset storage key itself.
-- Storage: "simpleui_hs_presets" → { [name] = {k=v, ...}, ... }
--
-- API:
--   SUIPresets.save(name)       SUIPresets.apply(name)    SUIPresets.delete(name)
--   SUIPresets.listNames()      SUIPresets.exists(name)   SUIPresets.rename(old,new)
--   SUIPresets.getAll()
--
-- ══════════════════════════════════════════════════════════════════════════
-- 2. ICON PRESETS  (SUIIconPresets)
-- ══════════════════════════════════════════════════════════════════════════
-- Saves and restores snapshots of all icon customizations:
--   • System icon overrides      simpleui_sysicon_*
--   • Default action icon overr. simpleui_action_*_icon
--   • Custom QA icon fields      simpleui_cqa_<id>.icon  (only the icon field)
-- Does NOT include: labels, paths/collections of CQAs, the storage key itself.
-- Storage: "simpleui_icon_presets" → { [name] = {_scalar={}, _cqa={}}, ... }
--
-- API:
--   SUIIconPresets.save(name)           SUIIconPresets.apply(name, QA_module)
--   SUIIconPresets.delete(name)         SUIIconPresets.listNames()
--   SUIIconPresets.exists(name)         SUIIconPresets.rename(old, new)
--   SUIIconPresets.getAll()

local SUISettings = require("sui_store")
local logger      = require("logger")
local _           = require("sui_i18n").translate

-- ============================================================================
-- § 1  HOMESCREEN PRESETS
-- ============================================================================

local HS_PRESET_KEY = "simpleui_hs_presets"

local HS_PREFIXES = {
    "simpleui_hs_",
    "simpleui_style_",
}

local HS_EXACT = {
    ["simpleui_statusbar_transparent"]  = true,
    ["simpleui_navbar_transparent"]     = true,
    ["simpleui_wallpaper_show_in_fm"]   = true,  -- "show wallpaper in file manager" toggle
    ["simpleui_collections_list"]           = true,
    ["simpleui_collections_badge_position"] = true,
    ["simpleui_collections_badge_color"]    = true,
    ["simpleui_collections_badge_hidden"]   = true,
    ["simpleui_reading_goals_show_annual"]  = true,
    ["simpleui_reading_goals_show_daily"]   = true,
    ["simpleui_reading_goals_layout"]       = true,
}

local function _hsMatchesKey(key)
    if HS_EXACT[key] then return true end
    for _, pfx in ipairs(HS_PREFIXES) do
        if key:sub(1, #pfx) == pfx then
            if key == HS_PRESET_KEY then return false end
            if key == HS_PRESET_KEY or key == "simpleui_hs_active_preset" then return false end
            return true
        end
    end
    return false
end

local function _getDirs()
    local ok_ds, DataStorage = pcall(require, "datastorage")
    if not ok_ds or not DataStorage then return nil, nil end
    local base = DataStorage:getSettingsDir() .. "/simpleui/sui_presets"
    local exp_dir = base .. "/sui_presets_export"
    local imp_dir = base .. "/sui_presets_import"
    local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
    if ok_lfs and lfs then
        if lfs.attributes(base, "mode") ~= "directory" then lfs.mkdir(base) end
        if lfs.attributes(exp_dir, "mode") ~= "directory" then lfs.mkdir(exp_dir) end
        if lfs.attributes(imp_dir, "mode") ~= "directory" then lfs.mkdir(imp_dir) end
    end
    return exp_dir, imp_dir
end

local function _getExportDir()
    local exp, _ = _getDirs()
    return exp
end

local function _getImportDir()
    local _, imp = _getDirs()
    return imp
end

local function _listImportFiles(suffix)
    local dir = _getImportDir()
    local files = {}
    if not dir then return files end
    local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
    if not ok_lfs then return files end
    local pattern = suffix and (suffix:gsub("%.", "%%.") .. "$") or "%.lua$"
    if lfs.attributes(dir, "mode") == "directory" then
        for fname in lfs.dir(dir) do
            if fname ~= "." and fname ~= ".." and fname:lower():match(pattern:lower()) then
                files[#files + 1] = {
                    name = fname,
                    path = dir .. "/" .. fname
                }
            end
        end
        table.sort(files, function(a, b) return a.name:lower() < b.name:lower() end)
    end
    return files
end

local function _countKeys(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

local SUIPresets = {}

function SUIPresets.getAll()
    local v = SUISettings:get(HS_PRESET_KEY)
    return type(v) == "table" and v or {}
end

function SUIPresets.save(name)
    if type(name) ~= "string" or name == "" then
        logger.warn("simpleui/presets: save() called with invalid name")
        return false
    end
    local snapshot = {}
    for k, v in SUISettings:iterateKeys() do
        if _hsMatchesKey(k) then
            if type(v) == "table" then
                local copy = {}
                for ki, vi in pairs(v) do copy[ki] = vi end
                snapshot[k] = copy
            else
                snapshot[k] = v
            end
        end
    end
    local presets = SUIPresets.getAll()
    presets[name] = snapshot
    SUISettings:set(HS_PRESET_KEY, presets)
    logger.dbg("simpleui/presets: saved preset '", name, "' with", _countKeys(snapshot), "keys")
    return true
end

function SUIPresets.apply(name)
    if type(name) ~= "string" or name == "" then return false end
    local presets  = SUIPresets.getAll()
    local snapshot = presets[name]
    if type(snapshot) ~= "table" then
        logger.warn("simpleui/presets: apply() — preset '", name, "' not found")
        return false
    end
    local to_delete = {}
    for k in SUISettings:iterateKeys() do
        if _hsMatchesKey(k) then to_delete[#to_delete + 1] = k end
    end
    for _, k in ipairs(to_delete) do SUISettings:del(k) end
    for k, v in pairs(snapshot) do SUISettings:set(k, v) end
    logger.dbg("simpleui/presets: applied preset '", name, "'")
    return true
end

function SUIPresets.delete(name)
    if type(name) ~= "string" or name == "" then return end
    local presets = SUIPresets.getAll()
    if presets[name] then
        presets[name] = nil
        SUISettings:set(HS_PRESET_KEY, presets)
        logger.dbg("simpleui/presets: deleted preset '", name, "'")
    end
end

function SUIPresets.rename(old_name, new_name)
    if type(old_name) ~= "string" or old_name == "" then return false end
    if type(new_name) ~= "string" or new_name == "" then return false end
    if old_name == new_name then return true end
    local presets = SUIPresets.getAll()
    if not presets[old_name] then return false end
    presets[new_name] = presets[old_name]
    presets[old_name] = nil
    SUISettings:set(HS_PRESET_KEY, presets)
    return true
end

function SUIPresets.exists(name)
    if type(name) ~= "string" or name == "" then return false end
    return SUIPresets.getAll()[name] ~= nil
end

function SUIPresets.listNames()
    local names = {}
    for name in pairs(SUIPresets.getAll()) do names[#names + 1] = name end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function SUIPresets.export(name)
    local dir = _getExportDir()
    if not dir then return nil, _("No export directory") end
    local preset = SUIPresets.getAll()[name]
    if not preset then return nil, _("Preset not found") end

    local filename = name:gsub("[^%w_.-]", "_") .. "_sui_hs.lua"
    local filepath = dir .. "/" .. filename

    local ok, LuaSettings = pcall(require, "luasettings")
    if not ok or not LuaSettings then return nil, _("LuaSettings module unavailable") end

    local f = LuaSettings:open(filepath)
    f:saveSetting("type", "simpleui_homescreen_preset")
    f:saveSetting("name", name)
    f:saveSetting("data", preset)
    f:flush()
    return filepath
end

function SUIPresets.import(filepath)
    local ok, LuaSettings = pcall(require, "luasettings")
    if not ok or not LuaSettings then return nil, _("LuaSettings module unavailable") end

    local f = LuaSettings:open(filepath)
    local typ = f:readSetting("type")
    if typ ~= "simpleui_homescreen_preset" then
        return nil, _("Invalid preset file")
    end
    local name = f:readSetting("name") or "Imported Preset"
    local data = f:readSetting("data")
    if type(data) ~= "table" then return nil, _("Invalid data") end

    local presets = SUIPresets.getAll()
    local final_name = name
    local i = 1
    while presets[final_name] do
        final_name = name .. " (" .. i .. ")"
        i = i + 1
    end
    presets[final_name] = data
    SUISettings:set(HS_PRESET_KEY, presets)
    return final_name
end

-- ============================================================================
-- § 2  ICON PRESETS
-- ============================================================================

local ICON_PRESET_KEY  = "simpleui_icon_presets"
local ICON_PREFIXES    = { "simpleui_sysicon_", "simpleui_action_" }
local CQA_PREFIX       = "simpleui_cqa_"
local CQA_LIST_KEY     = "simpleui_cqa_list"

local function _isScalarIconKey(key)
    if key == ICON_PRESET_KEY then return false end
    for _, pfx in ipairs(ICON_PREFIXES) do
        if key:sub(1, #pfx) == pfx then return true end
    end
    return false
end

local function _isCQAKey(key)
    return key ~= ICON_PRESET_KEY
        and key ~= CQA_LIST_KEY
        and key:sub(1, #CQA_PREFIX) == CQA_PREFIX
end

local SUIIconPresets = {}

function SUIIconPresets.getAll()
    local v = SUISettings:get(ICON_PRESET_KEY)
    return type(v) == "table" and v or {}
end

--- Saves the current state of all icons as a preset with the given name.
function SUIIconPresets.save(name)
    if type(name) ~= "string" or name == "" then
        logger.warn("simpleui/icon_presets: save() invalid name")
        return false
    end
    local snapshot = { _scalar = {}, _cqa = {} }

    -- Scalar keys: sysicon overrides + default action icon overrides.
    for k, v in SUISettings:iterateKeys() do
        if _isScalarIconKey(k) then snapshot._scalar[k] = v end
    end

    -- .icon field of each CQA (without touching other fields).
    local cqa_list = SUISettings:get(CQA_LIST_KEY) or {}
    for _i, qa_id in ipairs(cqa_list) do
        local cfg = SUISettings:get(CQA_PREFIX .. qa_id)
        if type(cfg) == "table" and cfg.icon ~= nil then
            snapshot._cqa[qa_id] = cfg.icon
        end
    end

    local presets = SUIIconPresets.getAll()
    presets[name] = snapshot
    SUISettings:set(ICON_PRESET_KEY, presets)
    logger.dbg("simpleui/icon_presets: saved '", name, "'")
    return true
end

--- Applies an icon preset.
--- QA: sui_quickactions module (to invalidate the cache after changing CQAs).
function SUIIconPresets.apply(name, QA)
    if type(name) ~= "string" or name == "" then return false end
    local snapshot = SUIIconPresets.getAll()[name]
    if type(snapshot) ~= "table" then
        logger.warn("simpleui/icon_presets: apply() — '", name, "' not found")
        return false
    end

    -- 1. Clear all current scalar icon keys.
    local to_delete = {}
    for k in SUISettings:iterateKeys() do
        if _isScalarIconKey(k) then to_delete[#to_delete + 1] = k end
    end
    for _, k in ipairs(to_delete) do SUISettings:del(k) end

    -- 2. Restore scalar keys.
    for k, v in pairs(snapshot._scalar or {}) do SUISettings:set(k, v) end

    -- 3. Apply .icon to each existing CQA; CQAs missing from snapshot → reset.
    local cqa_list = SUISettings:get(CQA_LIST_KEY) or {}
    local cqa_icons = snapshot._cqa or {}
    for _i, qa_id in ipairs(cqa_list) do
        local cfg = SUISettings:get(CQA_PREFIX .. qa_id)
        if type(cfg) == "table" then
            cfg.icon = cqa_icons[qa_id]  -- nil = reset para default
            SUISettings:set(CQA_PREFIX .. qa_id, cfg)
        end
    end

    -- 4. Invalidate QA cache.
    if QA and QA.invalidateCustomQACache then QA.invalidateCustomQACache() end

    logger.dbg("simpleui/icon_presets: applied '", name, "'")
    return true
end

function SUIIconPresets.delete(name)
    if type(name) ~= "string" or name == "" then return end
    local presets = SUIIconPresets.getAll()
    if presets[name] then
        presets[name] = nil
        SUISettings:set(ICON_PRESET_KEY, presets)
        logger.dbg("simpleui/icon_presets: deleted '", name, "'")
    end
end

function SUIIconPresets.rename(old_name, new_name)
    if type(old_name) ~= "string" or old_name == "" then return false end
    if type(new_name) ~= "string" or new_name == "" then return false end
    if old_name == new_name then return true end
    local presets = SUIIconPresets.getAll()
    if not presets[old_name] then return false end
    presets[new_name] = presets[old_name]
    presets[old_name] = nil
    SUISettings:set(ICON_PRESET_KEY, presets)
    return true
end

function SUIIconPresets.exists(name)
    if type(name) ~= "string" or name == "" then return false end
    return SUIIconPresets.getAll()[name] ~= nil
end

function SUIIconPresets.listNames()
    local names = {}
    for n in pairs(SUIIconPresets.getAll()) do names[#names + 1] = n end
    table.sort(names, function(a, b) return a:lower() < b:lower() end)
    return names
end

function SUIIconPresets.export(name)
    local dir = _getExportDir()
    if not dir then return nil, _("No export directory") end
    local preset = SUIIconPresets.getAll()[name]
    if not preset then return nil, _("Preset not found") end

    local filename = name:gsub("[^%w_.-]", "_") .. "_sui_icn.lua"
    local filepath = dir .. "/" .. filename

    local ok, LuaSettings = pcall(require, "luasettings")
    if not ok or not LuaSettings then return nil, _("LuaSettings module unavailable") end

    local f = LuaSettings:open(filepath)
    f:saveSetting("type", "simpleui_icon_preset")
    f:saveSetting("name", name)
    f:saveSetting("data", preset)
    f:flush()
    return filepath
end

function SUIIconPresets.import(filepath)
    local ok, LuaSettings = pcall(require, "luasettings")
    if not ok or not LuaSettings then return nil, _("LuaSettings module unavailable") end

    local f = LuaSettings:open(filepath)
    local typ = f:readSetting("type")
    if typ ~= "simpleui_icon_preset" then
        return nil, _("Invalid preset file")
    end
    local name = f:readSetting("name") or "Imported Icon Preset"
    local data = f:readSetting("data")
    if type(data) ~= "table" then return nil, _("Invalid data") end

    local presets = SUIIconPresets.getAll()
    local final_name = name
    local i = 1
    while presets[final_name] do
        final_name = name .. " (" .. i .. ")"
        i = i + 1
    end
    presets[final_name] = data
    SUISettings:set(ICON_PRESET_KEY, presets)
    return final_name
end

SUIPresets.getExportDir = _getExportDir
SUIPresets.getImportDir = _getImportDir
SUIPresets.listImportFiles = function() return _listImportFiles("_sui_hs.lua") end

SUIIconPresets.getExportDir = _getExportDir
SUIIconPresets.getImportDir = _getImportDir
SUIIconPresets.listImportFiles = function() return _listImportFiles("_sui_icn.lua") end

-- ============================================================================
-- Exports
-- ============================================================================

return {
    -- Homescreen presets (compatibility with existing code that does
    -- local P = require("sui_presets") and calls P.save / P.apply / etc.)
    save      = SUIPresets.save,
    apply     = SUIPresets.apply,
    delete    = SUIPresets.delete,
    listNames = SUIPresets.listNames,
    exists    = SUIPresets.exists,
    rename    = SUIPresets.rename,
    getAll    = SUIPresets.getAll,
    export    = SUIPresets.export,
    import    = SUIPresets.import,
    getExportDir    = _getExportDir,
    getImportDir    = _getImportDir,
    listImportFiles = SUIPresets.listImportFiles,

    -- Icon presets (accessed via P.icons.save / P.icons.apply / etc.)
    icons = SUIIconPresets,
}
