-- module_reading_stats.lua — Simple UI
-- Reading Stats module: row of stat cards (today, averages, totals, streak).

local Blitbuffer      = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local GestureRange    = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InputContainer  = require("ui/widget/container/inputcontainer")
local LineWidget      = require("ui/widget/linewidget")
local OverlapGroup    = require("ui/widget/overlapgroup")
local TextWidget      = require("ui/widget/textwidget")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local Screen          = Device.screen
local _ = require("sui_i18n").translate
local Config          = require("sui_config")

local UI      = require("sui_core")
local SUISettings = require("sui_store")
local CLR_TEXT_SUB = UI.CLR_TEXT_SUB
local PAD     = UI.PAD
local MOD_GAP = UI.MOD_GAP
local LABEL_H = UI.LABEL_H

local _CLR_TEXT_BLK  = Blitbuffer.COLOR_BLACK
local _CLR_CARD_BDR  = Blitbuffer.gray(0.72)

local _BASE_RS_CORNER_R = Screen:scaleBySize(12)
local _BASE_RS_GAP      = Screen:scaleBySize(12)
local _BASE_RS_CARD_H   = Screen:scaleBySize(96)
local _BASE_RS_VAL_FS   = Screen:scaleBySize(14)
local _BASE_RS_LBL_FS   = Screen:scaleBySize(8)
local _BASE_RS_SEP_W    = Screen:scaleBySize(1)
local _BASE_RS_PH_FS    = Screen:scaleBySize(11)  -- placeholder "No stats" text

local RS_N_COLS    = 7  -- max columns — not a dimension, no scaling needed

local SETTING_TYPE  = "reading_stats_type"   -- suffix: pfx .. "reading_stats_type"
local SETTING_ALIGN = "reading_stats_align"  -- suffix: pfx .. "reading_stats_align"

local function getType(pfx)
    return SUISettings:readSetting(pfx .. SETTING_TYPE) or "cards"
end

local function getAlign(pfx)
    local v = SUISettings:readSetting(pfx .. SETTING_ALIGN)
    if v == "left" or v == "right" or v == "center" then return v end
    return "center"
end

local function alignLabel(align)
    if align == "left"  then return _("Left")  end
    if align == "right" then return _("Right") end
    return _("Center")
end

-- ---------------------------------------------------------------------------
-- Stat map
-- ---------------------------------------------------------------------------
local function fmtTime(secs)
    secs = math.floor(secs or 0)
    if secs <= 0 then return "0m" end
    local h = math.floor(secs / 3600); local m = math.floor((secs % 3600) / 60)
    if h > 0 and m > 0 then return string.format("%dh %dm", h, m)
    elseif h > 0        then return string.format("%dh", h)
    else                     return string.format("%dm", m) end
end

local STAT_MAP = {
    today_time  = { display_label = _("Today — Time"),      value = function(s) return fmtTime(s.today_secs) end,   label = _("of reading today") },
    today_pages = { display_label = _("Today — Pages"),     value = function(s) return tostring(s.today_pages) end, label = _("pages read today") },
    avg_time    = { display_label = _("Daily avg — Time"),  value = function(s) return fmtTime(s.avg_secs) end,     label = _("daily avg (7 days)") },
    avg_pages   = { display_label = _("Daily avg — Pages"), value = function(s) return tostring(s.avg_pages) end,   label = _("pages/day (7 days)") },
    total_time  = { display_label = _("All time — Time"),   value = function(s) return fmtTime(s.total_secs) end,   label = _("of reading, all time") },
    total_books = { display_label = _("All time — Books"),  value = function(s) return tostring(s.total_books) end, label = _("books finished") },
    streak      = { display_label = _("Streak"),            value = function(s) return s.streak > 0 and tostring(s.streak) or "—" end,
                    label_fn = function(s) return s.streak == 1 and _("day streak") or (s.streak == 0 and _("no streak") or _("days streak")) end },
}

local STAT_POOL = { "today_time","today_pages","avg_time","avg_pages","total_time","total_books","streak" }

