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

    -- Tap-to-open at the highlighted page. Uses the shared Widgets.tappable
    -- wrapper (correct method-name dispatch) and closes the home before
    -- opening the reader so the user lands directly on the page.
    local content_h = content:getSize().h
    return Widgets.tappable(content, w, content_h, function()
        if not h.book_file then return end
        local Homescreen = require("pen_homescreen")
        if Homescreen and Homescreen.close then pcall(Homescreen.close) end
        local BookOpen = require("pen_book_open")
        BookOpen.open(h.book_file, h.page)
    end)
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
