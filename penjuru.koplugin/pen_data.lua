-- penjuru/pen_data
-- Centralized read access to KOReader's user data. Modules call here so
-- only this file knows about file paths, history format, .sdr layout.
-- Pure read; no mutations.

local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local M = {}

-- KOReader's per-book metadata stores `doc_props.authors` and `.title` as
-- either a string OR a table (multiple authors → newline-joined string in
-- newer KOReader, table in older). Title is usually a string but defensive
-- coercion costs nothing. Falls back to "" so callers can safely concatenate.
local function as_text(v)
    if v == nil then return "" end
    if type(v) == "string" then return v end
    if type(v) == "table" then return table.concat(v, ", ") end
    return tostring(v)
end

-- parse_lua_file(path) -> table | nil
-- Loads a file expected to be `return { ... }`. Used for KOReader's
-- history.lua and per-book .sdr/metadata.lua files. Errors during load
-- are logged and produce nil — callers handle missing data gracefully.
function M.parse_lua_file(path)
    local ok_stat, stat = pcall(lfs.attributes, path)
    if not ok_stat or not stat then return nil end
    local chunk, err = loadfile(path)
    if not chunk then
        logger.warn("pen_data: failed to load", path, err)
        return nil
    end
    local ok, result = pcall(chunk)
    if not ok or type(result) ~= "table" then
        logger.warn("pen_data: invalid table in", path, result)
        return nil
    end
    return result
end

-- read_history() -> table
-- KOReader's history.lua lives at the data dir ROOT (e.g.
-- /mnt/us/koreader/history.lua), NOT inside settings/. Verified on a
-- real Kindle Paperwhite running KOReader 2026.x. Returns the parsed
-- table (a numbered list of { file = "...", time = N }, most-recent
-- first), or empty table if absent. We try the data dir first, fall
-- back to settings/ for compatibility with older KOReader layouts.
function M.read_history()
    local DataStorage = require("datastorage")
    local data_path = DataStorage:getDataDir() .. "/history.lua"
    local result = M.parse_lua_file(data_path)
    if result then return result end
    local settings_path = DataStorage:getSettingsDir() .. "/history.lua"
    return M.parse_lua_file(settings_path) or {}
end

-- sdr_path_for(book_path) -> string | nil
-- Given /path/to/book.epub, returns /path/to/book.sdr/metadata.epub.lua
function M.sdr_path_for(book_path)
    if not book_path or book_path == "" then return nil end
    local dir, name = book_path:match("(.*)/(.*)$")
    if not dir or not name then return nil end
    local stem, ext = name:match("(.*)%.(.*)$")
    if not stem or not ext then return nil end
    return dir .. "/" .. stem .. ".sdr/metadata." .. ext:lower() .. ".lua"
end

-- read_sdr_metadata(book_path) -> table | nil
function M.read_sdr_metadata(book_path)
    local p = M.sdr_path_for(book_path)
    if not p then return nil end
    return M.parse_lua_file(p)
end

-- file_mtime(path) -> number | nil
function M.file_mtime(path)
    local ok, stat = pcall(lfs.attributes, path)
    if not ok or not stat then return nil end
    return stat.modification
end

-- list_books_in(dir) -> array of absolute paths
-- Walks `dir` recursively, returning every file whose extension is in
-- KOReader's supported set. Hidden files and .sdr/ folders are skipped.
local SUPPORTED_EXTS = {
    epub=true, pdf=true, mobi=true, azw=true, azw3=true, cbz=true, cbr=true,
    fb2=true, djvu=true, txt=true, rtf=true, html=true, htm=true, doc=true,
    docx=true, odt=true, chm=true, zip=true,
}
function M.list_books_in(dir)
    local out = {}
    local function walk(d)
        local ok, iter, dir_obj = pcall(lfs.dir, d)
        if not ok or not iter then return end
        for entry in iter, dir_obj do
            if entry:sub(1,1) ~= "." then
                local full = d .. "/" .. entry
                local attr = lfs.attributes(full)
                if attr and attr.mode == "directory" then
                    if not entry:match("%.sdr$") then walk(full) end
                elseif attr then
                    local ext = entry:match("%.([^.]+)$")
                    if ext and SUPPORTED_EXTS[ext:lower()] then
                        table.insert(out, full)
                    end
                end
            end
        end
    end
    walk(dir)
    return out
end

