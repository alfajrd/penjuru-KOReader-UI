-- penjuru/pen_book_open
-- Open a book and (optionally) seek to a specific page after it loads.
-- ReaderUI's showReader is asynchronous in terms of when goto is safe
-- (the document needs to load); we schedule the goto for ~0.5s later.

local UIManager = require("ui/uimanager")
local Event = require("ui/event")
local logger = require("logger")

local M = {}

-- open(path, page) -> bool
-- page is optional (1-indexed). If nil, just opens the book to its last
-- known location.
function M.open(path, page)
    if not path or path == "" then return false end
    local ok, ReaderUI = pcall(require, "apps/reader/readerui")
    if not ok or not ReaderUI then return false end
    local ok2 = pcall(ReaderUI.showReader, ReaderUI, path)
    if not ok2 then return false end
    if page and page > 0 then
        -- Schedule the goto for after the reader has finished initializing.
        UIManager:scheduleIn(0.5, function()
            local inst = ReaderUI.instance
            if not inst then return end
            local ok_goto = pcall(function()
                inst:handleEvent(Event:new("GotoPage", page))
            end)
            if not ok_goto then
                logger.warn("pen_book_open: GotoPage failed for page", page)
            end
        end)
    end
    return true
end

return M
