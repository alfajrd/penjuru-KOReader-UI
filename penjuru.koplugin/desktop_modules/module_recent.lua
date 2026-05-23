-- module_recent.lua — Simple UI
-- Módulo: Recent Books.
-- Substitui a parte "recent" de recentbookswidget.lua.

local Blitbuffer      = require("ffi/blitbuffer")
local Device          = require("device")
local Font            = require("ui/font")
local FrameContainer  = require("ui/widget/container/framecontainer")
local Geom            = require("ui/geometry")
local GestureRange    = require("ui/gesturerange")
local UIManager       = require("ui/uimanager")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local InputContainer  = require("ui/widget/container/inputcontainer")
local LineWidget      = require("ui/widget/linewidget")
local OverlapGroup    = require("ui/widget/overlapgroup")
local CenterContainer = require("ui/widget/container/centercontainer")
local TextWidget      = require("ui/widget/textwidget")
local VerticalGroup   = require("ui/widget/verticalgroup")
local Screen          = Device.screen
local Size            = require("ui/size")
local _ = require("pen_i18n").translate

local logger  = require("logger")
local _SH = nil
local function getSH()
    if not _SH then
        local ok, m = pcall(require, "desktop_modules/module_books_shared")
        if ok and m then _SH = m
        else logger.warn("simpleui: module_recent: cannot load module_books_shared: " .. tostring(m)) end
    end
    return _SH
end

local Config       = require("pen_config")
local UI           = require("pen_core")
local PENSettings = require("pen_store")
local PAD          = UI.PAD
local PAD2         = UI.PAD2
local MOD_GAP      = UI.MOD_GAP
local LABEL_H      = UI.LABEL_H
local CLR_TEXT_SUB = UI.CLR_TEXT_SUB

local _BASE_RB_PCT_FS = Screen:scaleBySize(8)  -- "XX% Read" label font size — base value

local SETTING_PROGRESS      = "recent_show_progress"  -- pfx .. this; default ON
local SETTING_TEXT          = "recent_show_text"       -- pfx .. this; default ON
local SETTING_OVERLAY       = "recent_show_overlay"    -- pfx .. this; default OFF
local SETTING_SHOW_FINISHED = "recent_show_finished"   -- pfx .. this; default OFF

local function showProgress(pfx)
    return PENSettings:readSetting(pfx .. SETTING_PROGRESS) ~= false
end
local function showText(pfx)
    return PENSettings:readSetting(pfx .. SETTING_TEXT) ~= false
end
local function showOverlay(pfx)
    return PENSettings:readSetting(pfx .. SETTING_OVERLAY) == true
end
local function showFinished(pfx)
    return PENSettings:readSetting(pfx .. SETTING_SHOW_FINISHED) == true
end


local M = {}

M.id          = "recent"
M.name        = _("Recent Books")
M.label       = _("Recent Books")
M.enabled_key = "recent"
M.default_on  = false
M.has_covers  = true   -- activates e-ink dithering and cover poll
M.is_book_mod = true   -- suppresses empty-state when active

-- Called by teardown (via _PLUGIN_MODULES flush) to drop the cached reference
-- to module_books_shared so a hot update picks up fresh code on next load.
function M.reset() _SH = nil end

