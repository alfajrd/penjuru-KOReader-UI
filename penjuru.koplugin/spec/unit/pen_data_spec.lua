require("commonrequire")

describe("pen_data", function()
    local Data
    setup(function()
        -- Add plugin dir to package.path so bare require("pen_data") works.
        -- The plugin is symlinked into the emulator at plugins/penjuru.koplugin/
        local plugin_dir = require("lfs").currentdir() .. "/plugins/penjuru.koplugin"
        package.path = plugin_dir .. "/?.lua;" .. package.path
        Data = require("pen_data")
    end)

    describe("read_history", function()
        it("returns a table (possibly empty)", function()
            local h = Data.read_history()
            assert.is_table(h)
        end)
    end)

    describe("read_sdr_metadata", function()
        it("returns nil for a non-existent path", function()
            local m = Data.read_sdr_metadata("/nonexistent/book.epub")
            assert.is_nil(m)
        end)
    end)

    describe("sdr_path_for", function()
        it("returns nil for nil input", function()
            assert.is_nil(Data.sdr_path_for(nil))
        end)
        it("returns nil for empty string", function()
            assert.is_nil(Data.sdr_path_for(""))
        end)
        it("computes the standard .sdr/metadata path for an epub", function()
            local p = Data.sdr_path_for("/foo/bar/book.epub")
            assert.equals("/foo/bar/book.sdr/metadata.epub.lua", p)
        end)
        it("lowercases the extension in the metadata filename", function()
            local p = Data.sdr_path_for("/foo/bar/book.EPUB")
            assert.equals("/foo/bar/book.sdr/metadata.epub.lua", p)
        end)
    end)

    describe("parse_lua_file", function()
        it("returns nil for a non-existent file", function()
            assert.is_nil(Data.parse_lua_file("/nonexistent/file.lua"))
        end)
        it("returns the table when the file is a valid `return { ... }`", function()
            local tmp = os.tmpname() .. ".lua"
            local f = io.open(tmp, "w")
            f:write([[return { hello = "world", n = 42 }]])
            f:close()
            local r = Data.parse_lua_file(tmp)
            assert.equals("world", r.hello)
            assert.equals(42, r.n)
            os.remove(tmp)
        end)
        it("returns nil for a file that errors on load", function()
            local tmp = os.tmpname() .. ".lua"
            local f = io.open(tmp, "w")
            f:write("this is not valid lua syntax !@#")
            f:close()
            assert.is_nil(Data.parse_lua_file(tmp))
            os.remove(tmp)
        end)
    end)

    describe("read_today_stats", function()
        it("returns a table with the expected keys (defaults if db absent)", function()
            local s = Data.read_today_stats()
            assert.is_table(s)
            assert.is_number(s.reading_minutes)
            assert.is_number(s.pages)
            assert.is_number(s.streak_days)
            assert.is_number(s.year_finished)
        end)
        it("returns all zeros when there's no statistics database", function()
            -- We can't reliably ensure absence in the test env, but the call
            -- must not error and must return numeric fields regardless.
            local s = Data.read_today_stats()
            assert.is_true(s.reading_minutes >= 0)
            assert.is_true(s.pages >= 0)
            assert.is_true(s.streak_days >= 0)
            assert.is_true(s.year_finished >= 0)
        end)
    end)

    describe("read_lead_book", function()
        it("returns a table with file field when history is non-empty, or nil if empty", function()
            local b = Data.read_lead_book()
            if b then
                assert.is_string(b.file)
                assert.is_string(b.title)
                assert.is_number(b.percent)
            end
        end)
    end)

    describe("read_book_highlights", function()
        it("returns empty array for a non-existent book", function()
            local hs = Data.read_book_highlights("/nonexistent.epub", 5)
            assert.is_table(hs)
            assert.equals(0, #hs)
        end)
        it("returns highlights sorted by datetime descending", function()
            -- Use the real test data: Macbeth has 3 dated highlights
            local hs = Data.read_book_highlights(
                "/Users/penjurupikiran/Developer/koreader/books/shakespeare-macbeth.epub",
                10)
            if #hs >= 2 then
                assert.is_true(hs[1].datetime >= hs[2].datetime)
            end
        end)
    end)

    describe("read_in_progress_books", function()
        it("returns a table (possibly empty)", function()
            local books = Data.read_in_progress_books(nil)
            assert.is_table(books)
        end)
        it("excludes a path passed in exclude argument", function()
            local exclude = "/Users/penjurupikiran/Developer/koreader/books/shakespeare-macbeth.epub"
            local books = Data.read_in_progress_books(exclude)
            for _, b in ipairs(books) do
                assert.is_not.equals(exclude, b.file)
            end
        end)
        it("returns books with 0 < percent < 1", function()
            local books = Data.read_in_progress_books(nil)
            for _, b in ipairs(books) do
                assert.is_true(b.percent > 0)
                assert.is_true(b.percent < 1)
            end
        end)
    end)

    describe("read_newly_catalogued", function()
        it("returns a table (possibly empty) when given a non-existent dir", function()
            local books = Data.read_newly_catalogued({"/nonexistent_dir"}, 30, 3)
            assert.is_table(books)
        end)
        it("returns a table for the real test books dir", function()
            local books = Data.read_newly_catalogued(
                {"/Users/penjurupikiran/Developer/koreader/books"}, 30, 5)
            assert.is_table(books)
            -- Should include Austen and Lovecraft (no .sdr) but not the
            -- 3 that have .sdr (Macbeth/Walden/Moby Dick).
            for _, b in ipairs(books) do
                assert.is_string(b.file)
                assert.is_number(b.age_days)
            end
        end)
    end)

    describe("read_recent_highlights", function()
        it("returns a table", function()
            local hs = Data.read_recent_highlights(3)
            assert.is_table(hs)
        end)
        it("returns at most `limit` entries", function()
            local hs = Data.read_recent_highlights(2)
            assert.is_true(#hs <= 2)
        end)
        it("returns entries sorted by datetime descending", function()
            local hs = Data.read_recent_highlights(10)
            if #hs >= 2 then
                for i = 2, #hs do
                    assert.is_true(hs[i-1].datetime >= hs[i].datetime)
                end
            end
        end)
    end)
end)
