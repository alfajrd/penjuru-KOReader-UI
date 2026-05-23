-- moduleregistry.lua — Simple UI
-- Registry estático dos módulos partilhados entre páginas.
--
-- DESIGN (optimizado para dispositivos lentos)
-- ① Lista estática: sem lfs.dir(), sem I/O de descoberta.
-- ② Lazy-require: ficheiros de módulo só carregados na primeira chamada a
--    Registry.list() — nunca no boot do plugin.
-- ③ Cache: após o primeiro load, _loaded/_by_id são tabelas em RAM,
--    reutilizadas em todos os renders subsequentes.
-- ④ Zero lógica de negócio aqui: cada módulo declara os seus próprios
--    metadados, enabled_key e defaults.
--
-- CONTRATO DE CADA MÓDULO (module_*.lua)
--
--   M.id             string   id único estável, e.g. "clock", "collections"
--   M.name           string   nome legível para menus / Arrange
--   M.label          string?  texto da section label acima do módulo (nil = sem label)
--   M.enabled_key    string?  sufixo de settings: pfx .. enabled_key → bool
--   M.default_on     bool?    valor quando a chave não existe (default true)
--
--   -- Flags declarativas (opcionais — usadas pelo homescreen):
--   M.has_covers     bool?    true → activa dithering e-ink e cover poll
--                             (equivalente a pertencer a _COVER_MOD_IDS)
--   M.is_book_mod    bool?    true → suprime empty-state "No books opened yet"
--                             (equivalente a "currently"/"recent"/"coverdeck")
--
--   M.isEnabled(pfx)         → bool         (opcional; substitui enabled_key)
--   M.build(w, ctx)          → widget | nil
--   M.getHeight(ctx)         → number
--   M.getMenuItems(ctx_menu) → table | nil  (nil = sem sub-menu de settings)
--
-- Módulos com múltiplos slots (e.g. quick_actions) devolvem
--   M.sub_modules = { slot1, slot2, … }
-- em vez de um único id.
--
-- ADICIONAR UM MÓDULO BUILT-IN: append de uma linha em MODULES. Nada mais.
--
-- ADICIONAR UM MÓDULO EXTERNO (plugin de terceiros):
--   local ok, Registry = pcall(require, "desktop_modules/moduleregistry")
--   if ok and Registry then
--       Registry.register(MyModule)           -- tabela já carregada
--       -- ou Registry.register("myplugin/module_foo")  -- path require-able
--   end
--   -- No teardown do plugin:
--   if Registry then Registry.unregister("myplugin_foo_id") end
--
-- NOTE: module_header is intentionally absent — it has been split into
-- module_clock (Clock / Clock+Date / Custom Text) and module_quote
-- (Quote of the Day). Installations that still use module_header directly
-- are unaffected; it remains loadable as a standalone file.

local logger = require("logger")
local SUISettings = require("sui_store")

local MODULES = {
    { require_mod = "desktop_modules/module_clock"         },
    { require_mod = "desktop_modules/module_quote"         },
    { require_mod = "desktop_modules/module_currently"     },
    { require_mod = "desktop_modules/module_recent"        },
    { require_mod = "desktop_modules/module_coverdeck"     },
    { require_mod = "desktop_modules/module_new_books"     },
    { require_mod = "desktop_modules/module_tbr"           },
    { require_mod = "desktop_modules/module_collections"   },
    { require_mod = "desktop_modules/module_reading_goals" },
    { require_mod = "desktop_modules/module_reading_stats" },
    { require_mod = "desktop_modules/module_quick_actions" },
    { require_mod = "desktop_modules/module_action_list"   },
}

local _loaded        = nil
local _by_id         = nil
local _default_order = nil
-- External modules registered at runtime by third-party plugins.
-- Entries are either a module table (already loaded) or a require-path string.
-- Built-ins in MODULES always precede externals in the final list.
local _external      = {}

