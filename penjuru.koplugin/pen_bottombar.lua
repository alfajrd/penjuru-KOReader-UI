-- penjuru/pen_bottombar
-- Persistent 7-cell paginated nav bar.
-- Layout: chevron-left · 5 content tabs · chevron-right.
-- Active-tab indicator: 7px top-edge bar.
-- Hold any tab: opens placeholder InfoMessage (Plan D wires real settings).

local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local InfoMessage = require("ui/widget/infomessage")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Tabs = require("pen_tabs")
local Icons = require("pen_icons")

local M = {}

-- Singleton state. Pagination + active id persist across renders.
M._current_page = 1
M._active_id = "home"
M._on_paginate = nil

-- Flex ratio per cell. Chevron : content : chevron = 10 : (16 x 5) : 10 = 100.
local CHEVRON_FLEX = 10
local CONTENT_FLEX = 16
local TOTAL_FLEX = CHEVRON_FLEX * 2 + CONTENT_FLEX * 5

-- On the Kindle PW (1648px tall) the home body already takes ~1300px;
-- giving the nav a tall 170px cell pushed everything past the screen
-- and KOReader's HorizontalGroup wrapped manga/books into a second row.
-- Smaller cells fit cleanly and still hit the 44pt+ touch target minimum.
local NAV_HEIGHT = 110
local ICON_SIZE = 44