-- read_today_stats() -> { reading_minutes, pages, streak_days, year_finished }
-- Reads KOReader's statistics.sqlite3. Returns sensible zeros if the db
-- is absent (e.g. user hasn't enabled the Statistics plugin yet).
function M.read_today_stats()
    local default = {
        reading_minutes = 0, pages = 0, streak_days = 0, year_finished = 0,
    }
    local DataStorage = require("datastorage")
    local path = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    local stat = lfs.attributes(path)
    if not stat then return default end

    local ok_sql, SQ3 = pcall(require, "lua-ljsqlite3/init")
    if not ok_sql then return default end
    local ok_db, db = pcall(SQ3.open, path)
    if not ok_db or not db then return default end

    local function scalar(sql)
        local ok, stmt = pcall(db.prepare, db, sql)
        if not ok or not stmt then return nil end
        local row_ok, row = pcall(stmt.step, stmt)
        local v = (row_ok and row) and row[1] or nil
        pcall(stmt.close, stmt)
        return v
    end

    -- "today" = local-time start-of-day to start-of-tomorrow.
    local now = os.date("*t")
    local day_start = os.time{ year = now.year, month = now.month, day = now.day, hour = 0 }
    local day_end = day_start + 86400

    -- ljsqlite3 returns LuaJIT cdata integers; tonumber() converts to plain Lua
    -- numbers so that math.floor / arithmetic work without type errors.
    local reading_seconds = tonumber(scalar(string.format(
        "SELECT IFNULL(SUM(duration), 0) FROM page_stat_data WHERE start_time >= %d AND start_time < %d",
        day_start, day_end))) or 0
    local pages_today = tonumber(scalar(string.format(
        "SELECT COUNT(DISTINCT id_book || ':' || page) FROM page_stat_data WHERE start_time >= %d AND start_time < %d",
        day_start, day_end))) or 0

    -- Streak: walk backwards day by day until we find a past day with
    -- no rows. Today itself can be empty (no penalty).
    local streak = 0
    local cursor = day_start
    while true do
        local n = tonumber(scalar(string.format(
            "SELECT COUNT(*) FROM page_stat_data WHERE start_time >= %d AND start_time < %d",
            cursor, cursor + 86400))) or 0
        if n > 0 then
            streak = streak + 1
            cursor = cursor - 86400
        else
            if cursor == day_start then
                cursor = cursor - 86400  -- skip empty today, keep checking
            else
                break
            end
        end
        if streak > 365 then break end  -- safety
    end

    -- Books finished this year: total_read_pages >= pages, last_open in year.
    local year_start = os.time{ year = now.year, month = 1, day = 1, hour = 0 }
    local year_finished = tonumber(scalar(string.format(
        "SELECT COUNT(*) FROM book WHERE total_read_pages >= pages AND pages > 0 AND last_open >= %d",
        year_start))) or 0

    pcall(db.close, db)
    return {
        reading_minutes = math.floor((reading_seconds or 0) / 60),
        pages = pages_today,
        streak_days = streak,
        year_finished = year_finished,
    }
end

-- read_lead_book() -> table | nil
-- Returns metadata for the most recently opened book, or nil if history empty.
function M.read_lead_book()
    local history = M.read_history()
    if #history == 0 then return nil end
    local top = history[1]
    if not top or not top.file then return nil end

    local sdr = M.read_sdr_metadata(top.file) or {}
    local doc_props = sdr.doc_props or {}
    local pages = sdr.doc_pages or (sdr.stats and sdr.stats.pages) or 0
    local percent = sdr.percent_finished or 0
    local title = as_text(doc_props.title)
    if title == "" then
        title = top.file:match("([^/]+)%.[^.]+$") or "untitled"
    end
    return {
        file = top.file,
        title = title,
        author = as_text(doc_props.authors),
        year = as_text(doc_props.year),
        percent = percent,
        pages_total = pages,
        page_current = math.floor(percent * pages + 0.5),
        last_read_ts = top.time or 0,
    }
end

-- read_book_highlights(book_path, limit) -> array of { text, datetime, page }
--
-- Schema note (v1.2.13 fix): KOReader's per-book annotation storage moved
-- from `bookmarks` → `annotations` a couple years back. In the new format,
-- the highlighted TEXT is in `.notes` (yes, confusingly named — `.text`
-- holds the user's optional COMMENT). Legacy bookmarks kept the highlighted
-- text in `.text`. We try both fields so highlights surface on any vintage
-- of .sdr file.
function M.read_book_highlights(book_path, limit)
    limit = limit or 1
    local sdr = M.read_sdr_metadata(book_path)
    if not sdr then return {} end
    local items = sdr.annotations or sdr.bookmarks or {}
    local hs = {}
    for _, item in ipairs(items) do
        local text = item.notes or item.text
        if text and text ~= "" then
            table.insert(hs, {
                text = text,
                datetime = item.datetime or "",
                page = item.page or 0,
            })
        end
    end
    table.sort(hs, function(a, b) return a.datetime > b.datetime end)
    local out = {}
    for i = 1, math.min(limit, #hs) do out[i] = hs[i] end
    return out
end

-- read_in_progress_books(exclude_path) -> array of { file, title, percent, last_read_ts }
-- Books from history with 0 < percent_finished < 1, sorted by last_read_ts desc.
function M.read_in_progress_books(exclude_path)
    local history = M.read_history()
    local seen, out = {}, {}
    for _, entry in ipairs(history) do
        if entry.file and entry.file ~= exclude_path and not seen[entry.file] then
            seen[entry.file] = true
            local sdr = M.read_sdr_metadata(entry.file) or {}
            local pct = sdr.percent_finished or 0
            if pct > 0 and pct < 1 then
                local props = sdr.doc_props or {}
                local t = as_text(props.title)
                if t == "" then
                    t = entry.file:match("([^/]+)%.[^.]+$") or "untitled"
                end
                table.insert(out, {
                    file = entry.file,
                    title = t,
                    percent = pct,
                    last_read_ts = entry.time or 0,
                })
            end
        end
    end
    table.sort(out, function(a, b) return a.last_read_ts > b.last_read_ts end)
    return out
end

-- read_book_cover(book_path, target_w, target_h) -> BlitBuffer | nil
-- Returns a scaled cover image, or nil if the file can't be read.
--
-- v1.2.13.1: defer to KOReader's official FileManagerBookInfo.getCoverImage
-- when available — it handles three things the raw DocumentRegistry call
-- missed:
--   1. Custom cover sidecars (`<book>.sdr/cover.<ext>`) take precedence.
--   2. CreDocument (EPUB / FB2) needs loadDocument(false) before
--      getCoverPageImage to populate metadata.
--   3. The flow is the same one CoverBrowser uses, so anything that
--      renders in your file browser will render here too — including
--      CBZ/CBR mangas where the koptinterface renders page 1 as the cover.
function M.read_book_cover(book_path, target_w, target_h)
    if not book_path or book_path == "" then return nil end
    local cover_bb
    local ok_bi, BookInfo = pcall(require, "apps/filemanager/filemanagerbookinfo")
    if ok_bi and BookInfo and BookInfo.getCoverImage then
        -- getCoverImage uses `:` syntax but never reads self; nil is fine.
        local ok_call, bb = pcall(BookInfo.getCoverImage, nil, nil, book_path, false)
        if ok_call then cover_bb = bb end
    end
    -- Last-ditch fallback: the original raw path, in case BookInfo isn't
    -- available (e.g. very old KOReader build).
    if not cover_bb then
        local ok, DocumentRegistry = pcall(require, "document/documentregistry")
        if not ok then return nil end
        local doc = DocumentRegistry:openDocument(book_path)
        if not doc then
            logger.warn("pen_data: openDocument failed for", book_path)
            return nil
        end
        if doc.loadDocument then pcall(doc.loadDocument, doc, false) end
        cover_bb = doc:getCoverPageImage()
        pcall(doc.close, doc)
    end
    if not cover_bb then
        logger.warn("pen_data: no cover image returned for", book_path)
        return nil
    end
    if cover_bb.scale then
        return cover_bb:scale(target_w, target_h)
    end
    return cover_bb
end

-- read_newly_catalogued(dirs, age_days, limit) -> array of { file, title, author, age_days, mtime }
-- Files in `dirs` whose mtime is within `age_days` AND have no .sdr
-- sidecar (i.e. never opened). Sorted by mtime desc, capped at `limit`.
function M.read_newly_catalogued(dirs, age_days, limit)
    age_days = age_days or 30
    limit = limit or 3
    local cutoff = os.time() - age_days * 86400
    local candidates = {}
    for _, dir in ipairs(dirs or {}) do
        for _, path in ipairs(M.list_books_in(dir)) do
            local mt = M.file_mtime(path)
            if mt and mt >= cutoff then
                local sdr_path = M.sdr_path_for(path)
                local has_sdr = sdr_path and lfs.attributes(sdr_path) ~= nil
                if not has_sdr then
                    local name = path:match("([^/]+)%.[^.]+$") or path
                    table.insert(candidates, {
                        file = path,
                        title = name,
                        author = "",  -- no .sdr means we can't get author cheaply
                        age_days = math.floor((os.time() - mt) / 86400),
                        mtime = mt,
                    })
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return a.mtime > b.mtime end)
    local out = {}
    for i = 1, math.min(limit, #candidates) do out[i] = candidates[i] end
    return out
end

-- read_recent_highlights(limit) -> array of { text, book_title, book_author, page, datetime, book_file }
-- Aggregates highlights from every book in history, sorts by datetime desc.
-- Reads both `annotations` (new KOReader) and `bookmarks` (legacy) per-book;
-- see read_book_highlights above for the schema rationale.
function M.read_recent_highlights(limit)
    limit = limit or 3
    local history = M.read_history()
    local all = {}
    for _, entry in ipairs(history) do
        if entry.file then
            local sdr = M.read_sdr_metadata(entry.file) or {}
            local props = sdr.doc_props or {}
            local items = sdr.annotations or sdr.bookmarks or {}
            for _, item in ipairs(items) do
                local text = item.notes or item.text
                if text and text ~= "" then
                    local bt = as_text(props.title)
                    if bt == "" then bt = "untitled" end
                    table.insert(all, {
                        text = text,
                        datetime = item.datetime or "",
                        page = item.page or 0,
                        book_file = entry.file,
                        book_title = bt,
                        book_author = as_text(props.authors),
                    })
                end
            end
        end
    end
    table.sort(all, function(a, b) return a.datetime > b.datetime end)
    local out = {}
    for i = 1, math.min(limit, #all) do out[i] = all[i] end
    return out
end

return M
