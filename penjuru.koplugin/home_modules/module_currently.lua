-- home_modules/module_currently
-- The lead story: headline = book title, byline = author/year, pull
-- quote = most recent highlight, body lede = activity summary,
-- progress bar.

local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

-- Tappable wrapper for the lead-story card.
--
-- HARD-WON LESSON (see penjuru-plan-a-state.md): KOReader's InputContainer
-- dispatches gestures by METHOD NAME derived from the ges_events key, NOT
-- by a `handler` field in the table. ges_events.TapBook → :onTapBook().
-- The v1.0 home used `handler = function()...end` and the user got stuck
-- on their Kindle three times because gestures fired into the void.
--
-- Range note: self.dimen is the SAME Geom table referenced by the gesture
-- range. WidgetContainer:paintTo() mutates dimen.x/.y to absolute screen
-- coords during paint, so the range tracks the widget's painted position
-- without any per-frame wiring.
local TappableCard = InputContainer:extend{
    on_tap_cb = nil,
}
function TappableCard:init()
    if not self.dimen then
        self.dimen = Geom:new{ x = 0, y = 0, w = 0, h = 0 }
    end
    self.ges_events.TapBook = {
        GestureRange:new{ ges = "tap", range = self.dimen },
    }
end
function TappableCard:onTapBook()
    if self.on_tap_cb then self.on_tap_cb() end
    return true
end

local function pull_quote(w, text)
    local quote = TextBoxWidget:new{
        text = '"' .. text .. '"',
        face = Style.fonts.italic(Style.size.pull),
        fgcolor = Style.colors.ink_2,
        width = w - 18,
    }
    return HorizontalGroup:new{
        align = "top",
        LineWidget:new{
            dimen = { w = 4, h = quote:getSize().h },
            background = Style.colors.ink,
        },
        HorizontalSpan:new{ width = 14 },
        quote,
    }
end

local function progress_bar(w, percent)
    local pct_int = math.floor(percent * 100 + 0.5)
    local left = TextWidget:new{
        text = "p " .. pct_int .. "%",
        face = Style.fonts.body(Style.size.body - 4),
        fgcolor = Style.colors.ink_soft,
    }
    local bar_w = w - left:getSize().w - 16
    local filled = math.max(2, math.floor(bar_w * percent))
    local bar = HorizontalGroup:new{
        align = "center",
        LineWidget:new{ dimen = { w = filled, h = 5 }, background = Style.colors.ink },
        LineWidget:new{ dimen = { w = bar_w - filled, h = 5 }, background = Style.colors.rule_dim },
    }
    return HorizontalGroup:new{
        align = "center",
        left,
        HorizontalSpan:new{ width = 16 },
        bar,
    }
end

function M.render(content_width)
    local b = Data.read_lead_book()
    if not b then
        -- Nothing to open → no tap needed, return the plain placeholder.
        return VerticalGroup:new{
            align = "left",
            Widgets.section_head(content_width, "currently reading"),
            TextWidget:new{
                text = "no entries today",
                face = Style.fonts.italic(Style.size.body),
                fgcolor = Style.colors.ink_faint,
            },
        }
    end

    local headline = TextBoxWidget:new{
        text = string.lower(b.title),
        face = Style.fonts.headline(Style.size.headline),
        fgcolor = Style.colors.ink,
        width = content_width,
    }
    local byline_text = "— "
    if b.author and b.author ~= "" then byline_text = byline_text .. string.lower(b.author) end
    if b.year and b.year ~= "" then byline_text = byline_text .. ", " .. tostring(b.year) end
    local byline = TextWidget:new{
        text = byline_text,
        face = Style.fonts.italic(Style.size.byline),
        fgcolor = Style.colors.ink_soft,
    }

    local children = {
        Widgets.section_head(content_width, "currently reading"),
        headline,
        VerticalSpan:new{ width = 6 },
        byline,
    }

    local hs = Data.read_book_highlights(b.file, 1)
    if hs[1] then
        table.insert(children, VerticalSpan:new{ width = 10 })
        table.insert(children, pull_quote(content_width, string.lower(hs[1].text)))
    end

    table.insert(children, VerticalSpan:new{ width = 10 })
    table.insert(children, progress_bar(content_width, b.percent or 0))

    local card = VerticalGroup:new{ align = "left", table.unpack(children) }

    -- Wrap the whole card in a tap target. Tap → close home → resume book at
    -- last-known position via pen_book_open. The require for pen_homescreen
    -- happens inside the callback (not at module load) to avoid the circular
    -- import problem — pen_homescreen requires this module at load time.
    local card_size = card:getSize()
    return TappableCard:new{
        dimen = Geom:new{ x = 0, y = 0, w = card_size.w, h = card_size.h },
        card,
        on_tap_cb = function()
            local Homescreen = require("pen_homescreen")
            if Homescreen and Homescreen.close then
                pcall(Homescreen.close)
            end
            local BookOpen = require("pen_book_open")
            BookOpen.open(b.file)
        end,
    }
end

return M