function M.build(w, ctx)
    Config.applyLabelToggle(M, _("Recent Books"))
    if not ctx.recent_fps or #ctx.recent_fps == 0 then return nil end

    local SH          = getSH()
    local scale       = Config.getModuleScale("recent", ctx.pfx)
    local thumb_scale = Config.getThumbScale("recent", ctx.pfx)
    local lbl_scale   = Config.getItemLabelScale("recent", ctx.pfx)
    local D           = SH.getDims(scale, thumb_scale)
    local pct_fs = math.max(8, math.floor(_BASE_RB_PCT_FS * scale * lbl_scale))

    -- Theme colors
    local ok_ss, SUIStyle  = pcall(require, "pen_style")
    local _theme_fg        = ok_ss and SUIStyle and SUIStyle.getThemeColor("fg")
    local _theme_secondary = ok_ss and SUIStyle and SUIStyle.getThemeColor("text_secondary")
    local _CLR_DARK_EFF    = _theme_fg or Blitbuffer.COLOR_BLACK
    local CLR_TEXT_SUB_EFF = _theme_secondary or _theme_fg or CLR_TEXT_SUB

    local cols    = math.min(#ctx.recent_fps, 5)
    local cw      = D.RECENT_W
    local ch      = D.RECENT_H
    -- Space-between across 5 fixed slots with same lateral padding as other modules (PAD).
    local inner_w = w - PAD * 2
    local gap     = math.floor((inner_w - 5 * cw) / 4)
    -- Hoist the face lookup — same args for every cell, no need to call per iteration.
    local pct_face = Font:getFace("smallinfofont", pct_fs)

    local show_progress = showProgress(ctx.pfx)
    local show_text     = showText(ctx.pfx)
    local use_overlay   = showOverlay(ctx.pfx)

    -- When overlay is active, progress bar and text below covers are hidden.
    local draw_progress = show_progress and not use_overlay
    local draw_text     = show_text     and not use_overlay

    -- Badge radius (also used in getHeight).
    local badge_r = math.floor(cw * 0.28)

    -- Total tappable cell height.
    local cell_h = use_overlay and (ch + badge_r) or D.RECENT_CELL_H

    local row = HorizontalGroup:new{ align = "top" }
    local cover_slots = {}
    for i = 1, cols do
        local fp    = ctx.recent_fps[i]
        local bd    = SH.getBookData(fp, ctx.prefetched and ctx.prefetched[fp])
        local cover = SH.getBookCover(fp, cw, ch, nil, 0.10) or SH.coverPlaceholder(bd.title, bd.authors, cw, ch)

        -- Build cover layer: plain or with percentage badge overlaid.
        local cover_widget
        if use_overlay then
            local pct_int = math.floor((bd.percent or 0) * 100 + 0.5)
            local badge_d = badge_r * 2
            local badge = FrameContainer:new{
                bordersize  = 0,
                background  = Blitbuffer.gray(0.15),
                padding     = 0,
                dimen       = Geom:new{ w = badge_d, h = badge_d },
                radius      = badge_r,
                CenterContainer:new{
                    dimen = Geom:new{ w = badge_d, h = badge_d },
                    UI.makeColoredText{
                        text    = string.format(_("%d%%"), pct_int),
                        face    = pct_face,
                        bold    = true,
                        fgcolor = _CLR_DARK_EFF,
                    },
                },
            }
            -- Position badge centred horizontally, half inside / half outside
            -- the bottom edge of the cover (y = ch - badge_r).
            badge.overlap_offset = {
                math.floor((cw - badge_d) / 2),
                ch - badge_r,
            }
            -- The OverlapGroup must be tall enough to include the half that
            -- bleeds below the cover, otherwise the badge gets clipped.
            cover_widget = OverlapGroup:new{
                dimen = Geom:new{ w = cw, h = ch + badge_r },
                cover,
                badge,
            }
        else
            cover_widget = cover
        end

        local cell = VerticalGroup:new{ align = "center", cover_widget }

        if draw_progress then
            cell[#cell+1] = SH.vspan(D.RB_GAP1, ctx.vspan_pool)
            cell[#cell+1] = SH.progressBar(cw, bd.percent, D.RB_BAR_H)
        end

        if draw_text then
            cell[#cell+1] = SH.vspan(draw_progress and D.RB_GAP2 or D.RB_GAP1, ctx.vspan_pool)
            cell[#cell+1] = UI.makeColoredText{
                text      = string.format(_("%d%% Read"), math.floor((bd.percent or 0) * 100 + 0.5)),
                face      = pct_face,
                bold      = true,
                fgcolor   = CLR_TEXT_SUB_EFF,
                width     = cw,
                alignment = "center",
            }
        end

        local tappable = InputContainer:new{
            dimen    = Geom:new{ w = cw, h = cell_h },
            [1]      = cell,
            _fp      = fp,
            _open_fn = ctx.open_fn,
        }
        tappable.ges_events = {
            TapBook = {
                GestureRange:new{
                    ges   = "tap",
                    range = function() return tappable.dimen end,
                },
            },
        }
        function tappable:onTapBook()
            if self._open_fn then self._open_fn(self._fp) end
            return true
        end

        -- Record cover slot: cell[1] is cover_widget; if overlay, cover is at [1] inside it.
        if use_overlay then
            cover_slots[#cover_slots+1] = { container = cover_widget, idx = 1, fp = fp, w = cw, h = ch, align = nil, stretch = 0.10 }
        else
            cover_slots[#cover_slots+1] = { container = cell, idx = 1, fp = fp, w = cw, h = ch, align = nil, stretch = 0.10 }
        end

        -- Keyboard focus: overlay a black rectangular border on this book cell
        -- when it is the currently selected keyboard-navigation item.
        local cell_widget = tappable
        if ctx.kb_recent_focus_idx == i then
            local bw = Screen:scaleBySize(3)
            cell_widget = OverlapGroup:new{
                dimen = Geom:new{ w = cw, h = cell_h },
                tappable,
                LineWidget:new{ dimen = Geom:new{ w = cw, h = bw },    background = _CLR_DARK_EFF },
                LineWidget:new{ dimen = Geom:new{ w = cw, h = bw },    background = _CLR_DARK_EFF, overlap_offset = {0, cell_h - bw} },
                LineWidget:new{ dimen = Geom:new{ w = bw, h = cell_h }, background = _CLR_DARK_EFF },
                LineWidget:new{ dimen = Geom:new{ w = bw, h = cell_h }, background = _CLR_DARK_EFF, overlap_offset = {cw - bw, 0} },
            }
        end

        -- Use HorizontalSpan for inter-cell spacing instead of a zero-border
        -- FrameContainer — avoids 4 unnecessary widget allocations per render.
        if i > 1 then row[#row + 1] = HorizontalSpan:new{ width = gap } end
        row[#row + 1] = cell_widget
    end

    local show_frame = PENSettings:isTrue(ctx.pfx .. "recent_show_frame")
    local solid_bg   = PENSettings:isTrue(ctx.pfx .. "recent_solid_bg")
    local has_box    = show_frame or solid_bg
    local border_sz  = show_frame and 1 or 0
    local radius     = has_box and math.floor(Screen:scaleBySize(12) * scale) or 0
    local border_color = Blitbuffer.gray(0.72)
    if ok_ss and SUIStyle then
        border_color = SUIStyle.getThemeColor("separator") or border_color
    end
    local bg_color = nil
    if solid_bg then
        bg_color = (ok_ss and SUIStyle and SUIStyle.getThemeColor("bg")) or Blitbuffer.COLOR_WHITE
    end

    local result = FrameContainer:new{
        bordersize = border_sz,
        radius     = radius,
        color      = border_color,
        background = bg_color,
        padding = PAD, padding_top = has_box and PAD or 0, padding_bottom = has_box and PAD or 0,
        row,
    }
    result._cover_slots = cover_slots
    return result
end

function M.updateCovers(widget, _ctx)
    if not widget or not widget._cover_slots then return true end
    local SH = getSH()
    if not SH then return true end
    local all_done = true
    for _, slot in ipairs(widget._cover_slots) do
        local new_cover = SH.getBookCover(slot.fp, slot.w, slot.h, slot.align, slot.stretch)
        if new_cover then
            slot.container[slot.idx] = new_cover
        elseif not Config.isCoverMissing(slot.fp) then
            all_done = false
        end
    end
    return all_done
end

function M.getHeight(ctx)
    local SH  = getSH()
    local pfx = ctx and ctx.pfx or ""
    local D   = SH.getDims(Config.getModuleScale("recent", pfx),
                            Config.getThumbScale("recent", pfx))
    local use_overlay = showOverlay(pfx)
    local h = D.RECENT_H
    if use_overlay then
        local badge_r = math.floor(D.RECENT_W * 0.28)
        h = h + badge_r
    else
        if showProgress(pfx) then
            h = h + D.RB_GAP1 + D.RB_BAR_H
            if showText(pfx) then h = h + D.RB_GAP2 end
        end
        if showText(pfx) then
            if not showProgress(pfx) then h = h + D.RB_GAP1 end
            h = h + D.RB_LABEL_H
        end
    end
    if PENSettings:isTrue(pfx .. "recent_show_frame") or PENSettings:isTrue(pfx .. "recent_solid_bg") then
        h = h + PAD * 2
    end
    return require("pen_config").getScaledLabelH() + h
end


local function _makeScaleItem(ctx_menu)
    local pfx = ctx_menu.pfx
    local _lc = ctx_menu._
    return Config.makeScaleItem({
        text_func    = function() return _lc("Scale") end,
        enabled_func = function() return not Config.isScaleLinked() end,
        title        = _lc("Scale"),
        info         = _lc("Scale for this module.\n100% is the default size."),
        get          = function() return require("pen_config").getModuleScalePct("recent", pfx) end,
        set          = function(v) require("pen_config").setModuleScale(v, "recent", pfx) end,
        refresh      = ctx_menu.refresh,
    })
end

local function _makeThumbScaleItem(ctx_menu)
    local pfx = ctx_menu.pfx
    local _lc = ctx_menu._
    return Config.makeScaleItem({
        text_func = function() return _lc("Cover size") end,
        separator = true,
        title     = _lc("Cover size"),
        info      = _lc("Scale for the cover thumbnails only.\nText and progress bar follow the module scale.\n100% is the default size."),
        get       = function() return require("pen_config").getThumbScalePct("recent", pfx) end,
        set       = function(v) require("pen_config").setThumbScale(v, "recent", pfx) end,
        refresh   = ctx_menu.refresh,
    })
end

function M.getMenuItems(ctx_menu)
    local pfx     = ctx_menu.pfx
    local refresh = ctx_menu.refresh
    local _lc     = ctx_menu._
    local label_item = Config.makeScaleItem({
        text_func = function() return _lc("Text Size") end,
        title     = _lc("Text Size"),
        info      = _lc("Scale for the percentage read text.\n100% is the default size."),
        get       = function() return Config.getItemLabelScalePct("recent", pfx) end,
        set       = function(v) Config.setItemLabelScale(v, "recent", pfx) end,
        refresh   = refresh,
    })
    return {
        _makeScaleItem(ctx_menu),
        label_item,
        Config.makeLabelToggleItem("recent", _("Recent Books"), refresh, _lc),
        {
            text           = _lc("Frame"),
            checked_func   = function() return PENSettings:isTrue(pfx .. "recent_show_frame") end,
            keep_menu_open = true,
            callback       = function()
                PENSettings:saveSetting(pfx .. "recent_show_frame", not PENSettings:isTrue(pfx .. "recent_show_frame"))
                refresh()
            end,
        },
        {
            text           = _lc("Solid Background"),
            checked_func   = function() return PENSettings:isTrue(pfx .. "recent_solid_bg") end,
            keep_menu_open = true,
            callback       = function()
                PENSettings:saveSetting(pfx .. "recent_solid_bg", not PENSettings:isTrue(pfx .. "recent_solid_bg"))
                refresh()
            end,
        },
        _makeThumbScaleItem(ctx_menu),
        {
            text           = _lc("Progress bar"),
            checked_func   = function() return showProgress(pfx) end,
            enabled_func   = function() return not showOverlay(pfx) end,
            keep_menu_open = true,
            callback       = function()
                PENSettings:saveSetting(pfx .. SETTING_PROGRESS, not showProgress(pfx))
                refresh()
            end,
        },
        {
            text           = _lc("Percentage text"),
            checked_func   = function() return showText(pfx) end,
            enabled_func   = function() return not showOverlay(pfx) end,
            keep_menu_open = true,
            callback       = function()
                PENSettings:saveSetting(pfx .. SETTING_TEXT, not showText(pfx))
                refresh()
            end,
        },
        {
            text           = _lc("Percentage overlay on cover"),
            checked_func   = function() return showOverlay(pfx) end,
            keep_menu_open = true,
            callback       = function()
                PENSettings:saveSetting(pfx .. SETTING_OVERLAY, not showOverlay(pfx))
                refresh()
            end,
        },
        {
            text           = _lc("Show finished books"),
            checked_func   = function() return showFinished(pfx) end,
            keep_menu_open = true,
            callback       = function()
                PENSettings:saveSetting(pfx .. SETTING_SHOW_FINISHED, not showFinished(pfx))
                refresh()
            end,
        },
    }
end

return M
