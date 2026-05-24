-- penjuru/pen_data
-- Centralized read access to KOReader's user data. Modules call here so
-- only this file knows about file paths, history format, .sdr layout.
-- Pure read; no mutations.

local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")

local M = {}

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
-- KOReader's history.lua is at <settings>/history.lua. Returns its
-- parsed table (a numbered list of { file = "...", time = N }, most
-- recent first), or empty table if absent.
function M.read_history()
    local DataStorage = require("datastorage")
    local path = DataStorage:getSettingsDir() .. "/history.lua"
    return M.parse_lua_file(path) or {}
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
        local ok, iter = pcall(lfs.dir, d)
        if not ok then return end
        for entry in iter do
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

return M
