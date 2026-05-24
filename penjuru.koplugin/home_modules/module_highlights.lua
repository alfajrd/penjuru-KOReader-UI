-- home_modules/module_highlights
-- "recent highlights" — 3 most-recent annotations across all books.
-- Each: quote (Syne Mono) + source line (Plex italic small) + dotted divider.

local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local function highlight_block(w, h)
    local quote = TextBoxWidget:new{
        text = '"' .. string.lower(h.text) .. '"',
        face = Style.fonts.headline(Style.size.highlight_q),
        fgcolor = Style.colors.ink,
        width = w,
    }
    local parts = { "— " }
    if h.book_author ~= "" then table.insert(parts, string.lower(h.book_author) .. ", ") end
    table.insert(parts, string.lower(h.book_title))
    table.insert(parts, " · p. " .. h.page)
    if h.datetime ~= "" then
        table.insert(parts, " · " .. h.datetime:sub(1, 10))
    end
    local src = TextWidget:new{
        text = table.concat(parts),
        face = Style.fonts.italic(Style.size.highlight_src),
        fgcolor = Style.colors.ink_dim,
    }
    local content = VerticalGroup:new{
        align = "left",
        quote,
        VerticalSpan:new{ width = 6 },
        src,
        VerticalSpan:new{ width = 10 },
        Widgets.dotted_rule(w, Style.rules.minor, Style.colors.rule_soft),
        VerticalSpan:new{ width = 10 },
    }

    local content_h = content:getSize().h
    local InputContainer = require("ui/widget/container/inputcontainer")
    local GestureRange = require("ui/gesturerange")
    local Geom = require("ui/geometry")
    return InputContainer:new{
        dimen = Geom:new{ x = 0, y = 0, w = w, h = content_h },
        content,
        ges_events = {
            Tap = {
                GestureRange:new{
                    ges = "tap",
                    range = Geom:new{ x = 0, y = 0, w = w, h = content_h },
                },
                handler = function()
                    if not h.book_file then return end
                    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
                    if not ok or not ReaderUI then return end
                    pcall(ReaderUI.showReader, ReaderUI, h.book_file)
                    -- Note: jumping to the highlighted page requires opening
                    -- the reader first then issuing a goto; we open to the
                    -- book and let the user navigate. Page-jump deferred
                    -- to Plan D enhancement.
                end,
            },
        },
    }
end

function M.render(content_width)
    local hs = Data.read_recent_highlights(3)
    local children = { Widgets.section_head(content_width, "recent highlights") }
    if #hs == 0 then
        table.insert(children, TextWidget:new{
            text = "no highlights yet",
            face = Style.fonts.italic(Style.size.body - 4),
            fgcolor = Style.colors.ink_faint,
        })
    else
        for _, h in ipairs(hs) do
            table.insert(children, highlight_block(content_width, h))
        end
    end
    return VerticalGroup:new{ align = "left", table.unpack(children) }
end

return M
