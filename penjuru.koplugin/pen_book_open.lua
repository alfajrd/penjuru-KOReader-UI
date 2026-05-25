-- penjuru/pen_book_open
-- Open a book and (optionally) seek to a specific page after it loads.
-- ReaderUI's showReader is asynchronous in terms of when goto is safe
-- (the document needs to load); we schedule the goto for ~0.5s later.

local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local logger = require("logger")

local M = {}

-- open(path, page) -> bool
-- `page` is optional. For paging documents (PDF, CBZ, DJVU) it's an
-- integer page number. For rolling documents (EPUB, FB2, HTML) KOReader
-- stores it as an xpointer string like "/body/DocFragment[5]/p[3]".
-- v1.2.12.2 fix: the old `page > 0` check crashed on EPUB highlights
-- (Lua errors on string-vs-number comparison). Dispatch GotoPage for
-- numbers and GotoXPointer for strings; silently skip anything else.
function M.open(path, page)
    if not path or path == "" then return false end
    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
    if not ok or not ReaderUI then return false end
    local ok2 = pcall(ReaderUI.showReader, ReaderUI, path)
    if not ok2 then return false end

    local goto_event
    if type(page) == "number" and page > 0 then
        goto_event = "GotoPage"
    elseif type(page) == "string" and page ~= "" then
        goto_event = "GotoXPointer"
    end
    if goto_event then
        -- Schedule the goto for after the reader has finished initializing.
        UIManager:scheduleIn(0.5, function()
            local inst = ReaderUI.instance
            if not inst then return end
            local ok_goto = pcall(function()
                inst:handleEvent(Event:new(goto_event, page))
            end)
            if not ok_goto then
                logger.warn("pen_book_open:", goto_event, "failed for", page)
            end
        end)
    end
    return true
end

return M