-- Build one cell. cell_w is the cell's pixel width.
local function make_cell(cell_w, icon_name, label, is_active, is_disabled, on_tap, on_hold)
    local icon = Icons.widget(icon_name, ICON_SIZE)
    local txt = TextWidget:new{
        text = label,
        face = Style.fonts.body(Style.size.nav_label),
        fgcolor = is_disabled and Style.colors.disabled or Style.colors.ink,
    }

    -- v1.2.14.2: icon + label centered inside a CenterContainer that
    -- spans the full cell width. Without this the inner VerticalGroup
    -- shrinks to its content's natural width and clings to the cell's
    -- left edge (FrameContainer doesn't center its children).
    local icon_label = VerticalGroup:new{
        align = "center",
        icon,
        VerticalSpan:new{ width = Style.gap.sm },
        txt,
    }
    local content_h = NAV_HEIGHT - Style.rules.active
    local centered_content = CenterContainer:new{
        dimen = Geom:new{ w = cell_w, h = content_h },
        icon_label,
    }

    -- Top border: 7px black on active, equivalent transparent span otherwise
    -- (so cells align across active/inactive states).
    local top_bar = is_active
        and Widgets.rule(cell_w, Style.rules.active, Style.colors.ink)
        or VerticalSpan:new{ width = Style.rules.active }

    local cell_inner = VerticalGroup:new{
        align = "center",
        top_bar,
        centered_content,
    }

    local wrap = FrameContainer:new{
        background = Style.colors.paper,
        bordersize = 0,
        margin = 0,
        padding_left = 0, padding_right = 0,
        padding_top = 0, padding_bottom = 0,
        width = cell_w,
        height = NAV_HEIGHT,
        cell_inner,
    }

    if not (on_tap or on_hold) or is_disabled then
        return wrap
    end

    -- v1.2.14: replaced the broken `handler = function()...end` antipattern
    -- with Widgets.tappable. KOReader dispatches gestures by method name
    -- (TapArea → :onTapArea, HoldArea → :onHoldArea), not by reading a
    -- handler field — the field is silently ignored. The original wiring
    -- locked the Kindle three times in v1.0 because cells never responded
    -- to taps; only a hard reset got the user back to the file manager.
    return Widgets.tappable(wrap, cell_w, NAV_HEIGHT, on_tap, on_hold)
end

-- render(content_width, action_dispatch) -> widget
-- action_dispatch is function(tab_descriptor); called when a content tab
-- is tapped. Chevron taps are handled internally and trigger _on_paginate.
function M.render(content_width, action_dispatch)
    local pages = Tabs.user_pages()
    local total_pages = #pages
    local cur = Tabs.clamp_page(M._current_page, total_pages)
    local page = pages[cur] or {}

    -- Pagination meta row above the cells.
    local meta_left = TextWidget:new{
        text = string.format("navpager · page %d / %d", cur, total_pages),
        face = Style.fonts.body(Style.size.nav_meta),
        fgcolor = Style.colors.ink_dim,
    }
    local meta_right = TextWidget:new{
        text = "hold any tab → settings",
        face = Style.fonts.body(Style.size.nav_meta),
        fgcolor = Style.colors.ink_dim,
    }
    local meta_row = Widgets.spaced_row(content_width, { meta_left, meta_right })
    local meta = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = Style.gap.xs },
        meta_row,
        VerticalSpan:new{ width = Style.gap.xs },
        Widgets.dotted_rule(content_width, Style.rules.minor, Style.colors.rule),
    }

    -- v1.2.14.1: 6 hairline dividers between the 7 cells. Subtract their
    -- combined width from the cell budget so the row still fits
    -- content_width exactly (dividers eat ~12px of 1116px on the PW).
    local DIVIDER_W = 2
    local DIVIDER_COUNT = 6
    local effective_w = content_width - DIVIDER_W * DIVIDER_COUNT
    local unit = effective_w / TOTAL_FLEX
    local chevron_w = math.floor(unit * CHEVRON_FLEX)
    local content_w_cell = math.floor(unit * CONTENT_FLEX)

    local function divider()
        return LineWidget:new{
            dimen = { w = DIVIDER_W, h = NAV_HEIGHT },
            background = Style.colors.rule_soft or Style.colors.ink_dim,
        }
    end

    local prev_disabled = (cur == 1)
    local next_disabled = (cur == total_pages)
    local prev_cell = make_cell(
        chevron_w, "chevron-left", "prev",
        false, prev_disabled,
        not prev_disabled and function()
            M._current_page = cur - 1
            if M._on_paginate then M._on_paginate() end
        end or nil,
        nil)
    local next_cell = make_cell(
        chevron_w, "chevron-right", "next",
        false, next_disabled,
        not next_disabled and function()
            M._current_page = cur + 1
            if M._on_paginate then M._on_paginate() end
        end or nil,
        nil)

    local row = HorizontalGroup:new{ align = "top" }
    table.insert(row, prev_cell)
    table.insert(row, divider())
    for idx, tab in ipairs(page) do
        local _tab = tab
        local on_tap = function()
            if action_dispatch then action_dispatch(_tab) end
        end
        local on_hold = function()
            local pages_text = "tab roster (read-only)\n\n"
            for i, p in ipairs(Tabs.user_pages()) do
                pages_text = pages_text .. "page " .. i .. ":\n"
                for _, t in ipairs(p) do
                    pages_text = pages_text .. "  · " .. t.label .. "  (" .. t.id .. ")\n"
                end
                pages_text = pages_text .. "\n"
            end
            pages_text = pages_text .. "edit via G_reader_settings.penjuru.bottombar.pages\n(gui editing in v1.1)"
            UIManager:show(InfoMessage:new{
                text = pages_text,
                timeout = 8,
            })
        end
        local is_active = (tab.id == M._active_id)
        table.insert(row, make_cell(content_w_cell, tab.icon, tab.label,
            is_active, false, on_tap, on_hold))
        -- Divider after every cell except the last content one (next chevron
        -- gets its own leading divider via the explicit insert below).
        table.insert(row, divider())
        _ = idx  -- silence unused-loop-var warning
    end
    table.insert(row, next_cell)

    return VerticalGroup:new{
        align = "left",
        Widgets.rule(content_width, Style.rules.nav_top, Style.colors.ink),
        meta,
        row,
    }
end

function M.set_active(tab_id)
    M._active_id = tab_id
end
function M.set_page(n)
    M._current_page = n
end
function M.set_on_paginate(callback)
    M._on_paginate = callback
end

return M