local function _load()
    if _loaded then return end
    _loaded = {}
    _by_id  = {}
    -- ── Built-ins ────────────────────────────────────────────────────────────
    for _, def in ipairs(MODULES) do
        local ok, mod = pcall(require, def.require_mod)
        if not ok or not mod then
            logger.warn("simpleui: moduleregistry: failed to load '" .. def.require_mod .. "': " .. tostring(mod))
        elseif mod then
            local list = mod.sub_modules or { mod }
            for _, m in ipairs(list) do
                if type(m.id) == "string" then
                    _loaded[#_loaded + 1] = m
                    _by_id[m.id]          = m
                end
            end
        end
    end
    -- ── Externals ────────────────────────────────────────────────────────────
    for _, entry in ipairs(_external) do
        local ok, mod
        if type(entry) == "string" then
            ok, mod = pcall(require, entry)
            if not ok or not mod then
                logger.warn("simpleui: moduleregistry: failed to load external '" .. entry .. "': " .. tostring(mod))
            end
        elseif type(entry) == "table" then
            ok, mod = true, entry
        end
        if ok and mod then
            local list = mod.sub_modules or { mod }
            for _, m in ipairs(list) do
                if type(m.id) == "string" and not _by_id[m.id] then
                    _loaded[#_loaded + 1] = m
                    _by_id[m.id]          = m
                end
            end
        end
    end
end

local Registry = {}

function Registry.list()
    _load(); return _loaded
end

function Registry.get(id)
    _load(); return _by_id[id]
end

function Registry.isEnabled(mod, pfx)
    if type(mod.isEnabled) == "function" then
        return mod.isEnabled(pfx)
    end
    if mod.enabled_key then
        local v = SUISettings:readSetting(pfx .. mod.enabled_key)
        if v == nil then return mod.default_on ~= false end
        return v == true
    end
    return mod.default_on ~= false
end

function Registry.countEnabled(pfx)
    local n = 0
    for _, mod in ipairs(Registry.list()) do
        if Registry.isEnabled(mod, pfx) then n = n + 1 end
    end
    return n
end

-- Merges the saved module order for a given settings prefix with the registry
-- default, appending any modules not present in the saved list.
-- Returns the cached default directly when no custom order has been saved.
function Registry.loadOrder(pfx)
    local saved = SUISettings:readSetting(pfx .. "module_order")
    if type(saved) ~= "table" or #saved == 0 then
        return Registry.defaultOrder()
    end
    local default = Registry.defaultOrder()
    local seen = {}; local result = {}
    for _, v in ipairs(saved)   do seen[v] = true; result[#result+1] = v end
    for _, v in ipairs(default) do
        if not seen[v] then
            if v == "coverdeck" then
                local insert_at = nil
                for i, id in ipairs(result) do
                    if id == "recent" then insert_at = i + 1; break end
                    if id == "currently" then insert_at = i + 1 end
                end
                if insert_at then
                    table.insert(result, insert_at, v)
                else
                    result[#result+1] = v
                end
            else
                result[#result+1] = v
            end
        end
    end
    return result
end

function Registry.defaultOrder()
    if not _default_order then
        _default_order = {}
        for _, mod in ipairs(Registry.list()) do
            _default_order[#_default_order + 1] = mod.id
        end
    end
    return _default_order
end

function Registry.invalidate()
    _loaded        = nil
    _by_id         = nil
    _default_order = nil
end

-- ---------------------------------------------------------------------------
-- Registry.register(mod_or_path)
--
-- Registers an external module so it appears in the homescreen, Arrange menu,
-- and loadOrder — exactly like built-in modules.
--
-- mod_or_path: a module table (with at least M.id set) OR a require-path
--              string (e.g. "myplugin/module_foo").
--
-- Safe to call multiple times with the same id — the previous entry is
-- replaced in _external and the cache is invalidated so the next render picks
-- up the new definition.
-- ---------------------------------------------------------------------------
function Registry.register(mod_or_path)
    if mod_or_path == nil then
        logger.warn("simpleui: moduleregistry: register() called with nil")
        return
    end
    -- Determine the id for dedup (only possible when a table is passed).
    local new_id
    if type(mod_or_path) == "table" then
        local list = mod_or_path.sub_modules or { mod_or_path }
        new_id = list[1] and list[1].id
    end
    -- Replace existing entry with same id (if any), otherwise append.
    local replaced = false
    if new_id then
        for i, entry in ipairs(_external) do
            local entry_id
            if type(entry) == "table" then
                local el = entry.sub_modules or { entry }
                entry_id = el[1] and el[1].id
            end
            if entry_id == new_id then
                _external[i] = mod_or_path
                replaced = true
                break
            end
        end
    end
    if not replaced then
        _external[#_external + 1] = mod_or_path
    end
    Registry.invalidate()
end

-- ---------------------------------------------------------------------------
-- Registry.unregister(id)
--
-- Removes a previously registered external module by its M.id string.
-- No-op when the id is unknown or refers to a built-in.
-- If a homescreen instance is currently displayed, call
-- plugin:_rebuildAllNavbars() or trigger a homescreen refresh after this.
-- ---------------------------------------------------------------------------
function Registry.unregister(id)
    if type(id) ~= "string" then return end
    for i = #_external, 1, -1 do
        local entry = _external[i]
        local entry_id
        if type(entry) == "table" then
            local el = entry.sub_modules or { entry }
            entry_id = el[1] and el[1].id
        end
        if entry_id == id then
            table.remove(_external, i)
            Registry.invalidate()
            return
        end
    end
end

return Registry