-- Pre-sort the pool alphabetically by display label — done once at module load,
-- not on every menu open.
local _sorted_pool = {}
for _, sid in ipairs(STAT_POOL) do
    _sorted_pool[#_sorted_pool+1] = { id = sid, label = STAT_MAP[sid].display_label }
end
table.sort(_sorted_pool, function(a, b) return a.label:lower() < b.label:lower() end)

-- ---------------------------------------------------------------------------
-- Stat widget builders
-- ---------------------------------------------------------------------------

-- Cards mode: rounded border, content aligned inside the card.
-- `d` is the scaled-dims table produced once per M.build() call.
-- Streak value widget: icon (dark grey) + space + number (black), side by side.
-- To change icon colour: edit _STREAK_ICON_CLR.
-- To change spacing:     edit _STREAK_ICON_GAP.
local _STREAK_ICON     = ""            -- U+F490 Nerd Fonts flame
local _STREAK_ICON_CLR = Blitbuffer.gray(0.80)  -- dark grey; 0=black, 1=white
local _STREAK_ICON_GAP = 6                   -- pixels between icon and number

local function makeStreakValWidget(val_str, d, clr_blk)
    return HorizontalGroup:new{ align = "center",
        UI.makeColoredText{
            text    = _STREAK_ICON,
            face    = d.face_val,
            fgcolor = _STREAK_ICON_CLR,
        },
        HorizontalSpan:new{ width = _STREAK_ICON_GAP },
        UI.makeColoredText{
            text    = val_str,
            face    = d.face_val,
            bold    = true,
            fgcolor = clr_blk or _CLR_TEXT_BLK,
        },
    }
end

local function buildStatCardWidget(card_w, stat_id, stats, d, align, colors, transparent)
    local entry = STAT_MAP[stat_id]
    if not entry then return nil end
    local val_str = entry.value(stats)
    local lbl_str = entry.label_fn and entry.label_fn(stats) or entry.label
    local clr_blk = colors and colors.blk or _CLR_TEXT_BLK
    local clr_sub = colors and colors.sub or CLR_TEXT_SUB
    return FrameContainer:new{
        dimen      = Geom:new{ w = card_w, h = d.card_h },
        bordersize = 1,
        color      = _CLR_CARD_BDR,
        background = not transparent and Blitbuffer.COLOR_WHITE or nil,
        radius     = d.corner_r,
        padding    = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = card_w, h = d.card_h },
            VerticalGroup:new{ align = align,
                stat_id == "streak" and stats.streak >= 5
                    and makeStreakValWidget(val_str, d, clr_blk)
                    or  UI.makeColoredText{ text = val_str, face = d.face_val, bold = true, fgcolor = clr_blk },
                UI.makeColoredText{
                    text    = lbl_str,
                    face    = d.face_lbl,
                    fgcolor = clr_sub,
                },
            },
        },
    }
end

-- Flat mode: no border, tinted background, content aligned.
local _CLR_FLAT_BG = Blitbuffer.gray(0.08)
local function buildStatFlatWidget(card_w, stat_id, stats, d, align, colors)
    local entry = STAT_MAP[stat_id]
    if not entry then return nil end
    local val_str = entry.value(stats)
    local lbl_str = entry.label_fn and entry.label_fn(stats) or entry.label
    local clr_blk = colors and colors.blk or _CLR_TEXT_BLK
    local clr_sub = colors and colors.sub or CLR_TEXT_SUB
    return FrameContainer:new{
        dimen      = Geom:new{ w = card_w, h = d.card_h },
        bordersize = 0,
        background = _CLR_FLAT_BG,
        radius     = d.corner_r,
        padding    = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = card_w, h = d.card_h },
            VerticalGroup:new{ align = align,
                stat_id == "streak" and stats.streak >= 5
                    and makeStreakValWidget(val_str, d, clr_blk)
                    or  UI.makeColoredText{ text = val_str, face = d.face_val, bold = true, fgcolor = clr_blk },
                UI.makeColoredText{
                    text    = lbl_str,
                    face    = d.face_lbl,
                    fgcolor = clr_sub,
                },
            },
        },
    }
