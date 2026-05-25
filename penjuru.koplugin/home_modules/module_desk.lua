-- home_modules/module_desk
-- "on the desk" — 5 cover thumbnails of in-progress books with a %
-- band below each cover. Excludes the lead book.

local Blitbuffer = require("ffi/blitbuffer")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local COVER_COUNT = 5
local COVER_GAP = 11

local function cover_cell(cell_w, book)
    local cell_h = math.floor(cell_w * 1.5)  -- 2:3 aspect

    local cover_widget
    local cover_bb = book.file and Data.read_book_cover(book.file, cell_w, cell_h)
    if cover_bb then
        cover_widget = ImageWidget:new{ image = cover_bb, width = cell_w, height = cell_h }
    else
        cover_widget = FrameContainer:new{
            background = Style.colors.rule_dim,
            bordersize = 2,
            margin = 0, padding = 0,
            VerticalSpan:new{ width = cell_h },
        }
    end

    local pct_text = math.floor((book.percent or 0) * 100 + 0.5) .. "%"
    local pct_band_h = math.floor(cell_h * 0.16)
    local pct_band = FrameContainer:new{
        background = Blitbuffer.COLOR_BLACK,
        bordersize = 0, margin = 0, padding = 4,
        TextWidget:new{
            text = pct_text,
            face = Style.fonts.numerals(math.floor(pct_band_h * 0.75)),
            fgcolor = Style.colors.paper,
        },
    }

    local caption_text = string.lower(book.title or "")
    if #caption_text > 18 then caption_text = caption_text:sub(1, 17) .. "…" end
    local caption = TextWidget:new{
        text = caption_text,
        face = Style.fonts.body(Style.size.caption - 4),
        fgcolor = Style.colors.ink_soft,
    }

    local cell = VerticalGroup:new{
        align = "center",
        cover_widget,
        pct_band,
        VerticalSpan:new{ width = 4 },
        caption,
    }

    -- v1.2.10: each cover is its own tap target. Tap → close home →
    -- open the book at its last-known position. cell_w / cell_size.h
    -- bound the tap exactly to the cover stack (image + % band + caption).
    local cell_size = cell:getSize()
    if not book.file then return cell end
    return Widgets.tappable(cell, cell_size.w, cell_size.h, function()
        local Homescreen = require("pen_homescreen")
        if Homescreen and Homescreen.close then pcall(Homescreen.close) end
        local BookOpen = require("pen_book_open")
        BookOpen.open(book.file)
    end)
end

function M.render(content_width)
    local lead = Data.read_lead_book()
    local books = Data.read_in_progress_books(lead and lead.file)

    local cell_w = math.floor((content_width - COVER_GAP * (COVER_COUNT - 1)) / COVER_COUNT)
    local row = HorizontalGroup:new{ align = "top" }
    for i = 1, COVER_COUNT do
        local book = books[i]
        if book then
            table.insert(row, cover_cell(cell_w, book))
        else
            -- placeholder spacer for empty slot to keep grid alignment
            table.insert(row, VerticalSpan:new{ width = cell_w })
        end
        if i < COVER_COUNT then
            table.insert(row, HorizontalSpan:new{ width = COVER_GAP })
        end
    end

    return VerticalGroup:new{
        align = "left",
        Widgets.section_head(content_width, "on the desk"),
        row,
    }
end

return M
