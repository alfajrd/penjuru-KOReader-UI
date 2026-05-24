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
    local content = VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = 12 },
        Widgets.spaced_row(w, { title, age }),
        VerticalSpan:new{ width = 12 },
        Widgets.dotted_rule(w, Style.rules.minor, Style.colors.rule_soft),
    }

    -- Tap-to-open: close the home overlay first, then open the book via
    -- pen_book_open (handles ReaderUI:showReader + scheduling). Uses the
    -- shared Widgets.tappable wrapper so the broken handler= antipattern
    -- never reappears here (see pen_widgets for design notes).
    local content_h = content:getSize().h
    return Widgets.tappable(content, w, content_h, function()
        if not book.file then return end
        local Homescreen = require("pen_homescreen")
        if Homescreen and Homescreen.close then pcall(Homescreen.close) end
        local BookOpen = require("pen_book_open")
        BookOpen.open(book.file)
    end)
end

-- user_book_dirs() -> array of dirs to scan
-- Pulls from G_reader_settings.penjuru.catalogue_dirs. Defaults are
-- environment-aware: on a real Kindle, scan /mnt/us/books + /mnt/us/manga
-- (typical Kindle layout). On the macOS emulator, scan the dev books dir.
-- v1.1 onboarding will detect these or let the user pick.
local function user_book_dirs()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    if s.catalogue_dirs and #s.catalogue_dirs > 0 then return s.catalogue_dirs end
    local ok, lfs = pcall(require, "libs/libkoreader-lfs")
    if ok and lfs.attributes("/mnt/us/books") then
        local dirs = { "/mnt/us/books" }
        if lfs.attributes("/mnt/us/mangas") then table.insert(dirs, "/mnt/us/mangas") end
        return dirs
    end
    -- Fallback for the macOS emulator
    local home = os.getenv("HOME") or ""
    return { home .. "/Developer/koreader/books" }
end

local function user_threshold()
    local s = (rawget(_G, "G_reader_settings") and G_reader_settings:readSetting("penjuru")) or {}
    return (s.newly and s.newly.threshold_days) or 30
end

function M.render(content_width)
    local books = Data.read_newly_catalogued(user_book_dirs(), user_threshold(), 3)
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