end
local function buildStatListCell(cell_w, stat_id, stats, show_sep, d, align, colors)
    local entry = STAT_MAP[stat_id]
    if not entry then return nil end
    local val_str = entry.value(stats)
    local lbl_str = entry.label_fn and entry.label_fn(stats) or entry.label
    local clr_blk = colors and colors.blk or _CLR_TEXT_BLK
    local clr_sub = colors and colors.sub or CLR_TEXT_SUB

    local card = FrameContainer:new{
        dimen      = Geom:new{ w = cell_w, h = d.card_h },
        bordersize = 0,
        padding    = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = cell_w, h = d.card_h },
            VerticalGroup:new{ align = align,
                stat_id == "streak" and stats.streak >= 5
                    and makeStreakValWidget(val_str, d, clr_blk)
                    or  UI.makeColoredText{ text = val_str, face = d.face_val, bold = true, fgcolor = clr_blk },
                UI.makeColoredText{
                    text    = lbl_str,
                    face    = d.face_lbl,
                    fgcolor = clr_sub,
                },
            },
        },
    }

    local og = OverlapGroup:new{
        dimen = Geom:new{ w = cell_w, h = d.card_h },
        card,
    }
    if show_sep then
        local sep = LineWidget:new{
            dimen      = Geom:new{ w = d.sep_w, h = d.card_h },
            background = _CLR_CARD_BDR,
        }
        sep.overlap_offset = { cell_w - d.sep_w, 0 }
        og[#og+1] = sep
    end
    return og
end

local function openReaderProgress()
    UIManager:broadcastEvent(require("ui/event"):new("ShowReaderProgress"))
end

-- ---------------------------------------------------------------------------
-- Module API
-- ---------------------------------------------------------------------------
local M = {}

M.id         = "reading_stats"
M.name       = _("Reading Stats")
M.label      = nil   -- no section label; uses own top-padding
M.default_on = false
M.MAX_ITEMS  = RS_N_COLS   -- public field instead of getMaxItems() function

function M.isEnabled(pfx)
    return SUISettings:readSetting(pfx .. "reading_stats_enabled") == true
end

function M.setEnabled(pfx, on)
    SUISettings:saveSetting(pfx .. "reading_stats_enabled", on)
end

function M.getCountLabel(pfx)
    local n      = #(SUISettings:readSetting(pfx .. "reading_stats_items") or {})
    local max_rs = M.MAX_ITEMS
    local rem    = max_rs - n
    if n == 0   then return nil end
    if rem <= 0 then return string.format("(%d/%d — at limit)", n, max_rs) end
    return string.format("(%d/%d — %d left)", n, max_rs, rem)
end

function M.getStatLabel(id)
    return STAT_MAP[id] and STAT_MAP[id].display_label or id
end

function M.getCardHeight()
    return math.floor(_BASE_RS_CARD_H * Config.getModuleScale())
end

M.STAT_POOL = STAT_POOL

function M.invalidateCache()
    -- Delegate to the shared provider — it owns the cache now.
    local SP = package.loaded["desktop_modules/module_stats_provider"]
    if SP then SP.invalidate() end
end

function M.build(w, ctx)
    if not M.isEnabled(ctx.pfx) then return nil end
    local stat_ids = SUISettings:readSetting(ctx.pfx .. "reading_stats_items") or {}

    -- Compute all scaled dims once for this render pass.
    local scale     = Config.getModuleScale("reading_stats", ctx and ctx.pfx)
    local text_scale = scale * (Config.getRSTextScalePct() / 100)
    local _val_fs = math.max(8, math.floor(_BASE_RS_VAL_FS * text_scale))
    local _lbl_fs = math.max(6, math.floor(_BASE_RS_LBL_FS * text_scale))
    local _ph_fs  = math.max(8, math.floor(_BASE_RS_PH_FS  * scale))
    local d = {
        card_h   = math.floor(_BASE_RS_CARD_H   * scale),
        gap      = math.max(2, math.floor(_BASE_RS_GAP      * scale)),
        corner_r = math.floor(_BASE_RS_CORNER_R  * scale),
        val_fs   = _val_fs,
        lbl_fs   = _lbl_fs,
        sep_w    = math.max(1, math.floor(_BASE_RS_SEP_W    * scale)),
        ph_fs    = _ph_fs,
        -- Pre-resolved font faces — shared by all card builders, avoids
        -- repeated Font:getFace calls inside the per-card build loop.
        face_val = Font:getFace("smallinfofont", _val_fs),
        face_lbl = Font:getFace("cfont",         _lbl_fs),
        face_ph  = Font:getFace("smallinfofont", _ph_fs),
    }

    -- Theme: when fg is set use it for all text; otherwise fall back to module defaults.
    local ok_ss, SUIStyle  = pcall(require, "sui_style")
    local _theme_fg        = ok_ss and SUIStyle and SUIStyle.getThemeColor("fg")
    local _theme_secondary = ok_ss and SUIStyle and SUIStyle.getThemeColor("text_secondary")
    local _CLR_TEXT_BLK_EFF = _theme_fg or _CLR_TEXT_BLK
    local CLR_TEXT_SUB_EFF  = _theme_secondary or _theme_fg or CLR_TEXT_SUB

    -- Show a placeholder when enabled but no stats have been selected yet.
    if #stat_ids == 0 then
        return CenterContainer:new{
            dimen = Geom:new{ w = w, h = d.card_h },
            UI.makeColoredText{
                text    = _("No stats selected"),
                face    = d.face_ph,
                fgcolor = CLR_TEXT_SUB_EFF,
                width   = w - PAD * 2,
            },
        }
    end

    local n    = math.min(#stat_ids, RS_N_COLS)
    -- Stats are pre-fetched by StatsProvider (via _buildCtx) and passed in
    -- ctx.stats — no DB access or cache logic here.
    local sp   = ctx.stats or {}
    local stats = {
        today_secs  = sp.today_secs  or 0,
        today_pages = sp.today_pages or 0,
        avg_secs    = sp.avg_secs    or 0,
        avg_pages   = sp.avg_pages   or 0,
        total_secs  = sp.total_secs  or 0,
        total_books = sp.books_total or 0,
        streak      = sp.streak      or 0,
    }
    if sp.db_conn_fatal and ctx then ctx.db_conn_fatal = true end
    local mode  = getType(ctx.pfx)
    local align = getAlign(ctx.pfx)
    local row    = HorizontalGroup:new{ align = "center" }

    if mode == "list" then
        local cell_w = math.floor(w / n)
        local colors = { blk = _CLR_TEXT_BLK_EFF, sub = CLR_TEXT_SUB_EFF }
        for i = 1, n do
            local cell = buildStatListCell(cell_w, stat_ids[i], stats, i < n, d, align, colors)
                      or OverlapGroup:new{
                             dimen = Geom:new{ w = cell_w, h = d.card_h },
                         }
            row[#row+1] = cell
        end

        -- Single tappable over the whole row — all cards open the same screen,
        -- so one InputContainer + one GestureRange + one handler replaces N of each.
        local frame = FrameContainer:new{
            dimen      = Geom:new{ w = w, h = d.card_h },
            bordersize = 0, padding = 0,
            row,
        }
        local tappable = InputContainer:new{
            dimen = Geom:new{ w = w, h = d.card_h },
            [1]   = frame,
        }
        tappable.ges_events = {
            TapStatCard = { GestureRange:new{ ges = "tap", range = function() return tappable.dimen end } },
        }
        function tappable:onTapStatCard() openReaderProgress(); return true end
        return tappable
    else
        -- Cards / Flat mode: rounded cards with gaps between them.
        -- "flat" = no border, tinted background; "cards" = bordered white.
        local avail_w = w - PAD * 2
        local card_w  = math.floor((avail_w - d.gap * (n - 1)) / n)
        local colors  = { blk = _CLR_TEXT_BLK_EFF, sub = CLR_TEXT_SUB_EFF }
        for i = 1, n do
            local card
            if mode == "flat" then
                card = buildStatFlatWidget(card_w, stat_ids[i], stats, d, align, colors)
            elseif mode == "cards_transparent" then
                card = buildStatCardWidget(card_w, stat_ids[i], stats, d, align, colors, true)
            else
                card = buildStatCardWidget(card_w, stat_ids[i], stats, d, align, colors, false)
            end
            card = card or FrameContainer:new{
                dimen = Geom:new{ w = card_w, h = d.card_h },
                bordersize = 0, padding = 0,
            }
            if i > 1 then row[#row+1] = HorizontalSpan:new{ width = d.gap } end
            row[#row+1] = card
        end

        -- Single tappable over the whole row — one InputContainer + one
        -- GestureRange + one handler replaces N of each (N ≤ RS_N_COLS = 3).
        local inner = CenterContainer:new{
            dimen = Geom:new{ w = w, h = d.card_h },
            row,
        }
        local tappable = InputContainer:new{
            dimen = Geom:new{ w = w, h = d.card_h },
            [1]   = FrameContainer:new{
                dimen      = Geom:new{ w = w, h = d.card_h },
                bordersize = 0, padding = 0,
                inner,
            },
        }
        tappable.ges_events = {
            TapStatCard = { GestureRange:new{ ges = "tap", range = function() return tappable.dimen end } },
        }
        function tappable:onTapStatCard() openReaderProgress(); return true end
        return tappable
    end
end

function M.getHeight(_ctx)
    local card_h = math.floor(_BASE_RS_CARD_H * Config.getModuleScale("reading_stats", _ctx and _ctx.pfx))
    return card_h
end


local function _makeScaleItem(ctx_menu)
    local pfx = ctx_menu.pfx
    local _lc = ctx_menu._
    return Config.makeScaleItem({
        text_func    = function() return _lc("Scale") end,
        enabled_func = function() return not Config.isScaleLinked() end,
        title        = _lc("Scale"),
        info         = _lc("Scale for this module.\n100% is the default size."),
        get          = function() return Config.getModuleScalePct("reading_stats", pfx) end,
        set          = function(v) Config.setModuleScale(v, "reading_stats", pfx) end,
        refresh      = ctx_menu.refresh,
    })
end
function M.getMenuItems(ctx_menu)
    local pfx         = ctx_menu.pfx
    local _UIManager  = ctx_menu.UIManager
    local InfoMessage = ctx_menu.InfoMessage
    local SortWidget  = ctx_menu.SortWidget
    local refresh     = ctx_menu.refresh
    local _lc         = ctx_menu._
    local N_lc        = ctx_menu.N_
    local items_key   = pfx .. "reading_stats_items"
    local MAX_RS      = M.MAX_ITEMS

    local function getItems() return SUISettings:readSetting(items_key) or {} end
    local function isSelected(id)
        for _, v in ipairs(getItems()) do if v == id then return true end end; return false
    end
    local function toggleItem(id)
        local cur = getItems(); local new_items = {}; local found = false
        for _, v in ipairs(cur) do if v == id then found = true else new_items[#new_items+1] = v end end
        if not found then
            if #cur >= MAX_RS then
                _UIManager:show(InfoMessage:new{
                    text = string.format(N_lc("The maximum of %d stat per row has been reached. Remove one first.",
                           "The maximum of %d stats per row has been reached. Remove one first.", MAX_RS), MAX_RS), timeout = 2 })
                return
            end
            new_items[#new_items+1] = id
        end
        SUISettings:saveSetting(items_key, new_items); refresh()
    end

    local items = {
        {
            text           = _lc("Type"),
            sub_item_table = {
                {
                    text           = _lc("Cards"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getType(pfx) == "cards" end,
                    callback       = function()
                        SUISettings:saveSetting(pfx .. SETTING_TYPE, "cards")
                        refresh()
                    end,
                },
                {
                    text           = _lc("Cards - Transparent"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getType(pfx) == "cards_transparent" end,
                    callback       = function()
                        SUISettings:saveSetting(pfx .. SETTING_TYPE, "cards_transparent")
                        refresh()
                    end,
                },
                {
                    text           = _lc("Flat"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getType(pfx) == "flat" end,
                    callback       = function()
                        SUISettings:saveSetting(pfx .. SETTING_TYPE, "flat")
                        refresh()
                    end,
                },
                {
                    text           = _lc("List"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getType(pfx) == "list" end,
                    callback       = function()
                        SUISettings:saveSetting(pfx .. SETTING_TYPE, "list")
                        refresh()
                    end,
                },
            },
        },
        _makeScaleItem(ctx_menu),
        Config.makeScaleItem({
            text_func     = function()
                local pct = Config.getRSTextScalePct()
                return pct == Config.RS_TEXT_SCALE_DEF
                    and _lc("Text Size")
                    or  string.format(_lc("Text Size — %d%%"), pct)
            end,
            title         = _lc("Text Size"),
            info          = _lc("Size of the text inside the stat cards.\nDoes not affect card size or padding.\n100% is the default size."),
            get           = function() return Config.getRSTextScalePct() end,
            set           = function(pct) Config.setRSTextScalePct(pct) end,
            refresh       = ctx_menu.refresh,
            value_min     = Config.RS_TEXT_SCALE_MIN,
            value_max     = Config.RS_TEXT_SCALE_MAX,
            value_step    = Config.RS_TEXT_SCALE_STEP,
            default_value = Config.RS_TEXT_SCALE_DEF,
        }),
        {
            text_func      = function()
                return _lc("Alignment") .. " — " .. alignLabel(getAlign(pfx))
            end,
            sub_item_table = {
                {
                    text           = _lc("Left"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getAlign(pfx) == "left"   end,
                    callback       = function()
                        SUISettings:saveSetting(pfx .. SETTING_ALIGN, "left")
                        refresh()
                    end,
                },
                {
                    text           = _lc("Center"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getAlign(pfx) == "center" end,
                    callback       = function()
                        SUISettings:saveSetting(pfx .. SETTING_ALIGN, "center")
                        refresh()
                    end,
                },
                {
                    text           = _lc("Right"),
                    radio          = true,
                    keep_menu_open = true,
                    checked_func   = function() return getAlign(pfx) == "right"  end,
                    callback       = function()
                        SUISettings:saveSetting(pfx .. SETTING_ALIGN, "right")
                        refresh()
                    end,
                },
            },
        },
        { text = _lc("Arrange"), keep_menu_open = true, separator = true, callback = function()
            local rs_ids = getItems()
            if #rs_ids < 2 then
                _UIManager:show(InfoMessage:new{ text = _lc("Add at least 2 stats to arrange."), timeout = 2 }); return
            end
            local sort_items = {}
            for _, id in ipairs(rs_ids) do
                sort_items[#sort_items+1] = { text = M.getStatLabel(id), orig_item = id }
            end
            _UIManager:show(SortWidget:new{ title = _lc("Arrange Reading Stats"), covers_fullscreen = true,
                item_table = sort_items, callback = function()
                    local new_order = {}
                    for _, item in ipairs(sort_items) do new_order[#new_order+1] = item.orig_item end
                    SUISettings:saveSetting(items_key, new_order); refresh()
                end })
        end },
    }

    -- Use pre-sorted pool (sorted once at module load, not per menu open).
    for _, entry in ipairs(_sorted_pool) do
        local _sid = entry.id; local _lbl = entry.label
        items[#items+1] = {
            text_func = function()
                if isSelected(_sid) then return _lbl end
                local rem = MAX_RS - #getItems()
                if rem <= 2 then return _lbl .. string.format(N_lc("  (%d left)", "  (%d left)", rem), rem) end
                return _lbl
            end,
            checked_func   = function() return isSelected(_sid) end,
            keep_menu_open = true,
            callback       = function() toggleItem(_sid) end,
        }
    end
    return items
end

return M