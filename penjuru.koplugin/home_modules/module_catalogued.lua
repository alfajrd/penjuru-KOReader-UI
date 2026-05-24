-- home_modules/module_catalogued
-- "newly catalogued" — 3 rows of recently-added unstarted books, no
-- covers, big tap target. Title + age + chevron.

local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Style = require("pen_style")
local Widgets = require("pen_widgets")
local Data = require("pen_data")

local M = {}

local function pretty_age(days)
    if days <= 1 then return "1d"
    elseif days < 7 then return days .. "d"
    elseif days < 30 then return math.floor(days / 7) .. "w"
    else return math.floor(days / 30) .. "mo" end
end

local function book_row(w, book)
    local title_text = string.lower(book.title)
    if #title_text > 36 then title_text = title_text:sub(1, 35) .. "…" end
    local title = TextWidget:new{
        text = title_text,
        face = Style.fonts.headline(Style.size.cat_title),
        fgcolor = Style.colors.ink,
    }
    local age = TextWidget:new{
        text = pretty_age(book.age_days) .. " →",
        face = Style.fonts.numerals(Style.size.cat_age),
        fgcolor = Style.colors.ink_soft,
    }
    return VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = 12 },
        Widgets.spaced_row(w, { title, age }),
        VerticalSpan:new{ width = 12 },
        Widgets.dotted_rule(w, Style.rules.minor, Style.colors.rule_soft),
    }
end

-- user_book_dirs() -> array of dirs to scan
-- Pulls from G_reader_settings.penjuru.catalogue_dirs; defaults to the
-- emulator's books dir (real-Kindle install will override via settings).
local function user_book_dirs()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    if s.catalogue_dirs and #s.catalogue_dirs > 0 then return s.catalogue_dirs end
    -- Sensible default for the macOS emulator setup
    local home = os.getenv("HOME") or ""
    return { home .. "/Developer/koreader/books" }
end

function M.render(content_width)
    local books = Data.read_newly_catalogued(user_book_dirs(), 30, 3)
    local out = { Widgets.section_head(content_width, "newly catalogued") }
    if #books == 0 then
        table.insert(out, TextWidget:new{
            text = "nothing new",
            face = Style.fonts.italic(Style.size.body - 4),
            fgcolor = Style.colors.ink_faint,
        })
    else
        for _, b in ipairs(books) do
            table.insert(out, book_row(content_width, b))
        end
    end
    return VerticalGroup:new{ align = "left", table.unpack(out) }
end

return M
