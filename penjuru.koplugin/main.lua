-- main.lua — Simple UI
-- Plugin entry point. Registers the plugin and delegates to specialised modules.

local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager       = require("ui/uimanager")
local InfoMessage     = require("ui/widget/infomessage")
local logger          = require("logger")
local Dispatcher      = require("dispatcher")

-- Each simpleui module captures its own local translation proxy from sui_i18n.
-- The native package.loaded["gettext"] is never wrapped or replaced, which
-- prevents state-mutation conflicts with other plugins (e.g. zlibrary).
local I18n = require("pen_i18n")
local _    = I18n.translate

local Config       = require("pen_config")
local UI           = require("pen_core")
local Bottombar    = require("pen_bottombar")
local Topbar       = require("pen_topbar")
-- pen_patches removed: legacy SimpleUI chrome injection (Plan D / D.0.1)
local PENSettings  = require("pen_store")

local penjuruPlugin = WidgetContainer:new{
    name = "penjuru",

    active_action             = nil,
    _rebuild_scheduled        = false,
    _topbar_timer             = nil,
    _power_dialog             = nil,

    _orig_uimanager_show      = nil,
    _orig_uimanager_close     = nil,
    _orig_booklist_new        = nil,
    _orig_menu_new            = nil,
    _orig_menu_init           = nil,
    _orig_fmcoll_show         = nil,
    _orig_rc_remove           = nil,
    _orig_rc_rename           = nil,
    _orig_fc_init             = nil,
    _orig_fm_setup            = nil,

    _makeNavbarMenu           = nil,
    _makeTopbarMenu           = nil,
    _makeQuickActionsMenu     = nil,
    _goalTapCallback          = nil,
}

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function penjuruPlugin:init()
    local ok, err = pcall(function()
        -- Ensure the simpleui settings directory tree exists before any
        -- PENSettings call.  PENSettings is lazy — its LuaSettings store is
        -- opened on first use — but LuaSettings:open() cannot create the
        -- parent directory.  If the directory is missing (fresh install, or
        -- the dir was wiped) the open will succeed but flush() will silently
        -- fail, discarding all writes for the session.
        --
        -- We create all five user-data directories here unconditionally so
        -- that (a) PENSettings can write safely and (b) a fresh install never
        -- needs to wait until the migration block to have a usable directory
        -- structure.  All five lfs.attributes calls are cheap (single stat
        -- syscall each) and lfs.mkdir is only called when the directory is
        -- actually absent, so the common steady-state cost is negligible.
        do
            local ok_ds,  DataStorage = pcall(require, "datastorage")
            local ok_lfs, lfs_early  = pcall(require, "libs/libkoreader-lfs")
            if ok_ds and ok_lfs then
                local base = DataStorage:getSettingsDir() .. "/penjuru"
                for _, sub in ipairs({
                    "", "/pen_icons", "/pen_icons/packs", "/pen_quotes",
                    "/pen_wallpapers"
                    -- sui_presets removed: out of scope for penjuru v1
                }) do
                    local path = base .. sub
                    if lfs_early.attributes(path, "mode") ~= "directory" then
                        lfs_early.mkdir(path)
                    end
                end
            end
        end

        -- Detect hot update: compare the version now on disk with what was
        -- running last session. If they differ, warn the user to restart so
        -- that all plugin modules are loaded fresh.
        local current_version
        local src = debug.getinfo(1, "S").source or ""
        local p_root = src:match("^@?(.+)/[^/]+$")
        if p_root then
            local ok, meta = pcall(dofile, p_root .. "/_meta.lua")
            if ok and type(meta) == "table" and meta.name == "penjuru" then
                current_version = meta.version
            end
        end
        if not current_version then
            local meta_ok, meta = pcall(require, "_meta")
            if meta_ok and type(meta) == "table" and meta.name == "penjuru" then
                current_version = meta.version
            end
        end
        -- Read version from PENSettings; fall back to G_reader_settings for the
        -- first boot after the Phase-4 migration (before v2 migration has run).
        local prev_version = PENSettings:get("penjuru_loaded_version")
            or G_reader_settings:readSetting("penjuru_loaded_version")
        if current_version then
            if prev_version and prev_version ~= current_version then
                logger.info("simpleui: updated from", prev_version, "to", current_version,
                    "— restart recommended")
                UIManager:scheduleIn(1, function()
                    local InfoMessage = require("ui/widget/infomessage")
                    local _t = require("pen_i18n").translate
                    UIManager:show(InfoMessage:new{
                        text = string.format(
                            _t("Simple UI was updated (%s → %s).\n\nA restart is recommended to apply all changes cleanly."),
                            prev_version, current_version
                        ),
                        timeout = 6,
                    })
                end)
            end
            PENSettings:set("penjuru_loaded_version", current_version)
        end

        -- -------------------------------------------------------------------
        -- User-data migration (runs once per install / once after upgrade).
        --
        -- v1: move user files out of the plugin folder into DataStorage so
        --     they survive plugin updates, and normalise all settings keys to
        --     the simpleui_ / navbar_ namespace.
        -- -------------------------------------------------------------------
        if not G_reader_settings:isTrue("penjuru_userdata_migrated_v1") then
            pcall(function()
                local ok_ds, DataStorage = pcall(require, "datastorage")
                local ok_lfs, lfs        = pcall(require, "libs/libkoreader-lfs")
                local ok_ffi, ffiutil    = pcall(require, "ffi/util")
                if not (ok_ds and ok_lfs and ok_ffi) then return end

                local data_dir = DataStorage:getSettingsDir() .. "/penjuru"

                -- ── 1. Migrate user files (copy, never overwrite) ─────────
                -- Directory structure is guaranteed by the startup block above.
                -- Resolve plugin root from this file's path.
                local src_info   = debug.getinfo(1, "S").source or ""
                local plugin_root = src_info:sub(1,1) == "@"
                    and src_info:sub(2):match("^(.*)/[^/]+$") or nil
                if plugin_root and plugin_root:sub(1,1) ~= "/" then
                    local ok_lfs2, lfs2 = pcall(require, "libs/libkoreader-lfs")
                    local cwd = ok_lfs2 and lfs2 and lfs2.currentdir()
                    if cwd then plugin_root = cwd .. "/" .. plugin_root end
                end

                if plugin_root then
                    -- Copy files from src/ to dst/ (never overwrite existing).
                    local function copyDirContents(src, dst)
                        if lfs.attributes(src, "mode") ~= "directory" then return end
                        for fname in lfs.dir(src) do
                            if fname ~= "." and fname ~= ".." then
                                local src_f = src .. "/" .. fname
                                local dst_f = dst .. "/" .. fname
                                if lfs.attributes(src_f, "mode") == "file"
                                    and lfs.attributes(dst_f, "mode") ~= "file" then
                                    ffiutil.copyFile(src_f, dst_f)
                                end
                            end
                        end
                    end

                    -- Removes all plain files inside dir, then the dir itself.
                    -- Skips silently if dir doesn't exist or still has subdirs.
                    local function removeDirIfEmpty(dir)
                        if lfs.attributes(dir, "mode") ~= "directory" then return end
                        for fname in lfs.dir(dir) do
                            if fname ~= "." and fname ~= ".." then
                                local p = dir .. "/" .. fname
                                if lfs.attributes(p, "mode") == "file" then
                                    os.remove(p)
                                end
                            end
                        end
                        lfs.rmdir(dir)  -- only succeeds when empty
                    end

                    -- icons/custom → DataStorage/penjuru/pen_icons/
                    -- then remove the now-redundant in-plugin directory.
                    copyDirContents(plugin_root .. "/icons/custom",
                                    data_dir    .. "/pen_icons")
                    removeDirIfEmpty(plugin_root .. "/icons/custom")

                    -- desktop_modules/custom_quotes → DataStorage/penjuru/pen_quotes/
                    -- then remove the now-redundant in-plugin directory.
                    copyDirContents(plugin_root .. "/desktop_modules/custom_quotes",
                                    data_dir    .. "/pen_quotes")
                    removeDirIfEmpty(plugin_root .. "/desktop_modules/custom_quotes")
                end

                -- ── 2. Migrate renamed settings keys ──────────────────────
                -- Each entry: { old_key, new_key }
                local key_renames = {
                    { "pen_tbr_list",             "penjuru_tbr_list"                    },
                    { "quote_deck_order",          "penjuru_quote_deck_order"            },
                    { "quote_deck_pos",            "penjuru_quote_deck_pos"              },
                    { "quote_deck_count",          "penjuru_quote_deck_count"            },
                    { "quote_hl_deck_order",       "penjuru_quote_hl_deck_order"         },
                    { "quote_hl_deck_pos",         "penjuru_quote_hl_deck_pos"           },
                    { "quote_hl_deck_count",       "penjuru_quote_hl_deck_count"         },
                    { "quote_custom_deck_order",   "penjuru_quote_custom_deck_order"     },
                    { "quote_custom_deck_pos",     "penjuru_quote_custom_deck_pos"       },
                    { "quote_custom_deck_count",   "penjuru_quote_custom_deck_count"     },
                    { "quote_custom_deck_file",    "penjuru_quote_custom_deck_file"      },
                    -- quote_source and quote_custom_file are per-instance (prefixed
                    -- with navbar_homescreen_ at runtime); migrate all known slots.
                    { "navbar_homescreen_quote_source",      "navbar_homescreen_simpleui_quote_source"      },
                    { "navbar_homescreen_quote_custom_file", "navbar_homescreen_simpleui_quote_custom_file" },
                }
                for _, pair in ipairs(key_renames) do
                    local old_key, new_key = pair[1], pair[2]
                    local val = G_reader_settings:readSetting(old_key)
                    if val ~= nil and G_reader_settings:readSetting(new_key) == nil then
                        G_reader_settings:saveSetting(new_key, val)
                    end
                    G_reader_settings:delSetting(old_key)
                end

                logger.info("simpleui: userdata migration v1 complete")
            end)
            G_reader_settings:saveSetting("penjuru_userdata_migrated_v1", true)
        end
        -- -------------------------------------------------------------------
        -- Settings migration v2: move all navbar_* and simpleui_* keys from
        -- G_reader_settings into PENSettings (the dedicated per-plugin store).
        --
        -- This runs once on first boot after the Phase-3 refactor.  It is safe
        -- to re-run if interrupted: keys that already exist in PENSettings are
        -- not overwritten; keys successfully copied are removed from
        -- G_reader_settings.
        -- -------------------------------------------------------------------
        if not PENSettings:isTrue("penjuru_settings_migrated_v2") then
            pcall(function()
                -- Enumerate every key currently stored in G_reader_settings
                -- and migrate the ones owned by SimpleUI.
                local raw = G_reader_settings.data  -- LuaSettings exposes .data
                if type(raw) ~= "table" then return end

                -- Collect owned keys first; deleting from raw while iterating
                -- it with pairs() has undefined behaviour in Lua and can cause
                -- entries to be skipped.
                local to_migrate = {}
                for k, v in pairs(raw) do
                    local owned = (type(k) == "string")
                        and (k:sub(1, 7) == "navbar_" or k:sub(1, 9) == "penjuru_")
                        -- Keep the v1 and v2 migration flags in G_reader_settings
                        -- so they survive a factory reset of sui_settings.lua.
                        and k ~= "penjuru_userdata_migrated_v1"
                    if owned then
                        to_migrate[#to_migrate + 1] = { k = k, v = v }
                    end
                end

                local migrated = 0
                for _, entry in ipairs(to_migrate) do
                    local k, v = entry.k, entry.v
                    -- Only copy if PENSettings does not already have the key
                    -- (e.g. the user already made changes after the code update).
                    if PENSettings:get(k) == nil then
                        PENSettings:set(k, v)
                    end
                    G_reader_settings:delSetting(k)
                    migrated = migrated + 1
                end

                PENSettings:flush()
                logger.info("simpleui: settings migration v2 complete —", migrated, "keys moved to PENSettings")
            end)
            PENSettings:set("penjuru_settings_migrated_v2", true)
            PENSettings:flush()
        end
        -- -------------------------------------------------------------------
        -- Settings migration v3: rename all navbar_* keys inside PENSettings
        -- to the canonical simpleui_* namespace.
        --
        -- Two passes:
        --   1. Fixed renames  — explicit old → new map (fast, readable).
        --   2. Dynamic prefix — bulk rename of per-slot / per-id keys that are
        --      built at runtime via string concatenation.
        --
        -- Rules:
        --   • Only copies when the destination key is absent (never overwrites).
        --   • Old key is always deleted, even when the copy is skipped.
        --   • The whole block runs inside pcall — a crash must never prevent
        --     the plugin from loading on a resource-constrained e-reader.
        --   • Guarded by simpleui_settings_migrated_v3 so it runs at most once.
        -- -------------------------------------------------------------------
        if not PENSettings:isTrue("penjuru_settings_migrated_v3") then
            pcall(function()
                -- ── 1. Fixed renames ─────────────────────────────────────────
                local fixed_renames = {
                    -- Bottom bar — general
                    { "navbar_enabled",                      "penjuru_bar_enabled"                   },
                    { "navbar_mode",                         "penjuru_bar_mode"                      },
                    { "navbar_bar_size",                     "penjuru_bar_size"                      },
                    { "navbar_bar_size_pct",                 "penjuru_bar_size_pct"                  },
                    { "navbar_hide_separator",               "penjuru_bar_hide_separator"            },
                    { "navbar_bottom_margin_pct",            "penjuru_bar_bottom_margin_pct"         },
                    { "navbar_icon_scale_pct",               "penjuru_bar_icon_scale_pct"            },
                    { "navbar_label_scale_pct",              "penjuru_bar_label_scale_pct"           },
                    { "navbar_rs_text_scale_pct",            "penjuru_bar_rs_text_scale_pct"         },
                    -- Bottom bar — pagination / pager
                    { "navbar_pagination_visible",           "penjuru_bar_pagination_visible"        },
                    { "navbar_pagination_size",              "penjuru_bar_pagination_size"           },
                    { "navbar_pagination_show_subtitle",     "penjuru_bar_pagination_show_subtitle"  },
                    { "navbar_navpager_enabled",             "penjuru_bar_navpager_enabled"          },
                    { "navbar_dotpager_always",              "penjuru_bar_dotpager_always"           },
                    -- Bottom bar — tabs & settings
                    { "navbar_tabs",                         "penjuru_bar_tabs"                      },
                    { "navbar_bottombar_settings_on_hold",   "penjuru_bar_settings_on_hold"          },
                    -- Top bar
                    { "navbar_topbar_enabled",               "penjuru_topbar_enabled"                },
                    { "navbar_topbar_config",                "penjuru_topbar_config"                 },
                    { "navbar_topbar_custom_text",           "penjuru_topbar_custom_text"            },
                    { "navbar_topbar_settings_on_hold",      "penjuru_topbar_settings_on_hold"       },
                    { "navbar_topbar_swipe_indicator",       "penjuru_topbar_swipe_indicator"        },
                    { "navbar_topbar_wifi_hide_when_off",    "penjuru_topbar_wifi_hide_when_off"     },
                    { "navbar_topbar_size_pct",              "penjuru_topbar_size_pct"               },
                    -- Homescreen bar — fixed keys
                    { "navbar_homescreen_pagination_hidden", "penjuru_hs_pagination_hidden"          },
                    { "navbar_homescreen_settings_on_hold",  "penjuru_hs_settings_on_hold"           },
                    { "navbar_homescreen_overflow_warn",     "penjuru_hs_overflow_warn"              },
                    { "navbar_hs_return_to_book_folder",     "penjuru_hs_return_to_book_folder"      },
                    { "navbar_homescreen_module_scale",      "penjuru_hs_module_scale"               },
                    { "navbar_homescreen_label_scale",       "penjuru_hs_label_scale"                },
                    { "navbar_homescreen_scale_linked",      "penjuru_hs_scale_linked"               },
                    -- Reading goal
                    { "navbar_reading_goal",                 "penjuru_reading_goal"                  },
                    { "navbar_reading_goal_physical",        "penjuru_reading_goal_physical"         },
                    { "navbar_daily_reading_goal_secs",      "penjuru_daily_reading_goal_secs"       },
                    -- Reading goals module display
                    { "navbar_reading_goals_show_annual",    "penjuru_reading_goals_show_annual"     },
                    { "navbar_reading_goals_show_daily",     "penjuru_reading_goals_show_daily"      },
                    { "navbar_reading_goals_layout",         "penjuru_reading_goals_layout"          },
                    -- Collections module
                    { "navbar_collections_list",             "penjuru_collections_list"              },
                    { "navbar_collections_covers",           "penjuru_collections_covers"            },
                    { "navbar_collections_badge_position",   "penjuru_collections_badge_position"    },
                    { "navbar_collections_badge_color",      "penjuru_collections_badge_color"       },
                    { "navbar_collections_badge_hidden",     "penjuru_collections_badge_hidden"      },
                    -- Custom quick actions — list & migration flag
                    { "navbar_custom_qa_list",               "penjuru_cqa_list"                      },
                    { "navbar_custom_qa_migrated_v1",        "penjuru_cqa_migrated_v1"               },
                }

                local migrated = 0

                for _, pair in ipairs(fixed_renames) do
                    local old_k, new_k = pair[1], pair[2]
                    local val = PENSettings:get(old_k)
                    if val ~= nil then
                        if PENSettings:get(new_k) == nil then
                            PENSettings:set(new_k, val)
                        end
                        PENSettings:del(old_k)
                        migrated = migrated + 1
                    end
                end

                -- ── 2. Dynamic-prefix renames ─────────────────────────────────
                -- Keys built at runtime via string concatenation:
                --   simpleui_hs_*        (was navbar_homescreen_*)
                --   navbar_cqa_*         →  simpleui_cqa_*
                --   navbar_action_*      →  simpleui_action_*
                --   navbar_custom_*      →  simpleui_custom_*
                --
                -- We collect all renames first, then apply — modifying a table
                -- while iterating it is undefined behaviour in Lua 5.1/5.2.
                local dynamic_prefixes = {
                    { old = "navbar_homescreen_",  new = "penjuru_hs_"     },
                    { old = "navbar_cqa_",         new = "penjuru_cqa_"    },
                    { old = "navbar_action_",      new = "penjuru_action_" },
                    { old = "navbar_custom_",      new = "penjuru_custom_" },
                }

                local pending = {}
                for k, v in PENSettings:iterateKeys() do
                    for _, pfx in ipairs(dynamic_prefixes) do
                        local plen = #pfx.old
                        if k:sub(1, plen) == pfx.old then
                            local new_k = pfx.new .. k:sub(plen + 1)
                            pending[#pending + 1] = { old_k = k, new_k = new_k, val = v }
                            break
                        end
                    end
                end

                for _, entry in ipairs(pending) do
                    if PENSettings:get(entry.new_k) == nil then
                        PENSettings:set(entry.new_k, entry.val)
                    end
                    PENSettings:del(entry.old_k)
                    migrated = migrated + 1
                end

                PENSettings:flush()
                logger.info("simpleui: settings migration v3 complete —", migrated, "navbar_* keys renamed to simpleui_*")
            end)
            PENSettings:set("penjuru_settings_migrated_v3", true)
            PENSettings:flush()
        end
        -- -------------------------------------------------------------------
        -- Settings migration v4: rename icon pack keys to integrated sui_ scheme.
        -- -------------------------------------------------------------------
        if not PENSettings:isTrue("penjuru_settings_migrated_v4") then
            pcall(function()
                local icon_renames = {
                    { "penjuru_sysicon_bm_normal",     "penjuru_sysicon_sui_browse_normal" },
                    { "penjuru_sysicon_bm_author",     "penjuru_sysicon_sui_browse_author" },
                    { "penjuru_sysicon_bm_series",     "penjuru_sysicon_sui_browse_series" },
                    { "penjuru_sysicon_bm_tags",       "penjuru_sysicon_sui_browse_tags" },
                    { "penjuru_sysicon_pg_chev_left",  "penjuru_sysicon_sui_pager_prev" },
                    { "penjuru_sysicon_pg_chev_right", "penjuru_sysicon_sui_pager_next" },
                    { "penjuru_sysicon_pg_chev_first", "penjuru_sysicon_sui_pager_first" },
                    { "penjuru_sysicon_pg_chev_last",  "penjuru_sysicon_sui_pager_last" },
                    { "penjuru_sysicon_coll_back",     "penjuru_sysicon_sui_coll_back" },
                }
                local migrated = 0
                for _, pair in ipairs(icon_renames) do
                    local old_k, new_k = pair[1], pair[2]
                    local val = PENSettings:get(old_k)
                    if val ~= nil then
                        if PENSettings:get(new_k) == nil then
                            PENSettings:set(new_k, val)
                        end
                        PENSettings:del(old_k)
                        migrated = migrated + 1
                    end
                end
                local icon_presets = PENSettings:get("penjuru_icon_presets")
                if type(icon_presets) == "table" then
                    local changed = false
                    for _, preset in pairs(icon_presets) do
                        if type(preset._scalar) == "table" then
                            for _, pair in ipairs(icon_renames) do
                                local old_k, new_k = pair[1], pair[2]
                                if preset._scalar[old_k] ~= nil then
                                    if preset._scalar[new_k] == nil then
                                        preset._scalar[new_k] = preset._scalar[old_k]
                                    end
                                    preset._scalar[old_k] = nil
                                    changed = true
                                end
                            end
                        end
                    end
                    if changed then PENSettings:set("penjuru_icon_presets", icon_presets) end
                end
                PENSettings:flush()
                logger.info("simpleui: settings migration v4 complete —", migrated, "icon keys renamed")
            end)
            PENSettings:set("penjuru_settings_migrated_v4", true)
            PENSettings:flush()
        end
        -- -------------------------------------------------------------------
        -- Settings migration v5: standardize titlebar button nomenclature
        -- -------------------------------------------------------------------
        if not PENSettings:isTrue("penjuru_settings_migrated_v5") then
            pcall(function()
                local renames = {
                    { "penjuru_tb_item_menu_button",     "penjuru_tb_item_fm_menu" },
                    { "penjuru_tb_item_up_button",       "penjuru_tb_item_fm_back" },
                    { "penjuru_tb_item_search_button",   "penjuru_tb_item_fm_search" },
                    { "penjuru_tb_item_browse_button",   "penjuru_tb_item_fm_browse" },
                    { "penjuru_tb_item_title",           "penjuru_tb_item_fm_title" },
                    { "penjuru_tb_item_inj_back",        "penjuru_tb_item_sub_menu" },
                    { "penjuru_tb_item_inj_right",       "penjuru_tb_item_sub_close" },
                    { "penjuru_tb_item_inj_menubutton",  "penjuru_tb_item_sub_menu" },
                    { "penjuru_tb_item_inj_closebutton", "penjuru_tb_item_sub_close" },
                    { "penjuru_tb_inj_cfg",              "penjuru_tb_sub_cfg" },
                }
                local migrated = 0
                for _, pair in ipairs(renames) do
                    local old_k, new_k = pair[1], pair[2]
                    local val = PENSettings:get(old_k)
                    if val ~= nil then
                        if PENSettings:get(new_k) == nil then
                            PENSettings:set(new_k, val)
                        end
                        PENSettings:del(old_k)
                        migrated = migrated + 1
                    end
                end

                local function map_cfg(cfg_key, mapping)
                    local cfg = PENSettings:get(cfg_key)
                    if type(cfg) == "table" then
                        local changed = false
                        local function map_arr(arr)
                            for i, v in ipairs(arr) do
                                if mapping[v] then arr[i] = mapping[v]; changed = true end
                            end
                        end
                        if type(cfg.side) == "table" then
                            for old_btn, new_btn in pairs(mapping) do
                                if cfg.side[old_btn] ~= nil then
                                    cfg.side[new_btn] = cfg.side[old_btn]
                                    cfg.side[old_btn] = nil
                                    changed = true
                                end
                            end
                        end
                        if type(cfg.order_left) == "table" then map_arr(cfg.order_left) end
                        if type(cfg.order_right) == "table" then map_arr(cfg.order_right) end
                        if changed then
                            PENSettings:set(cfg_key, cfg)
                            migrated = migrated + 1
                        end
                    end
                end

                local fm_map = {
                    menu_button   = "fm_menu",
                    up_button     = "fm_back",
                    search_button = "fm_search",
                    browse_button = "fm_browse",
                    title         = "fm_title"
                }
                local sub_map = {
                    inj_back         = "sub_menu",
                    inj_right        = "sub_close",
                    inj_menubutton   = "sub_menu",
                    inj_closebutton  = "sub_close"
                }
                map_cfg("penjuru_tb_fm_cfg", fm_map)
                map_cfg("penjuru_tb_sub_cfg", sub_map)

                logger.info("simpleui: settings migration v5 complete —", migrated, "titlebar keys renamed")
            end)
            PENSettings:set("penjuru_settings_migrated_v5", true)
            PENSettings:flush()
        end
        -- -------------------------------------------------------------------

        Config.applyFirstRunDefaults()
        Config.migrateOldCustomSlots()
        -- Always run sanitizeQASlots: it cleans both custom QA slot references
        -- and any stale built-in IDs from navbar_tabs.  The function is cheap —
        -- it reads a handful of settings and only writes back when it finds
        -- something invalid, so the common no-op case costs only a few reads.
        Config.sanitizeQASlots()
        -- Apply the saved UI font preference early, before any widget is built.
        -- SUIStyle is lazy (module-level init runs only when the font menu opens)
        -- so this pcall is cheap on the common path where no custom font is set.
        do
            local ok_ss, SUIStyle = pcall(require, "pen_style")
            if ok_ss and SUIStyle and SUIStyle.applyUIFont then
                pcall(SUIStyle.applyUIFont)
            end
        end
        self.ui.menu:registerToMainMenu(self)

        -- Register gesture-assignable actions via Dispatcher.
        -- After this, KOReader's gesture/keyboard settings will list these
        -- actions so the user can bind any gesture to them.
        Dispatcher:init()
        Dispatcher:registerAction("penjuru_go_homescreen", {
            category = "none",
            event    = "SimpleUIGoHomescreen",
            title    = _("Simple UI: Go to Homescreen"),
            general  = true,
        })
        Dispatcher:registerAction("penjuru_go_library", {
            category = "none",
            event    = "SimpleUIGoLibrary",
            title    = _("Simple UI: Go to Library"),
            general  = true,
        })
        Dispatcher:registerAction("penjuru_toggle_home_library", {
            category = "none",
            event    = "SimpleUIToggleHomeLibrary",
            title    = _("Simple UI: Toggle Homescreen / Library"),
            general  = true,
        })

        -- -------------------------------------------------------------------
        -- Icon registration: register the settings tab icon into KOReader's
        -- icon system at plugin init time (eager, not lazy).
        --
        -- This mirrors the approach used by Zen UI (common/inject_icons.lua):
        --   1. Resolve plugin_root to an ABSOLUTE path.  On some KOReader
        --      builds/devices debug.getinfo returns a relative source path
        --      (e.g. "plugins/simpleui.koplugin/main.lua"); without the
        --      lfs.currentdir() fix, every subsequent lfs.attributes() call
        --      fails silently and all three icon-injection strategies in
        --      sui_menu.lua are skipped, leaving the tab icon blank.
        --   2. Copy the SVG to DataStorage/icons/ (persistent, survives
        --      between sessions).  KOReader's ICONS_DIRS always includes
        --      that directory, so the icon resolves even if the runtime
        --      upvalue injection below fails (e.g. hardened builds).
        --   3. Inject the resolved path into IconWidget's ICONS_PATH and
        --      ICONS_DIRS upvalue caches so the icon is immediately available
        --      in the current session without needing a restart.
        --      Unlike sui_menu.lua's three-strategy approach, both caches are
        --      populated in a single upvalue scan (matching Zen UI's method).
        -- -------------------------------------------------------------------
        do
            -- Step 1: resolve plugin_root to an absolute path.
            local src = debug.getinfo(1, "S").source or ""
            local plugin_root = (src:sub(1, 1) == "@") and src:sub(2):match("^(.*)/[^/]+$") or nil
            if plugin_root and plugin_root:sub(1, 1) ~= "/" then
                local ok_lfs2, lfs2 = pcall(require, "libs/libkoreader-lfs")
                local cwd = ok_lfs2 and lfs2 and lfs2.currentdir()
                if cwd then plugin_root = cwd .. "/" .. plugin_root end
            end

            if plugin_root then
                local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
                if ok_lfs and lfs then
                    local icon_src = plugin_root .. "/icons/settings.svg"
                    if lfs.attributes(icon_src, "mode") == "file" then

                        -- Step 2: copy to DataStorage/icons/simpleui_settings.svg
                        -- so ICONS_DIRS disk lookup works even without upvalue injection.
                        pcall(function()
                            local DataStorage = require("datastorage")
                            local ffiutil     = require("ffi/util")
                            local user_dir    = DataStorage:getDataDir() .. "/icons"
                            if lfs.attributes(user_dir, "mode") ~= "directory" then
                                lfs.mkdir(user_dir)
                            end
                            local dst = user_dir .. "/simpleui_settings.svg"
                            if lfs.attributes(dst, "mode") ~= "file" then
                                ffiutil.copyFile(icon_src, dst)
                            end
                        end)

                        -- Step 3: inject into IconWidget's runtime upvalue caches.
                        -- Scan once, collect both ICONS_PATH and ICONS_DIRS together.
                        pcall(function()
                            local iw      = require("ui/widget/iconwidget")
                            local iw_init = rawget(iw, "init")
                            if type(iw_init) ~= "function" then return end
                            local icons_path, icons_dirs
                            for i = 1, 64 do
                                local uname, uval = debug.getupvalue(iw_init, i)
                                if uname == nil then break end
                                if uname == "ICONS_PATH" and type(uval) == "table" then
                                    icons_path = uval
                                elseif uname == "ICONS_DIRS" and type(uval) == "table" then
                                    icons_dirs = uval
                                end
                                if icons_path and icons_dirs then break end
                            end
                            if icons_path and not icons_path["penjuru_settings"] then
                                icons_path["penjuru_settings"] = icon_src
                            end
                            if icons_dirs then
                                local icons_subdir = plugin_root .. "/icons"
                                local already = false
                                for _, d in ipairs(icons_dirs) do
                                    if d == icons_subdir then already = true; break end
                                end
                                if not already then
                                    table.insert(icons_dirs, 1, icons_subdir)
                                end
                            end
                        end)

                    end
                end
            end
        end
        -- -------------------------------------------------------------------

        -- -------------------------------------------------------------------
        -- Tab injection: add a dedicated "Simple UI" tab to the KOReader menu
        -- bar (both FileManager and Reader), positioned right after the
        -- QuickSettings tab.  We patch setUpdateItemTable on the menu class
        -- once — the flag __sui_tab_patched prevents double-patching on
        -- subsequent plugin reloads within the same KOReader session.
        -- This mirrors the approach used by Zen UI.
        --
        -- sui_menu is loaded lazily: the pre-bootstrap buildTabItems below
        -- triggers require("pen_menu") on the first menu open, which registers
        -- the icon and installs the real buildTabItems before the tab is built.
        -- This removes sui_menu (and its lfs + IconWidget introspection) from
        -- the critical startup path.
        -- -------------------------------------------------------------------
        do
            -- buildTabItems: supplies the items array for the penjuru settings
            -- tab injected into the FileManager menu. D.0.2: returns empty list;
            -- D.1.1 will populate it from pen_menu.get_menu_items().
            if not rawget(penjuruPlugin, "buildTabItems") then
                penjuruPlugin.buildTabItems = function(_plugin_self)
                    return {}
                end
            end

            local plugin_self = self

            local function find_quicksettings_pos(tab_table)
                for i, tab in ipairs(tab_table) do
                    for _, field in ipairs({ "id", "name", "icon" }) do
                        local v = tab[field]
                        if type(v) == "string" then
                            local norm = v:lower():gsub("[%s_%-]+", "")
                            if norm == "quicksettings" then return i end
                        end
                    end
                end
                return nil
            end

            local function inject_sui_tab(menu_class)
                if not menu_class or menu_class.__sui_tab_patched then return end
                menu_class.__sui_tab_patched = true
                local orig_sut = menu_class.setUpdateItemTable
                menu_class.setUpdateItemTable = function(m_self)
                    orig_sut(m_self)
                    -- Respect the user's choice: default on (nilOrTrue), skip if explicitly false.
                    if not PENSettings:nilOrTrue("penjuru_settings_tab_enabled") then return end
                    if type(m_self.tab_item_table) ~= "table" then return end
                    local build_fn = rawget(penjuruPlugin, "buildTabItems")
                    if type(build_fn) ~= "function" then return end
                    local ok, tab_items = pcall(build_fn, plugin_self)
                    if not ok or type(tab_items) ~= "table" then return end
                    -- Mirror exactly how Zen UI does it: set icon as a field on
                    -- the items array itself (not a wrapper table), then insert
                    -- that array directly into tab_item_table.
                    tab_items.icon = "penjuru_settings"
                    local qs_pos     = find_quicksettings_pos(m_self.tab_item_table)
                    local insert_pos = qs_pos and (qs_pos + 1) or 1
                    table.insert(m_self.tab_item_table, insert_pos, tab_items)
                end
            end

            -- Inject the SUI tab only into FileManager (and HomeScreen), not into
            -- the Reader menu. The SimpleUI settings tab should not appear while
            -- a document is open.
            local ok_fm, FileManagerMenu = pcall(require, "apps/filemanager/filemanagermenu")
            if ok_fm and FileManagerMenu then inject_sui_tab(FileManagerMenu) end
        end
        -- -------------------------------------------------------------------
        if PENSettings:nilOrTrue("penjuru_enabled") then
            -- Patches.installAll removed (Plan D / D.0.1): legacy SimpleUI chrome injection
            -- caused TOTAL_H / scheduleRefresh errors on old singletons; chrome now lives
            -- in pen_homescreen.lua and needs no monkey-patches.
            -- TBR button registration removed: module_tbr out of scope for penjuru v1.
            -- (Plan B adds module_newly_catalogued as replacement.)

            -- "More by <Author>" button removed: sui_browsemeta out of scope for penjuru v1.

            -- Topbar.scheduleRefresh removed (Plan D / D.0.1): new pen_topbar is a pure
            -- render function; topbar refreshes via pen_homescreen on each open/resume.
            -- Pre-load ALL desktop modules during boot idle time so the first
            -- Homescreen open has no perceptible freeze. scheduleIn(2) runs
            -- after the FileManager UI is fully painted and stable.
            -- Registry.list() triggers _load() which pcall-requires all 9
            -- module_*.lua files — they land in package.loaded and subsequent
            -- require() calls are free table lookups, not disk I/O.
            UIManager:scheduleIn(2, function()
                local ok, reg = pcall(require, "desktop_modules/moduleregistry")
                if ok and reg then pcall(reg.list) end
            end)
            -- Auto-updater removed: sui_updater out of scope for penjuru v1.
            -- Patch ReaderStatistics:onSyncBookStats to close the SimpleUI
            -- stats connection before every sync, including syncs triggered
            -- from inside the Reader (where HomescreenWidget is not on the
            -- UIManager stack and therefore cannot handle the event itself).
            -- The HomescreenWidget:onSyncBookStats handler covers the common
            -- case; this patch is the safety net for the remaining paths
            -- (Reader menu → "Synchronize now", interval-based auto-sync).
            -- We apply it unconditionally at init time — no scheduleIn needed
            -- because PluginLoader has already initialised all plugins before
            -- SimpleUI:init() runs, so the RS class table is already in
            -- package.loaded.
            do
                local ok_rs, RS = pcall(require, "plugins/statistics.koplugin/main")
                if ok_rs and RS and RS.onSyncBookStats and not RS._sui_sync_patched then
                    local orig_onSyncBookStats = RS.onSyncBookStats
                    RS._sui_orig_onSyncBookStats = orig_onSyncBookStats
                    RS._sui_sync_patched         = true
                    RS.onSyncBookStats = function(self_rs, ...)
                        -- Close the HomescreenWidget DB connection synchronously,
                        -- before ReaderStatistics defers the actual sync to nextTick.
                        -- Homescreen._instance is the singleton ref used everywhere
                        -- in sui_homescreen.lua — no UIManager stack walk needed.
                        local hs = Homescreen and Homescreen._instance
                        if hs then
                            if hs._db_conn then
                                pcall(function() hs._db_conn:close() end)
                                hs._db_conn = nil
                            end
                            -- Guard prevents _buildCtx from reopening the connection
                            -- during the window between this call and the nextTick
                            -- sync.  Cleared two ticks later (after sync completes).
                            hs._db_sync_guard = true
                            local hs_ref = hs
                            UIManager:tickAfterNext(function()
                                UIManager:nextTick(function()
                                    if Homescreen._instance ~= hs_ref then return end
                                    hs_ref._db_sync_guard = false
                                    hs_ref._ctx_cache     = nil
                                    hs_ref:_refresh(false)
                                end)
                            end)
                        end
                        return orig_onSyncBookStats(self_rs, ...)
                    end
                end
            end
        end
    end)
    if not ok then logger.err("simpleui: init failed:", tostring(err)) end

    -- KUAL auto-open: if /mnt/us/extensions/penjuru/run.sh launched
    -- KOReader, it dropped a flag file in the settings dir. Open the
    -- home overlay immediately after KOReader finishes initializing.
    -- The flag is consumed (deleted) so a normal restart doesn't fire.
    do
        local ok_ds, DataStorage = pcall(require, "datastorage")
        local ok_lfs, lfs = pcall(require, "libs/libkoreader-lfs")
        if ok_ds and ok_lfs then
            local flag_path = DataStorage:getSettingsDir() .. "/penjuru-autoopen.flag"
            if lfs.attributes(flag_path) then
                os.remove(flag_path)
                local ok_uim, UIManager = pcall(require, "ui/uimanager")
                if ok_uim then
                    UIManager:scheduleIn(1.0, function()
                        local ok_hs, Home = pcall(require, "pen_homescreen")
                        if ok_hs and Home and Home.show then
                            pcall(Home.show)
                        end
                    end)
                end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- List of all plugin-owned Lua modules that must be evicted from
-- package.loaded on teardown so that a hot plugin update (replacing files
-- without restarting KOReader) always loads fresh code.
-- ---------------------------------------------------------------------------
local _PLUGIN_MODULES = {
    "pen_i18n", "pen_config", "pen_core", "pen_bottombar", "pen_topbar",
    -- "pen_patches" removed (Plan D / D.0.1): stashed as pen_patches.lua.old_simpleui
    "pen_menu", "pen_titlebar", "pen_quickactions",
    "pen_homescreen",
    -- removed: sui_foldercovers, sui_browsemeta, sui_updater, sui_presets (out of scope)
    "pen_store", "pen_style",
    "desktop_modules/moduleregistry",
    "desktop_modules/module_books_shared",
    "desktop_modules/module_clock",
    "desktop_modules/module_collections",
    "desktop_modules/module_currently",
    "desktop_modules/module_quick_actions",
    -- removed: module_quote (replaced by module_highlights in Plan B)
    "desktop_modules/module_reading_goals",
    "desktop_modules/module_reading_stats",
    "desktop_modules/module_stats_provider",
    "desktop_modules/module_recent",
    -- removed: module_tbr (replaced by module_newly_catalogued in Plan B)
    -- removed: desktop_modules/quotes (replaced by user-highlight quotes)
}

-- ---------------------------------------------------------------------------
-- Dispatcher gesture handlers
-- ---------------------------------------------------------------------------

-- Called when the user triggers the "Go to Homescreen" gesture.
-- v1.2.7: pure-overlay model. The penjuru home is a fullscreen
-- InputContainer (covers_fullscreen=true) — pushing it onto the
-- UIManager stack paints over whatever's beneath without disturbing it.
-- Tap-to-dismiss closes the overlay and reveals the original view.
--
-- v1.2.6 closed RUI.instance before showing the home, which made the
-- gesture exit KOReader entirely on devices where the reader was the
-- only widget on the stack (e.g. KUAL-launched, start_with=last_file):
-- onClose() had nothing to fall back to and dropped the user at the
-- Kindle home screen (KUAL).
function penjuruPlugin:onSimpleUIGoHomescreen()
    local ok, Home = pcall(require, "pen_homescreen")
    if ok and Home and Home.show then pcall(Home.show) end
    return true
end

-- Called when the user triggers the "Go to Library" gesture.
-- When outside the Reader: equivalent to tapping the Library tab.
-- NOTE (Plan D / D.0.1): reader-close path (Patches.closeReaderToLibrary)
-- removed with pen_patches. Reader gestures fall through to FM-side navigate.
function penjuruPlugin:onSimpleUIGoLibrary()
    local RUI = package.loaded["apps/reader/readerui"]
    if RUI and RUI.instance then
        -- Patches.closeReaderToLibrary removed (Plan D / D.0.1)
        self._closing_via_gesture = true
        RUI.instance:onClose()
    end
    local tabs = Config.loadTabConfig()
    self:_navigate("home", self.ui, tabs, false)
    return true
end

-- Called when the user triggers the "Toggle Homescreen / Library" gesture.
-- v1.2.7: same overlay model — toggling reduces to "if home is visible,
-- dismiss it; otherwise overlay it on top of whatever's there."
function penjuruPlugin:onSimpleUIToggleHomeLibrary()
    local HS = package.loaded["pen_homescreen"]
    if HS and HS._instance and HS.close then
        pcall(HS.close)
        return true
    end
    local ok, Home = pcall(require, "pen_homescreen")
    if ok and Home and Home.show then pcall(Home.show) end
    return true
end

function penjuruPlugin:onTeardown()
    -- Flush the plugin settings store so any in-memory writes are persisted
    -- before the plugin is unloaded or KOReader exits.
    PENSettings:flush()
    if self._topbar_timer then
        UIManager:unschedule(self._topbar_timer)
        self._topbar_timer = nil
    end
    -- Patches.teardownAll removed (Plan D / D.0.1): no monkey-patches to reverse
    I18n.uninstall()
    -- Give modules with internal upvalue caches a chance to nil them before
    -- their package.loaded entry is cleared — ensures the GC can collect the
    -- old tables immediately rather than waiting for the upvalue to be rebound.
    local mod_recent = package.loaded["desktop_modules/module_recent"]
    if mod_recent and type(mod_recent.reset) == "function" then
        pcall(mod_recent.reset)
    end
    -- module_tbr teardown removed: out of scope for penjuru v1
    -- TBR/BrowseAuthor dialog button teardown removed: out of scope for penjuru v1
    local mod_rg = package.loaded["desktop_modules/module_reading_goals"]
    if mod_rg and type(mod_rg.reset) == "function" then
        pcall(mod_rg.reset)
    end
    -- sui_browsemeta teardown removed: out of scope for penjuru v1
    -- Evict all plugin modules from the Lua module cache so that a hot update
    -- (files replaced on disk without restarting KOReader) picks up new code
    -- on the next plugin load, instead of reusing the old in-memory versions.
    -- Nil buildTabItems so its upvalue cache is released and the patch can
    -- rebuild fresh on next plugin load.
    penjuruPlugin.buildTabItems = nil
    -- Clear the tab-injection flag so the patch can be re-applied if the
    -- plugin is reloaded within the same KOReader session.
    local fm_menu = package.loaded["apps/filemanager/filemanagermenu"]
    if fm_menu then fm_menu.__sui_tab_patched = nil end
    -- Restore the ReaderStatistics:onSyncBookStats patch.
    local RS = package.loaded["plugins/statistics.koplugin/main"]
    if RS and RS._sui_sync_patched then
        if RS._sui_orig_onSyncBookStats then
            RS.onSyncBookStats = RS._sui_orig_onSyncBookStats
            RS._sui_orig_onSyncBookStats = nil
        end
        RS._sui_sync_patched = nil
    end
    for _, mod in ipairs(_PLUGIN_MODULES) do
        package.loaded[mod] = nil
    end
end

-- ---------------------------------------------------------------------------
-- System events
-- ---------------------------------------------------------------------------

function penjuruPlugin:onScreenResize()
    if self._penjuru_suspended then return end
    UI.invalidateDimCache()
    UIManager:scheduleIn(0.2, function()
        if self._penjuru_suspended then return end
        local RUI = package.loaded["apps/reader/readerui"]
        if RUI and RUI.instance then return end

        -- If the homescreen is open, close and reopen it so HomescreenWidget:new
        -- runs with the new screen dimensions. rewrapAllWidgets cannot resize it
        -- correctly because its layout is built entirely in init(), not via
        -- wrapWithNavbar — the same reason FM uses reinit() (= rotate()) instead
        -- of a simple rewrap.
        local HS = package.loaded["pen_homescreen"]
        if HS and HS._instance then
            local hs_inst = HS._instance
            hs_inst._navbar_closing_intentionally = true
            pcall(function() UIManager:close(hs_inst) end)
            hs_inst._navbar_closing_intentionally = nil
            if not self._goalTapCallback then self:addToMainMenu({}) end
            local tabs = Config.loadTabConfig()
            Bottombar.setActiveAndRefreshFM(self, "homescreen", tabs)
            HS.show(
                function(aid) self:_navigate(aid, self.ui, Config.loadTabConfig(), false) end,
                self._goalTapCallback
            )
            return
        end

        self:_rewrapAllWidgets()
        self:_refreshCurrentView()
    end)
end
function penjuruPlugin:onNetworkConnected()
    if self._penjuru_suspended then return end
    local RUI = package.loaded["apps/reader/readerui"]
    -- If this event was fired by doWifiToggle itself, wifi_optimistic is already
    -- set correctly and the bars are already rebuilt. Skip the reset so the
    -- optimistic icon is preserved (on Kindle isWifiOn() may lag behind).
    -- Still call _refreshCurrentView to rebuild homescreen QA icons.
    if not Config.wifi_broadcast_self then
        Config.wifi_optimistic = nil
    end
    if RUI and RUI.instance then
        self:_rebuildAllNavbars()
    else
        Bottombar.refreshWifiIcon(self)
    end
end

function penjuruPlugin:onNetworkDisconnected()
    if self._penjuru_suspended then return end
    local RUI = package.loaded["apps/reader/readerui"]
    -- Same rationale as onNetworkConnected above.
    if not Config.wifi_broadcast_self then
        Config.wifi_optimistic = nil
    end
    if RUI and RUI.instance then
        self:_rebuildAllNavbars()
    else
        Bottombar.refreshWifiIcon(self)
    end
end

function penjuruPlugin:onSuspend()
    self._penjuru_suspended = true
    -- Snapshot whether the reader was open at the moment of suspend.
    -- We cannot rely on RUI.instance being intact by the time onResume fires
    -- (e.g. autosuspend can race with a reader teardown on some Kobo builds),
    -- so we capture the truth here, while the world is still settled.
    local RUI = package.loaded["apps/reader/readerui"]
    self._simpleui_reader_was_active = (RUI and RUI.instance) and true or false
    if self._topbar_timer then
        UIManager:unschedule(self._topbar_timer)
        self._topbar_timer = nil
    end
end

function penjuruPlugin:onResume()
    self._penjuru_suspended = false
    -- Topbar.scheduleRefresh removed (Plan D / D.0.1): topbar refreshes via
    -- pen_homescreen on each open; no standalone refresh timer in new arch.
    -- Use the snapshot captured in onSuspend rather than checking RUI.instance
    -- live. On some Kobo builds the autosuspend timer fires close to a reader
    -- teardown, leaving RUI.instance nil even though the user was reading —
    -- causing the homescreen to open on wakeup instead of returning to the reader.
    local reader_active = self._simpleui_reader_was_active
    self._simpleui_reader_was_active = nil  -- consume; next suspend will repopulate
    -- Outside the reader: restore the Homescreen.
    -- RS and RG have a built-in date-key guard (_stats_cache_day): they re-query
    -- automatically on a new calendar day and serve the in-memory cache otherwise.
    -- Explicit invalidation here would force full SQL queries on every wakeup
    -- even when nothing changed. Data changes from reading are handled by
    -- onCloseDocument, which invalidates those caches before the next render.
    if not reader_active then
        local HS = package.loaded["pen_homescreen"]
        if HS and HS._instance then
            -- Refresh the QA tap callback on the live homescreen instance.
            -- If the device suspended while the homescreen (or the touch menu
            -- floating on top of it) was open, HS._instance survives but its
            -- _on_qa_tap closure may reference a stale FileManager object.
            -- Reassigning it here ensures QA buttons work on the very first
            -- tap after wakeup, without requiring the user to navigate away
            -- and reopen the homescreen.
            local plugin_ref = self
            HS._instance._on_qa_tap = function(aid)
                plugin_ref:_navigate(aid, plugin_ref.ui, Config.loadTabConfig(), false)
            end
            HS.refresh(true)
        end
        -- Re-open the Homescreen on wakeup when "Start with Homescreen" is set.
        -- Patches.showHSAfterResume removed (Plan D / D.0.1): wakeup-HS logic
        -- was part of pen_patches chrome injection; will be re-implemented
        -- without monkey-patches in a later Plan D task.
    end
end

function penjuruPlugin:onCloseDocument()
    -- Consume _closing_via_gesture unconditionally before any early return,
    -- so the flag never leaks to a subsequent close if this handler bails out
    -- (e.g. while the plugin is suspended).
    local via_gesture = self._closing_via_gesture
    self._closing_via_gesture = nil

    if self._penjuru_suspended then return end
    local HS = package.loaded["pen_homescreen"]
    if not HS then return end

    -- Show a brief "closing book" notice whenever a book is closed.
    -- onCloseDocument is the single, authoritative place for this: it fires on
    -- every close path (menu, gesture, or any direct call to ReaderUI:onClose).
    --
    -- How the three modes work:
    --   "always"       — show on every book close, regardless of how it was
    --                    triggered or where the user ends up afterwards.
    --   "gesture_only" — show only when the close was triggered by a SimpleUI
    --                    gesture (GoHomescreen, GoLibrary, ToggleHomeLibrary).
    --                    Those paths set plugin._closing_via_gesture = true
    --                    immediately before readerui:onClose(). We read and
    --                    clear that flag above. Menu-triggered closes never set
    --                    the flag — no KOReader internals patched.
    --   "never"        — never show.
    --
    -- The notice is shown while readerui.dialog is still on the widget stack
    -- (i.e. the book page is still the background). forceRePaint pushes it to
    -- the e-ink screen immediately; without it _repaint() only runs on the next
    -- event-loop tick, after closeDocument() and UIManager:close(dialog) have
    -- already run, so the notice would appear over the FM/HS far too late.
    -- timeout=0.0 schedules the InfoMessage to close itself on the next tick.
    --
    -- Migration: if simpleui_hs_closing_notice_mode is absent, fall back to the
    -- old boolean simpleui_hs_closing_notice (nil/true → "always", false → "never").
    do
        local notice_mode = PENSettings:readSetting("penjuru_hs_closing_notice_mode")
        if not notice_mode then
            notice_mode = PENSettings:nilOrTrue("penjuru_hs_closing_notice") and "always" or "never"
        end

        if notice_mode == "always"
                or (notice_mode == "gesture_only" and via_gesture) then
            -- UIManager:show() respects honor_silent_mode on InfoMessage, which
            -- means the notice is silently dropped when the Dispatcher has put
            -- the UIManager into silent mode to batch multiple gesture actions.
            -- We bypass silent mode here by temporarily clearing it, showing the
            -- notice and flushing it to the screen, then restoring the flag.
            -- This is safe because forceRePaint() runs synchronously and the
            -- InfoMessage is a non-blocking toast (timeout=0.0 auto-closes it);
            -- no other widget draw or event dispatch occurs between the two lines.
            local was_silent = UIManager:isInSilentMode()
            if was_silent then UIManager:setSilentMode(false) end
            UIManager:show(InfoMessage:new{
                text    = _("Closing book…"),
                timeout = 0.0,
            })
            UIManager:forceRePaint()
            if was_silent then UIManager:setSilentMode(true) end
        end
    end

    -- Fast-path: if the HS is not visible and is already flagged for rebuild,
    -- there is nothing further to do — the next Homescreen.show() will rebuild
    -- from scratch. Avoids loading the Registry and all module pcalls.
    if not HS._instance and HS._stats_need_refresh then
        -- Topbar.scheduleRefresh removed (Plan D / D.0.1)
        return
    end

    -- Registry is already loaded (moduleregistry was pre-loaded at boot via
    -- scheduleIn(2)); use package.loaded to avoid a pcall on the hot path.
    -- Fall back to pcall only if it hasn't been loaded yet.
    local Registry = package.loaded["desktop_modules/moduleregistry"]
    if not Registry then
        local ok, reg = pcall(require, "desktop_modules/moduleregistry")
        if not ok then return end
        Registry = reg
    end

    local PFX = "penjuru_hs_"
    local needs_refresh    = false
    local currently_active = false

    -- Only call pcall(require) for modules that are actually enabled.
    -- Registry.get + Registry.isEnabled are cheap table lookups; the module
    -- is guaranteed already loaded when enabled (required by the HS on open).

    -- Determine the filepath of the book that just closed.
    -- readhistory.hist[1] is still the closing book at this point (the reader
    -- has not yet handed control back to the FM, so the history order has not
    -- been updated).
    local rh         = package.loaded["readhistory"]
    local closed_fp  = rh and rh.hist and rh.hist[1] and rh.hist[1].file

    -- Invalidate the shared stats provider when either stats module is active.
    -- One SP.invalidate() covers both reading_goals and reading_stats — they
    -- both read ctx.stats which is populated from StatsProvider.get().
    --
    -- Optimisation: SP contains two parts — DB time-series (always stale after
    -- a reading session) and books_year/books_total (sidecar scan, expensive).
    -- The sidecar-derived counts only change when the closed book's
    -- summary.status transitions to or from "complete". We detect this by
    -- comparing the cached pre-session status (from SH._cacheGet, still valid
    -- at this point) with the on-disk status (one DS.open on the closed book).
    -- If neither was "complete" and neither is now, the counts are unchanged
    -- and we can spare the full SP.invalidate() — instead we call
    -- SP.invalidateTimeSeries() which discards only the DB-derived fields,
    -- leaving books_year/books_total intact in the cache.
    local mod_rg = Registry.get("reading_goals")
    local mod_rs = Registry.get("reading_stats")
    local stats_active = (mod_rg and Registry.isEnabled(mod_rg, PFX))
        or (mod_rs and mod_rs.isEnabled and mod_rs.isEnabled(PFX))

    if not stats_active then
        for _, mod in ipairs(Registry.list()) do
            if mod.needs and mod.needs.stats and Registry.isEnabled(mod, PFX) then
                stats_active = true
                break
            end
        end
    end

    if stats_active then
        local SP = package.loaded["desktop_modules/module_stats_provider"]
        if SP then
            local status_changed = true  -- default: full invalidation (safe)
            if closed_fp and SP.invalidateTimeSeries then
                local SH = package.loaded["desktop_modules/module_books_shared"]
                -- Pre-session status: read from sidecar cache (no I/O).
                -- The cache entry is still valid here — SH.invalidateSidecarCache
                -- for closed_fp runs later in this function, after this block.
                local pre_status
                if SH and SH._cacheGet then
                    local cached = SH._cacheGet(closed_fp)
                    local s = cached and cached.summary
                    pre_status = type(s) == "table" and s.status or nil
                end
                -- Post-session status: one DS.open on the closed book only.
                local post_status
                local ok_DS, DocSettings = pcall(require, "docsettings")
                if ok_DS then
                    local ok_ds, ds = pcall(function()
                        return DocSettings:open(closed_fp)
                    end)
                    if ok_ds and ds then
                        local s = ds:readSetting("summary")
                        post_status = type(s) == "table" and s.status or nil
                        pcall(function() ds:close() end)
                    end
                end
                -- Status changed only when a "complete" boundary was crossed.
                -- Both nil/non-complete pre and post → counts are unaffected.
                local pre_complete  = pre_status  == "complete"
                local post_complete = post_status == "complete"
                status_changed = pre_complete ~= post_complete
            end

            if status_changed then
                SP.invalidate()
            elseif SP.invalidateTimeSeries then
                -- Counts unchanged: only discard DB-derived fields (time, pages,
                -- streak). books_year/books_total survive in the cache intact.
                SP.invalidateTimeSeries()
            else
                -- SP.invalidateTimeSeries not available (older version): fall back.
                SP.invalidate()
            end
            needs_refresh = true
        end
    end

    -- Currently Reading shows the current book's cover, title, author and
    -- progress (percent_finished). All of these come from _cached_books_state.
    -- When the reader closes, percent_finished has changed for the closed book.
    -- Instead of discarding the entire _cached_books_state (which forces
    -- prefetchBooks() to re-open every sidecar), we do a surgical invalidation:
    -- only the entry for the closed book is removed from prefetched_data.
    -- prefetchBooks() will then re-open exactly one sidecar (the closed book)
    -- and reuse the mtime-validated sidecar cache for all other entries.
    -- Read the md5 of the closing book once — used by both Currently Reading
    -- and Cover Deck for surgical stats-cache invalidation.
    local closed_md5
    if closed_fp then
        local bs_pre = (HS._instance and HS._instance._cached_books_state)
                    or HS._cached_books_state
        local pe = bs_pre and bs_pre.prefetched_data
                and bs_pre.prefetched_data[closed_fp]
        closed_md5 = pe and pe.partial_md5_checksum
    end

    -- Currently Reading: invalidate book data so the next render shows fresh
    -- progress. Uses surgical invalidation to avoid re-opening every sidecar.
    local mod_cr = Registry.get("currently")
    currently_active = mod_cr and Registry.isEnabled(mod_cr, PFX) or false
    -- module_coverdeck removed: out of scope for penjuru v1
    local coverdeck_active = false
    if currently_active then
        -- Surgical invalidation: drop only the closed book's entry so
        -- prefetchBooks() re-reads exactly one sidecar, cache-hitting the rest.
        local function _partial_invalidate(bs)
            if not bs then return end
            -- Drop the entry for the closed book so prefetchBooks() re-reads it.
            if bs.prefetched_data and closed_fp then
                bs.prefetched_data[closed_fp] = nil
            end
            -- current_fp will be re-resolved by the next prefetchBooks() call.
            -- Setting it to nil ensures Currently Reading does not paint
            -- stale progress data before the refresh completes.
            bs.current_fp = nil
        end
        if HS._instance then
            _partial_invalidate(HS._instance._cached_books_state)
            _partial_invalidate(HS._cached_books_state)
        end
        -- When the homescreen is not visible (HS._instance == nil), the partially
        -- invalidated HS._cached_books_state (with current_fp=nil) would be passed
        -- to the next HomescreenWidget:new{} in Homescreen.show(). Because the
        -- state is non-nil, _buildCtx() skips prefetchBooks() entirely, leaving
        -- ctx.current_fp = nil and causing Currently Reading to disappear.
        -- Fix: discard the shared cached state so _buildCtx() is forced to call
        -- prefetchBooks() from scratch on the next Homescreen.show().
        if not HS._instance then
            HS._cached_books_state = nil
        end
        local MC = package.loaded["desktop_modules/module_currently"]
        if MC and MC.invalidateCache then MC.invalidateCache() end
        needs_refresh = true
    end

    -- coverdeck block removed: module_coverdeck out of scope for penjuru v1

    if not needs_refresh then return end

    local book_mod_active = currently_active or coverdeck_active

    -- Invalidate the sidecar mtime-cache entry for the closed book only when
    -- a book module is active — prefetchBooks() will re-read it on next render.
    -- Stats-only path never calls prefetchBooks, so no sidecar work is needed.
    -- Guard: only invalidate surgically when closed_fp is known; a nil fp would
    -- flush the entire cache, discarding valid entries for all other books.
    if book_mod_active and closed_fp then
        local SH = package.loaded["desktop_modules/module_books_shared"]
        if SH and SH.invalidateSidecarCache then
            SH.invalidateSidecarCache(closed_fp)
        end
    end

    if HS._instance then
        -- Determine what changed and use the narrowest refresh that covers it:
        --   books_only  → book module(s) active; prefetchBooks() must re-run.
        --   stats_only  → only stats modules active; SP.get() must re-run but
        --                  no sidecar I/O is needed (_cached_books_state kept).
        -- keep_cache is always false — we never want to reuse a stale _ctx_cache.
        HS.refresh(false, book_mod_active, not book_mod_active)
    else
        -- Homescreen not visible yet — flag it for rebuild on next open.
        HS._stats_need_refresh = true
    end

    -- Topbar.scheduleRefresh removed (Plan D / D.0.1): topbar clock refresh
    -- was a legacy pen_patches timer chain; new arch refreshes via pen_homescreen.
end

-- ---------------------------------------------------------------------------
-- onBookMetadataChanged — fired by KOReader when the user edits a book's
-- title, author, or other doc_props via "Book information" → "Set custom".
--
-- SimpleUI reads title/author from the sidecar's doc_props via prefetchBooks()
-- and caches the result in both the sidecar mtime-cache (_sidecar_cache in
-- module_books_shared) and the homescreen's _cached_books_state table.
--
-- Without this handler, editing metadata has no visible effect on the
-- Currently Reading (and Recent) modules: _cached_books_state is never
-- cleared, so prefetchBooks() is never re-called, and the old stale values
-- are shown even though the sidecar on disk is already correct.
--
-- Fix: when BookMetadataChanged fires, flush the sidecar cache entirely (we
-- don't know which file was edited from the event alone; prop_updated carries
-- a filepath key in some call-sites but not all, so a full flush is safest
-- and cheap — it only costs one extra DS.open on the next render), discard
-- _cached_books_state to force a full prefetchBooks() pass, and schedule a
-- homescreen refresh so the corrected metadata appears immediately.
-- ---------------------------------------------------------------------------
function penjuruPlugin:onBookMetadataChanged(_prop_updated)
    if self._penjuru_suspended then return end

    local HS = package.loaded["pen_homescreen"]
    if not HS then return end

    -- Flush the entire sidecar mtime-cache.  The next prefetchBooks() will
    -- re-open each sidecar and repopulate the cache from fresh disk state.
    local SH = package.loaded["desktop_modules/module_books_shared"]
    if SH and SH.invalidateSidecarCache then
        SH.invalidateSidecarCache()  -- nil → flush all
    end

    -- Discard the cached prefetch state on both the class and any live
    -- instance so _buildCtx() is forced to call prefetchBooks() from scratch.
    if HS._instance then
        HS._instance._cached_books_state = nil
    end
    HS._cached_books_state = nil

    -- Trigger a homescreen refresh (keep_cache=false, books_only=true).
    if HS._instance then
        HS.refresh(false, true)
    end
end

function penjuruPlugin:onFrontlightStateChanged()
    -- Topbar.scheduleRefresh removed (Plan D / D.0.1)
end

function penjuruPlugin:onCharging()
    -- Topbar.scheduleRefresh removed (Plan D / D.0.1)
end

function penjuruPlugin:onNotCharging()
    -- Topbar.scheduleRefresh removed (Plan D / D.0.1)
end

-- ---------------------------------------------------------------------------
-- Topbar delegation (Plan D / D.0.1: scheduleRefresh / registerTouchZones
-- removed — new pen_topbar is a pure render function; no timer chain or
-- touch-zone registration needed; topbar refreshes via pen_homescreen)
-- ---------------------------------------------------------------------------

function penjuruPlugin:_registerTouchZones(fm_self)
    -- Bottombar.registerTouchZones removed (Plan D / D.0.1)
    -- Topbar.registerTouchZones removed (Plan D / D.0.1)
end

function penjuruPlugin:_scheduleTopbarRefresh(delay)
    -- Topbar.scheduleRefresh removed (Plan D / D.0.1)
end

function penjuruPlugin:_refreshTopbar()
    -- Topbar.refresh removed (Plan D / D.0.1)
end

-- ---------------------------------------------------------------------------
-- Bottombar delegation
-- ---------------------------------------------------------------------------

function penjuruPlugin:_onTabTap(action_id, fm_self)
    Bottombar.onTabTap(self, action_id, fm_self)
end

function penjuruPlugin:_navigate(action_id, fm_self, tabs, force)
    Bottombar.navigate(self, action_id, fm_self, tabs, force)
end

function penjuruPlugin:_refreshCurrentView()
    local tabs      = Config.loadTabConfig()
    local action_id = self.active_action or tabs[1] or "home"
    self:_navigate(action_id, self.ui, tabs)
end

function penjuruPlugin:_rebuildAllNavbars()
    Bottombar.rebuildAllNavbars(self)
end

function penjuruPlugin:_rewrapAllWidgets()
    Bottombar.rewrapAllWidgets(self)
end

function penjuruPlugin:_restoreTabInFM(tabs, prev_action)
    Bottombar.restoreTabInFM(self, tabs, prev_action)
end

function penjuruPlugin:_setPowerTabActive(active, prev_action)
    Bottombar.setPowerTabActive(self, active, prev_action)
end

function penjuruPlugin:_showPowerDialog(fm_self)
    Bottombar.showPowerDialog(self, fm_self)
end

function penjuruPlugin:_doWifiToggle()
    Bottombar.doWifiToggle(self)
end

function penjuruPlugin:_doRotateScreen()
    Bottombar.doRotateScreen()
end

function penjuruPlugin:_showFrontlightDialog()
    Bottombar.showFrontlightDialog()
end

function penjuruPlugin:_scheduleRebuild()
    if self._rebuild_scheduled then return end
    self._rebuild_scheduled = true
    UIManager:scheduleIn(0.1, function()
        self._rebuild_scheduled = false
        self:_rebuildAllNavbars()
    end)
end

function penjuruPlugin:_updateFMHomeIcon() end

-- ---------------------------------------------------------------------------
-- Main menu entry
-- ---------------------------------------------------------------------------

function penjuruPlugin:addToMainMenu(menu_items)
    local _ = require("pen_i18n").translate
    local ok, PenMenu = pcall(require, "pen_menu")
    local sub_items = (ok and PenMenu.get_menu_items()) or {}
    if not ok then
        logger.err("penjuru: pen_menu failed to load: " .. tostring(PenMenu))
    end
    menu_items.penjuru = {
        text = _("penjuru"),
        sorting_hint = "tools",
        sub_item_table = sub_items,
    }
end

return penjuruPlugin