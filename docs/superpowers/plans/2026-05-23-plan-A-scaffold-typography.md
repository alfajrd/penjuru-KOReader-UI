# penjuru.koplugin · Plan A — Scaffold + Typography

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the `penjuru.koplugin` skeleton on a local KOReader emulator with the design's typography (Plex Mono · Syne Mono · VT323) loaded, a stripped-down file layout (no SimpleUI features we won't use), and a placeholder home screen that renders the masthead. After this plan: the emulator launches, the plugin is enabled via the menu, and the home screen shows `penjuru pikiran · a reader's almanac · mind-wide` in the right typography.

**Architecture:** Fork [doctorhetfield-cmd/simpleui.koplugin](https://github.com/doctorhetfield-cmd/simpleui.koplugin) (already studied in [docs/superpowers/specs/2026-05-23-koreader-ui-design.md](../specs/2026-05-23-koreader-ui-design.md)). Keep its KOReader-monkey-patching machinery (`sui_patches.lua`, `sui_core.lua`) and module-registry pattern (`desktop_modules/moduleregistry.lua`). Rename `sui_*` → `pen_*` throughout. Replace its style/typography layer with one that loads bundled TTFs from `fonts/`. Delete the modules and features we don't use (folder covers, browse-by-author, all built-in home modules) so subsequent plans build on a minimal base. Develop against KOReader's SDL emulator running on macOS, not directly against the Kindle, for fast iteration.

**Tech Stack:**
- KOReader 2024+ (Lua 5.1, SDL2 emulator on macOS for dev, ARM cross-compile for Kindle)
- Lua 5.1 (KOReader is locked to this)
- busted (Lua test framework, ships with KOReader)
- Homebrew (macOS build deps)
- Fonts: IBM Plex Mono · Syne Mono · VT323 (all OFL/SIL)

---

## Phase 0 · Dev environment

The KOReader emulator on macOS runs the same Lua you'll ship to the Kindle. Building it once gives us a 1-second feedback loop instead of copying the plugin to a real device every iteration.

### Task 0.1: Install macOS build dependencies

**Files:** none.

- [ ] **Step 1: Install KOReader's build deps via Homebrew**

Run:
```bash
brew install autoconf automake cmake coreutils libtool luarocks make nasm ninja pkg-config sdl2 wget
```

Expected output: `==> Installing ... ==> Pouring ...` for any missing formulas, or a list ending in "already installed" lines. Should exit 0.

- [ ] **Step 2: Verify the GNU coreutils are on PATH**

KOReader's build needs GNU `readlink` and `gmake` from coreutils, not BSD versions. Run:
```bash
ls /opt/homebrew/opt/coreutils/libexec/gnubin/readlink
which gmake
```

Expected output: the readlink path exists, `gmake` resolves to `/opt/homebrew/bin/gmake` (or similar).

If `gmake` is missing, run `brew install make`. The build's Makefiles expect `gmake` on macOS.

### Task 0.2: Clone KOReader for the emulator

**Files:**
- Create: `~/Developer/koreader/` (clone outside our plugin project)

- [ ] **Step 1: Clone the KOReader repo with submodules**

Run:
```bash
cd ~/Developer
git clone --recursive https://github.com/koreader/koreader.git
cd koreader
git log -1 --oneline
```

Expected output: clone completes; final command prints a recent commit on master like `abc1234 Bump version to 2026.xx`.

- [ ] **Step 2: Pin to a known-good release tag**

Master can have ABI churn that breaks plugins. Pin to the latest stable release:
```bash
cd ~/Developer/koreader
LATEST=$(git tag --sort=-v:refname | grep -E '^v?20[0-9]{2}\.[0-9]{1,2}(\.[0-9]+)?$' | head -1)
echo "Pinning to: $LATEST"
git checkout "$LATEST"
git submodule update --init --recursive
```

Expected output: `Pinning to: v2025.x` or similar, then `HEAD is now at ...`.

### Task 0.3: Build the SDL emulator

**Files:** none (build artifacts only).

- [ ] **Step 1: Run the emulator build**

Run:
```bash
cd ~/Developer/koreader
./kodev fetch-thirdparty
./kodev build
```

Expected: 2–8 minutes of compile output. Ends with no errors and produces `~/Developer/koreader/koreader-emulator-x86_64-darwin/`.

If you hit `error: SDL2/SDL.h not found`, ensure `pkg-config --libs sdl2` outputs `-lSDL2` and re-run `./kodev build`.

- [ ] **Step 2: Run the emulator once to smoke-test the build**

Run:
```bash
cd ~/Developer/koreader
./kodev run
```

Expected: an SDL window opens showing KOReader's file browser at `~/Developer/koreader/`. Close it (Cmd-Q) once you see the UI.

- [ ] **Step 3: Commit a note recording the build state**

Back in the plugin project:
```bash
cd ~/Developer/koreader-custom-ui
KOREADER_TAG=$(cd ~/Developer/koreader && git describe --tags --always)
mkdir -p docs/dev
cat > docs/dev/emulator.md <<EOF
# Emulator setup

Built against KOReader \`$KOREADER_TAG\` (pinned).
Source: \`~/Developer/koreader\`
Run with: \`cd ~/Developer/koreader && ./kodev run\`

Plugin install path during dev: \`~/Developer/koreader/plugins/penjuru.koplugin/\`
(Create as a symlink to this repo so edits are picked up live.)
EOF
git add docs/dev/emulator.md
git commit -m "docs: record KOReader emulator setup"
```

Expected: commit succeeds; the noted tag will be used as the reference KOReader version in subsequent plans.

---

## Phase 1 · Plugin scaffold

Fork SimpleUI in-place inside our project, rename everything, delete what we won't use. End state: an empty-but-loadable `penjuru.koplugin/` that shows up in KOReader's plugin list.

### Task 1.1: Pull SimpleUI source into the project

**Files:**
- Create: `penjuru.koplugin/` (the plugin folder, peer to `docs/`)

- [ ] **Step 1: Clone SimpleUI as a temporary working copy**

Run:
```bash
cd /tmp
git clone https://github.com/doctorhetfield-cmd/simpleui.koplugin.git
cd simpleui.koplugin
git log -1 --oneline
```

Expected: clone succeeds, prints a recent commit (it was updated 2026-05-22).

- [ ] **Step 2: Copy the Lua source into our plugin folder**

Run:
```bash
mkdir -p ~/Developer/koreader-custom-ui/penjuru.koplugin
cd /tmp/simpleui.koplugin
cp -R _meta.lua main.lua sui_*.lua desktop_modules icons locale ~/Developer/koreader-custom-ui/penjuru.koplugin/
```

Note: we are intentionally NOT copying SimpleUI's `Makefile`, `README.md`, `LICENSE`, `extract_strings.py`, `CONTRIBUTING.md`, or `.github/` — we'll add our own. We are also NOT copying any `.git/` data, so this becomes a clean unforked copy.

- [ ] **Step 3: Verify the copy and commit the unmodified snapshot**

Run:
```bash
cd ~/Developer/koreader-custom-ui
ls penjuru.koplugin/
git add penjuru.koplugin/
git commit -m "feat: vendor simpleui.koplugin source as starting point

Unmodified copy of doctorhetfield-cmd/simpleui.koplugin @ <commit> for
the penjuru fork. License-compatible (both MIT). Subsequent commits
rename, prune, and replace per docs/superpowers/specs/2026-05-23-...md."
```

Replace `<commit>` with the short hash from Step 1. Expected: 25+ files added, commit succeeds.

### Task 1.2: Update `_meta.lua` and add LICENSE

**Files:**
- Modify: `penjuru.koplugin/_meta.lua`
- Create: `penjuru.koplugin/LICENSE`

- [ ] **Step 1: Rewrite `_meta.lua`**

Replace the entire contents of `penjuru.koplugin/_meta.lua` with:
```lua
return {
    name        = "penjuru",
    fullname    = "penjuru",
    description = [[a reader's almanac — newspaper-flavored home screen for kindle.]],
    version     = "0.1.0",
    author      = "alfajrd",
}
```

- [ ] **Step 2: Add an MIT LICENSE with attribution to SimpleUI**

Create `penjuru.koplugin/LICENSE` with:
```
MIT License

Copyright (c) 2026 alfajrd
Portions Copyright (c) 2024–2026 Doctor Hetfield (simpleui.koplugin)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/_meta.lua penjuru.koplugin/LICENSE
git commit -m "feat: rename plugin to penjuru, add MIT LICENSE with SimpleUI attribution"
```

### Task 1.3: Symlink the plugin into the emulator and verify it loads

**Files:** none (symlink only).

- [ ] **Step 1: Create the symlink**

Run:
```bash
mkdir -p ~/Developer/koreader/plugins
ln -sf ~/Developer/koreader-custom-ui/penjuru.koplugin ~/Developer/koreader/plugins/penjuru.koplugin
ls -la ~/Developer/koreader/plugins/penjuru.koplugin
```

Expected: symlink points to the project folder.

- [ ] **Step 2: Launch the emulator and confirm the plugin appears**

Run:
```bash
cd ~/Developer/koreader && ./kodev run
```

In the emulator:
1. Open the menu (top-right hamburger or Cmd-M).
2. Navigate to **Tools → Plugin management**.
3. Look for `penjuru` in the list.

Expected: `penjuru` is listed (because it inherits SimpleUI's main.lua menu registration). Enable it. KOReader may prompt for a restart — click "Restart now".

- [ ] **Step 3: After restart, confirm a menu entry exists**

In the emulator menu, navigate to **Tools → SimpleUI** (still labeled as SimpleUI internally — we rename in the next phase). Expected: a settings submenu opens. Close the emulator (Cmd-Q).

- [ ] **Step 4: Commit the verified state**

```bash
cd ~/Developer/koreader-custom-ui
git commit --allow-empty -m "verify: plugin loads in koreader emulator and shows in plugin management"
```

### Task 1.4: Prune SimpleUI files we won't use

The spec lists what's out of scope (folder covers, browse-by-author/series/tags, quote-of-day from external corpus). Their source files can go now.

**Files:**
- Delete: `penjuru.koplugin/sui_foldercovers.lua`
- Delete: `penjuru.koplugin/sui_browsemeta.lua`
- Delete: `penjuru.koplugin/sui_presets.lua` (we have one locked aesthetic)
- Delete: `penjuru.koplugin/sui_updater.lua` (no built-in updater for v1)
- Delete: `penjuru.koplugin/desktop_modules/quotes.lua` (replaced by user-highlight quotes)
- Delete: `penjuru.koplugin/desktop_modules/module_quote.lua` (will be rewritten as `module_highlights.lua` in Plan B)
- Delete: `penjuru.koplugin/desktop_modules/module_tbr.lua` (replaced by `module_newly_catalogued.lua` in Plan B)
- Delete: `penjuru.koplugin/desktop_modules/module_coverdeck.lua` (out of scope)

- [ ] **Step 1: Delete the files**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
rm sui_foldercovers.lua sui_browsemeta.lua sui_presets.lua sui_updater.lua
rm desktop_modules/quotes.lua desktop_modules/module_quote.lua
rm desktop_modules/module_tbr.lua desktop_modules/module_coverdeck.lua
ls *.lua desktop_modules/*.lua
```

Expected: file list no longer contains the deleted names.

- [ ] **Step 2: Find and remove `require`s of the deleted modules**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
grep -rn 'sui_foldercovers\|sui_browsemeta\|sui_presets\|sui_updater\|module_quote\|module_tbr\|module_coverdeck' .
```

For each match, open the file and delete or comment out the `require(...)` line and any references that depend on it. Most matches will be in `main.lua`, `sui_menu.lua`, and `desktop_modules/moduleregistry.lua`. Replace any `require("...")` that fails to resolve with `-- removed: <name>` so the code parses but does nothing for that module.

After editing, re-run the grep — expected output should be empty (or only `-- removed: ...` comment matches).

- [ ] **Step 3: Launch the emulator and verify no load errors**

Run:
```bash
cd ~/Developer/koreader && ./kodev run 2>&1 | grep -iE 'error|fail|cannot' | head -20
```

Open the menu → Tools → SimpleUI in the emulator. Expected: opens without error popups. If a popup appears citing "module 'X' not found", fix the corresponding `require` and retry.

Quit the emulator. Expected: the grep output above should have no `error` / `fail` lines related to penjuru.

- [ ] **Step 4: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add -A penjuru.koplugin/
git commit -m "refactor: remove simpleui modules and features out of scope for penjuru v1

Dropped: folder covers, browse-meta variants, presets, updater,
quote-of-day from corpus, TBR (replaced by newly-catalogued in Plan B),
coverdeck."
```

### Task 1.5: Rename `sui_*` and `SUI` identifiers to `pen_*` / `PEN`

**Files:** all remaining `.lua` files in `penjuru.koplugin/`.

- [ ] **Step 1: Rename the files**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
for f in sui_*.lua; do
  newname="pen_${f#sui_}"
  git mv "$f" "$newname"
done
ls *.lua
```

Expected: every file is now `pen_*.lua` — `pen_bottombar.lua`, `pen_config.lua`, `pen_core.lua`, `pen_homescreen.lua`, `pen_i18n.lua`, `pen_menu.lua`, `pen_patches.lua`, `pen_quickactions.lua`, `pen_store.lua`, `pen_style.lua`, `pen_titlebar.lua`, `pen_topbar.lua`.

- [ ] **Step 2: Rewrite all internal `require` and identifier references**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
# require("sui_xxx") -> require("penjuru.pen_xxx")
# Important: KOReader resolves plugin requires relative to the plugin's
# folder name, which is "penjuru.koplugin". The require path is the folder
# stem joined with the file stem.
find . -name '*.lua' -print0 | xargs -0 sed -i '' \
  -e 's|require("sui_|require("penjuru/pen_|g' \
  -e "s|require('sui_|require('penjuru/pen_|g"
```

Note the directory separator: KOReader's Lua `package.path` uses `/` (or `.`) as a path separator depending on how the plugin manager resolves it. SimpleUI's existing code uses bare `require("sui_xxx")` because of how its main.lua sets `package.path`. Inspect `main.lua` to confirm the convention before this step, and adjust the sed expression to match (e.g. if main.lua adds the plugin folder to package.path so bare names resolve, the replacement becomes `require("pen_` instead of `require("penjuru/pen_`).

- [ ] **Step 3: Rename SUI variable / constant identifiers**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
find . -name '*.lua' -print0 | xargs -0 sed -i '' \
  -e 's/\bSUI\b/PEN/g' \
  -e 's/\bsimpleui\b/penjuru/g' \
  -e 's/\bSimpleUI\b/penjuru/g'
```

- [ ] **Step 4: Confirm no stray `sui` references remain in functional code**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
grep -rn '\bsui\b\|\bSUI\b\|\bsimpleui\b\|\bSimpleUI\b' . | grep -v -i 'simpleui.koplugin' | grep -v '\-\-'
```

Expected: empty output, or only entries inside comments referencing the upstream attribution. Any remaining functional reference is a bug — fix in place.

- [ ] **Step 5: Verify the emulator still loads**

```bash
cd ~/Developer/koreader && ./kodev run
```

Open menu → Tools → **penjuru** (it should now be relabeled). Confirm the settings submenu opens. Close emulator.

- [ ] **Step 6: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add -A penjuru.koplugin/
git commit -m "refactor: rename sui_* -> pen_*, SUI -> PEN, simpleui -> penjuru"
```

---

## Phase 2 · Typography

Drop in the three webfonts as bundled TTFs and wire `pen_style.lua` to use them as the base for every text widget. This phase ends with KOReader rendering its own UI in our typography (any screen, not just home) so we know the swap actually took.

### Task 2.1: Bundle the font files

**Files:**
- Create: `penjuru.koplugin/fonts/IBMPlexMono-Regular.ttf`
- Create: `penjuru.koplugin/fonts/IBMPlexMono-Italic.ttf`
- Create: `penjuru.koplugin/fonts/IBMPlexMono-Medium.ttf`
- Create: `penjuru.koplugin/fonts/IBMPlexMono-Bold.ttf`
- Create: `penjuru.koplugin/fonts/SyneMono-Regular.ttf`
- Create: `penjuru.koplugin/fonts/VT323-Regular.ttf`
- Create: `penjuru.koplugin/fonts/OFL.txt` (combined license)

- [ ] **Step 1: Download from Google Fonts' GitHub mirror**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
mkdir -p fonts && cd fonts

# IBM Plex Mono (Regular, Italic, Medium, Bold)
BASE=https://github.com/google/fonts/raw/main/ofl/ibmplexmono
curl -sL -o IBMPlexMono-Regular.ttf "$BASE/IBMPlexMono-Regular.ttf"
curl -sL -o IBMPlexMono-Italic.ttf  "$BASE/IBMPlexMono-Italic.ttf"
curl -sL -o IBMPlexMono-Medium.ttf  "$BASE/IBMPlexMono-Medium.ttf"
curl -sL -o IBMPlexMono-Bold.ttf    "$BASE/IBMPlexMono-Bold.ttf"

# Syne Mono
curl -sL -o SyneMono-Regular.ttf \
  https://github.com/google/fonts/raw/main/ofl/synemono/SyneMono-Regular.ttf

# VT323
curl -sL -o VT323-Regular.ttf \
  https://github.com/google/fonts/raw/main/ofl/vt323/VT323-Regular.ttf

ls -la
```

Expected: 6 TTF files, each 30 KB to 250 KB (sanity check — `du -sh .` should report well under 1 MB total).

- [ ] **Step 2: Add combined OFL license**

Create `penjuru.koplugin/fonts/OFL.txt` with the SIL Open Font License text plus a header listing all three font families. Copy from one of the OFL.txt files in the same Google Fonts repo (e.g. `ofl/ibmplexmono/OFL.txt`) and prepend:
```
This directory bundles three OFL-licensed font families:
  - IBM Plex Mono (c) 2017 IBM Corp.
  - Syne Mono (c) 2017 The Syne Project Authors
  - VT323 (c) 2011 Peter Hull

All are distributed under the SIL Open Font License v1.1, full text below.
```

- [ ] **Step 3: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/fonts/
git commit -m "feat: bundle IBM Plex Mono, Syne Mono, VT323 TTFs

All three families are SIL OFL 1.1. Combined license at fonts/OFL.txt."
```

### Task 2.2: Add a font-loading helper

**Files:**
- Create: `penjuru.koplugin/pen_fonts.lua`
- Test: `penjuru.koplugin/spec/pen_fonts_spec.lua`

KOReader's `ui/font` module exposes `Font:getFace(name, size)`. We need a wrapper that maps our role names (`headline`, `body`, `numerals`, etc.) to the right TTF + size and caches the resulting face.

- [ ] **Step 1: Write the failing spec**

Create `penjuru.koplugin/spec/pen_fonts_spec.lua`:
```lua
-- Run with: ~/Developer/koreader/koreader-emulator-x86_64-darwin/koreader/luajit \
--   ~/Developer/koreader/spec/runtests.sh penjuru.koplugin/spec/pen_fonts_spec.lua
-- (we'll wrap this in a script in step 4)

require("commonrequire")  -- koreader test bootstrap

describe("pen_fonts", function()
    local Fonts
    setup(function()
        Fonts = require("penjuru/pen_fonts")
    end)

    it("returns a face for the headline role", function()
        local face = Fonts:get("headline", 48)
        assert.is_not_nil(face)
        assert.is_not_nil(face.ftsize)  -- koreader Face objects expose ftsize
    end)

    it("returns a face for the body role", function()
        local face = Fonts:get("body", 22)
        assert.is_not_nil(face)
    end)

    it("returns a face for the numerals role", function()
        local face = Fonts:get("numerals", 32)
        assert.is_not_nil(face)
    end)

    it("caches faces by (role, size)", function()
        local a = Fonts:get("body", 22)
        local b = Fonts:get("body", 22)
        assert.equals(a, b)
    end)

    it("errors loudly on unknown role", function()
        assert.has_error(function() Fonts:get("nonexistent", 14) end)
    end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails**

Run:
```bash
cd ~/Developer/koreader
./kodev test ~/Developer/koreader-custom-ui/penjuru.koplugin/spec/pen_fonts_spec.lua 2>&1 | tail -20
```

Expected: error about `module 'penjuru/pen_fonts' not found`.

- [ ] **Step 3: Create `pen_fonts.lua` with the minimum needed to pass**

Create `penjuru.koplugin/pen_fonts.lua`:
```lua
-- penjuru/pen_fonts
-- Maps role names to bundled TTFs and caches loaded Face objects.

local Font = require("ui/font")
local logger = require("logger")

-- Resolve our plugin's font directory regardless of where KOReader is run from.
local plugin_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)")
local font_dir = plugin_dir .. "fonts/"

local ROLE_TO_FILE = {
    headline   = "SyneMono-Regular.ttf",
    display    = "SyneMono-Regular.ttf",
    body       = "IBMPlexMono-Regular.ttf",
    italic     = "IBMPlexMono-Italic.ttf",
    medium     = "IBMPlexMono-Medium.ttf",
    bold       = "IBMPlexMono-Bold.ttf",
    numerals   = "VT323-Regular.ttf",
}

local M = { _cache = {} }

function M:get(role, size)
    local file = ROLE_TO_FILE[role]
    if not file then
        error("pen_fonts: unknown role '" .. tostring(role) .. "'")
    end
    local key = role .. "@" .. tostring(size)
    if not self._cache[key] then
        local path = font_dir .. file
        self._cache[key] = Font:getFace(path, size)
        logger.dbg("pen_fonts: loaded", role, size, path)
    end
    return self._cache[key]
end

return M
```

- [ ] **Step 4: Run the spec and confirm it passes**

```bash
cd ~/Developer/koreader
./kodev test ~/Developer/koreader-custom-ui/penjuru.koplugin/spec/pen_fonts_spec.lua 2>&1 | tail -10
```

Expected: `5 successes / 0 failures / 0 errors / 0 pending`.

If `./kodev test` is not available in your KOReader checkout, fall back to:
```bash
cd ~/Developer/koreader
luajit -lcommonrequire \
  -e "require('busted.runner')({standalone=false})" \
  ~/Developer/koreader-custom-ui/penjuru.koplugin/spec/pen_fonts_spec.lua
```

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_fonts.lua penjuru.koplugin/spec/pen_fonts_spec.lua
git commit -m "feat(fonts): pen_fonts helper maps roles to bundled TTFs

Cached Face lookup by (role, size). Roles: headline/display (Syne Mono),
body/italic/medium/bold (IBM Plex Mono), numerals (VT323)."
```

### Task 2.3: Replace `pen_style.lua` to use our fonts and color tokens

**Files:**
- Modify: `penjuru.koplugin/pen_style.lua` (currently inherits from SimpleUI's `sui_style.lua`)

The spec's visual system needs concrete values pinned down. Define them once here so every widget can reference `Style.colors.ink`, `Style.fonts.headline(48)`, etc.

- [ ] **Step 1: Read the current `pen_style.lua` to understand existing exports**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
wc -l pen_style.lua
grep -nE '^(local |function |[A-Z][a-z]+\.[a-z])' pen_style.lua | head -30
```

You'll need to preserve any public symbols that other `pen_*.lua` files import. Note them — we'll keep their names and just change the values.

- [ ] **Step 2: Rewrite the body of `pen_style.lua`**

Replace the file with:
```lua
-- penjuru/pen_style
-- Single source of truth for typography, color, rules, and spacing.
-- Every other module reads from here so there is one place to retune.

local Fonts = require("penjuru/pen_fonts")
local Blitbuffer = require("ffi/blitbuffer")

local Style = {}

-- COLOR TOKENS (greyscale only — e-ink)
-- Blitbuffer.Color8(n) where 0 = black, 255 = white.
Style.colors = {
    paper     = Blitbuffer.COLOR_WHITE,        -- #fff
    ink       = Blitbuffer.COLOR_BLACK,        -- #111
    ink_2     = Blitbuffer.Color8(0x44),       -- #444
    ink_soft  = Blitbuffer.Color8(0x55),       -- #555
    ink_dim   = Blitbuffer.Color8(0x66),       -- #666
    ink_faint = Blitbuffer.Color8(0x77),       -- #777
    rule      = Blitbuffer.Color8(0xaa),       -- #aaa
    rule_soft = Blitbuffer.Color8(0xcc),       -- #ccc
    rule_dim  = Blitbuffer.Color8(0xdd),       -- #ddd
    divider   = Blitbuffer.Color8(0xee),       -- #eee
    disabled  = Blitbuffer.Color8(0xbb),       -- #bbb
}

-- FONT FACTORIES — call with size in px to get a Face.
Style.fonts = {
    headline = function(size) return Fonts:get("headline", size) end,
    display  = function(size) return Fonts:get("display", size) end,
    body     = function(size) return Fonts:get("body", size) end,
    italic   = function(size) return Fonts:get("italic", size) end,
    medium   = function(size) return Fonts:get("medium", size) end,
    bold     = function(size) return Fonts:get("bold", size) end,
    numerals = function(size) return Fonts:get("numerals", size) end,
}

-- TYPE SCALE — named sizes used across the home screen.
Style.size = {
    masthead_name    = 76,
    masthead_tagline = 20,
    dateline         = 20,
    section_head     = 36,  -- VT323
    headline         = 48,
    body             = 22,
    byline           = 21,
    pull             = 24,
    pull_dropcap     = 66,
    caption          = 18,
    stat_label       = 22,
    stat_value       = 34,  -- VT323
    almanac_value    = 32,  -- VT323
    cat_title        = 28,
    cat_author       = 20,
    cat_age          = 32,  -- VT323
    highlight_q      = 29,
    highlight_src    = 20,
    nav_label        = 22,
    nav_meta         = 19,
    top_bar          = 24,
}

-- RULES — line weights and styles for dividers.
Style.rules = {
    major     = 2,    -- solid #111 between sections
    minor     = 1.5,  -- dotted #aaa within section
    soft      = 1.5,  -- solid #eee between similar items
    masthead  = 2.5,  -- dashed #111 under masthead
    section   = 2.5,  -- solid #111 under section heads
    nav_top   = 3.5,  -- solid #111 above bottom nav
    active    = 7,    -- solid #111 top bar on active tab
}

-- SPACING — common gaps.
Style.gap = {
    xs = 4,
    sm = 8,
    md = 12,
    lg = 18,
    xl = 26,
}

return Style
```

- [ ] **Step 3: Add a spec for the style tokens**

Create `penjuru.koplugin/spec/pen_style_spec.lua`:
```lua
require("commonrequire")

describe("pen_style", function()
    local Style
    setup(function() Style = require("penjuru/pen_style") end)

    it("exposes color tokens", function()
        assert.is_not_nil(Style.colors.paper)
        assert.is_not_nil(Style.colors.ink)
        assert.is_not_nil(Style.colors.rule)
    end)

    it("exposes font factories that return faces", function()
        assert.is_not_nil(Style.fonts.headline(48))
        assert.is_not_nil(Style.fonts.body(22))
        assert.is_not_nil(Style.fonts.numerals(32))
    end)

    it("exposes a complete size table covering home-screen roles", function()
        local required = {
            "masthead_name", "masthead_tagline", "dateline", "section_head",
            "headline", "body", "byline", "pull", "pull_dropcap", "caption",
            "stat_label", "stat_value", "almanac_value", "cat_title",
            "cat_author", "cat_age", "highlight_q", "highlight_src",
            "nav_label", "nav_meta", "top_bar",
        }
        for _, key in ipairs(required) do
            assert.is_number(Style.size[key], "size." .. key .. " must be a number")
        end
    end)

    it("exposes rule weights", function()
        for _, key in ipairs({"major", "minor", "soft", "masthead", "section", "nav_top", "active"}) do
            assert.is_number(Style.rules[key])
        end
    end)
end)
```

- [ ] **Step 4: Run all specs and confirm they pass**

```bash
cd ~/Developer/koreader
./kodev test ~/Developer/koreader-custom-ui/penjuru.koplugin/spec/ 2>&1 | tail -10
```

Expected: 9+ successes (5 from pen_fonts, 4 from pen_style), 0 failures.

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_style.lua penjuru.koplugin/spec/pen_style_spec.lua
git commit -m "feat(style): single source of truth for colors, fonts, sizes, rules

Tokens for all home-screen widgets. Replaces SimpleUI's style layer."
```

---

## Phase 3 · Placeholder home screen

End state: the home screen renders just the **masthead** and **tagline** in the right fonts and color, with the device frame top/bottom borders. No real modules yet — those land in Plan B. The point of this phase is to prove the rendering pipeline works end-to-end with our typography.

### Task 3.1: Strip `pen_homescreen.lua` to a minimal placeholder

**Files:**
- Modify: `penjuru.koplugin/pen_homescreen.lua` (large, ~127 KB inherited from SimpleUI)

- [ ] **Step 1: Identify the entry-point widget class and the show()/render() method**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
grep -nE '^(local |function )(HomeScreen|home)' pen_homescreen.lua | head -10
```

Note the top-level widget definition (likely `local HomeScreen = WidgetContainer:extend{...}` or similar) and which method KOReader calls to show it.

- [ ] **Step 2: Save the old file and create a minimal replacement**

Run:
```bash
cd ~/Developer/koreader-custom-ui/penjuru.koplugin
git mv pen_homescreen.lua pen_homescreen.lua.old_simpleui  # keep for reference
```

Create a new `pen_homescreen.lua`:
```lua
-- penjuru/pen_homescreen
-- v0: masthead-only placeholder so we can verify typography end-to-end
-- before building the full module set in Plan B.

local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = require("device").screen
local Style = require("penjuru/pen_style")

local HomeScreen = WidgetContainer:extend{
    name = "pen_homescreen",
}

function HomeScreen:show()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()

    local name = TextWidget:new{
        text = "penjuru pikiran",
        face = Style.fonts.headline(Style.size.masthead_name),
        fgcolor = Style.colors.ink,
    }
    local tagline = TextWidget:new{
        text = "a reader's almanac · mind-wide",
        face = Style.fonts.body(Style.size.masthead_tagline),
        fgcolor = Style.colors.ink_soft,
    }

    local masthead = VerticalGroup:new{
        align = "center",
        name,
        tagline,
    }

    local frame = FrameContainer:new{
        background = Style.colors.paper,
        bordersize = 0,
        padding = 0,
        margin = 0,
        width = screen_w,
        height = screen_h,
        CenterContainer:new{
            dimen = { w = screen_w, h = screen_h },
            masthead,
        },
    }

    -- Display via UIManager so it overlays the file browser.
    local UIManager = require("ui/uimanager")
    UIManager:show(frame)
    self._frame = frame
end

return HomeScreen
```

- [ ] **Step 3: Wire `main.lua` to call `pen_homescreen:show()` from a menu item**

Open `penjuru.koplugin/main.lua` and locate the menu entry that previously opened SimpleUI's home screen (search for `home` references). Replace its `callback` body with:
```lua
callback = function()
    local HomeScreen = require("penjuru/pen_homescreen")
    HomeScreen:new{}:show()
end,
```

If multiple home-screen entry points exist (top bar tap, bottom bar tap, menu item), edit them all to point at the new module. If you cannot find an existing entry, add a new menu item under Tools → penjuru → "Open home":
```lua
{
    text = "Open home",
    callback = function()
        local HomeScreen = require("penjuru/pen_homescreen")
        HomeScreen:new{}:show()
    end,
},
```

- [ ] **Step 4: Launch the emulator and visually verify**

```bash
cd ~/Developer/koreader && ./kodev run
```

Open menu → Tools → penjuru → Open home. Expected: an overlay appears showing `penjuru pikiran` in Syne Mono and the tagline in IBM Plex Mono, centered on a white background. Close the overlay (typically swipe down or tap-and-hold).

Take a screenshot for the commit log (Cmd-Shift-S in the SDL emulator places PNGs in `~/Developer/koreader/screenshot/`).

- [ ] **Step 5: Commit**

```bash
cd ~/Developer/koreader-custom-ui
git add penjuru.koplugin/pen_homescreen.lua penjuru.koplugin/pen_homescreen.lua.old_simpleui penjuru.koplugin/main.lua
git commit -m "feat(home): masthead-only placeholder home screen

Proves end-to-end pipeline: pen_fonts -> pen_style -> TextWidget renders
correctly in the emulator. Old SimpleUI home stashed at .old_simpleui
for reference while we rebuild modules in Plan B."
```

### Task 3.2: Add device-frame borders + dateline to the placeholder

This rounds out the visible "skeleton" of the home screen so Plan B can focus purely on filling in the body. We add the masthead bottom dashed rule and the dateline row.

**Files:**
- Modify: `penjuru.koplugin/pen_homescreen.lua`
- Create: `penjuru.koplugin/pen_dates.lua` (date helpers — needed for the dateline now and the almanac later)
- Test: `penjuru.koplugin/spec/pen_dates_spec.lua`

- [ ] **Step 1: Write the date-helper spec**

Create `penjuru.koplugin/spec/pen_dates_spec.lua`:
```lua
require("commonrequire")

describe("pen_dates", function()
    local Dates
    setup(function() Dates = require("penjuru/pen_dates") end)

    describe("edition", function()
        it("returns 'morning' before noon", function()
            assert.equals("morning", Dates.edition_for_hour(0))
            assert.equals("morning", Dates.edition_for_hour(11))
        end)
        it("returns 'afternoon' from 12 to 17", function()
            assert.equals("afternoon", Dates.edition_for_hour(12))
            assert.equals("afternoon", Dates.edition_for_hour(17))
        end)
        it("returns 'evening' from 18 to 23", function()
            assert.equals("evening", Dates.edition_for_hour(18))
            assert.equals("evening", Dates.edition_for_hour(23))
        end)
    end)

    describe("day_of_year", function()
        it("returns 1 for Jan 1", function()
            assert.equals(1, Dates.day_of_year(os.time{year=2026, month=1, day=1}))
        end)
        it("returns 143 for May 23 in a non-leap year", function()
            assert.equals(143, Dates.day_of_year(os.time{year=2026, month=5, day=23}))
        end)
    end)

    describe("iso_week", function()
        it("returns 21 for 2026-05-23 (Saturday of ISO week 21)", function()
            assert.equals(21, Dates.iso_week(os.time{year=2026, month=5, day=23}))
        end)
    end)

    describe("format_long", function()
        it("renders 'saturday · 23 may 2026' lowercase", function()
            local t = os.time{year=2026, month=5, day=23, hour=10, min=42}
            assert.equals("saturday · 23 may 2026", Dates.format_long(t))
        end)
    end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
cd ~/Developer/koreader
./kodev test ~/Developer/koreader-custom-ui/penjuru.koplugin/spec/pen_dates_spec.lua 2>&1 | tail -10
```

Expected: error about `module 'penjuru/pen_dates' not found`.

- [ ] **Step 3: Implement `pen_dates.lua`**

Create `penjuru.koplugin/pen_dates.lua`:
```lua
-- penjuru/pen_dates
-- Pure-data date helpers — no KOReader deps, easy to unit-test.

local M = {}

local MONTHS = {
    "january", "february", "march", "april", "may", "june",
    "july", "august", "september", "october", "november", "december",
}
local SHORT_MONTHS = {
    "jan", "feb", "mar", "apr", "may", "jun",
    "jul", "aug", "sep", "oct", "nov", "dec",
}
local DAYS = {
    "sunday", "monday", "tuesday", "wednesday",
    "thursday", "friday", "saturday",
}

function M.edition_for_hour(h)
    if h < 12 then return "morning"
    elseif h < 18 then return "afternoon"
    else return "evening" end
end

function M.day_of_year(t)
    return tonumber(os.date("%j", t))
end

function M.iso_week(t)
    -- ISO 8601 week number; %V is supported by glibc/musl strftime
    -- and KOReader's bundled Lua relies on the system strftime.
    return tonumber(os.date("%V", t))
end

function M.format_long(t)
    local d = os.date("*t", t)
    return string.format("%s · %d %s %d",
        DAYS[d.wday], d.day, SHORT_MONTHS[d.month], d.year)
end

function M.month_name(month_1_to_12)
    return MONTHS[month_1_to_12]
end

return M
```

- [ ] **Step 4: Run spec and confirm pass**

```bash
cd ~/Developer/koreader
./kodev test ~/Developer/koreader-custom-ui/penjuru.koplugin/spec/pen_dates_spec.lua 2>&1 | tail -10
```

Expected: `7 successes / 0 failures`.

- [ ] **Step 5: Extend `pen_homescreen.lua` with the masthead rule and dateline**

Replace `pen_homescreen.lua` with:
```lua
-- penjuru/pen_homescreen
-- v0.1: masthead + dateline + placeholder body region.
-- Full module set lands in Plan B.

local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LineWidget = require("ui/widget/linewidget")
local TextWidget = require("ui/widget/textwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = require("device").screen
local UIManager = require("ui/uimanager")
local Style = require("penjuru/pen_style")
local Dates = require("penjuru/pen_dates")

local HomeScreen = WidgetContainer:extend{
    name = "pen_homescreen",
}

local function rule(w, weight, color)
    return LineWidget:new{
        dimen = { w = w, h = weight },
        background = color,
    }
end

local function spaced_row(w, items)
    -- items: array of TextWidgets; lay them out with space-between.
    local total_text_w = 0
    for _, item in ipairs(items) do total_text_w = total_text_w + item:getSize().w end
    local gap = (#items > 1) and math.floor((w - total_text_w) / (#items - 1)) or 0
    local row = HorizontalGroup:new{ align = "baseline" }
    for i, item in ipairs(items) do
        table.insert(row, item)
        if i < #items then table.insert(row, HorizontalSpan:new{ width = gap }) end
    end
    return row
end

function HomeScreen:_build_masthead(content_w)
    local name = TextWidget:new{
        text = "penjuru pikiran",
        face = Style.fonts.headline(Style.size.masthead_name),
        fgcolor = Style.colors.ink,
    }
    local tagline = TextWidget:new{
        text = "a reader's almanac · mind-wide",
        face = Style.fonts.body(Style.size.masthead_tagline),
        fgcolor = Style.colors.ink_soft,
    }
    return VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = 12 },
        name,
        VerticalSpan:new{ width = 10 },
        tagline,
        VerticalSpan:new{ width = 14 },
        rule(content_w, Style.rules.masthead, Style.colors.ink),
    }
end

function HomeScreen:_build_dateline(content_w)
    local t = os.time()
    local d = os.date("*t", t)
    -- vol/no are placeholder until Plan B adds install-date storage.
    -- Spec says: vol = years since install + 1, no = days since install + 1.
    local vol = TextWidget:new{
        text = "vol. i · no. 1",
        face = Style.fonts.body(Style.size.dateline),
        fgcolor = Style.colors.ink_2,
    }
    local date = TextWidget:new{
        text = Dates.format_long(t),
        face = Style.fonts.body(Style.size.dateline),
        fgcolor = Style.colors.ink_2,
    }
    local edition = TextWidget:new{
        text = Dates.edition_for_hour(d.hour) .. " edition",
        face = Style.fonts.body(Style.size.dateline),
        fgcolor = Style.colors.ink_2,
    }
    return VerticalGroup:new{
        align = "left",
        VerticalSpan:new{ width = 12 },
        spaced_row(content_w, { vol, date, edition }),
        VerticalSpan:new{ width = 12 },
        rule(content_w, Style.rules.minor, Style.colors.rule),
    }
end

function HomeScreen:show()
    local screen_w = Screen:getWidth()
    local screen_h = Screen:getHeight()
    local pad_x = 36
    local content_w = screen_w - 2 * pad_x

    local placeholder = TextWidget:new{
        text = "[ plan b — home modules land here ]",
        face = Style.fonts.italic(Style.size.body),
        fgcolor = Style.colors.ink_faint,
    }

    local body = VerticalGroup:new{
        align = "center",
        VerticalSpan:new{ width = 80 },
        placeholder,
    }

    local stack = VerticalGroup:new{
        align = "center",
        self:_build_masthead(content_w),
        self:_build_dateline(content_w),
        body,
    }

    local outer = FrameContainer:new{
        background = Style.colors.paper,
        bordersize = 0,
        padding_left = pad_x,
        padding_right = pad_x,
        padding_top = 0,
        padding_bottom = 0,
        width = screen_w,
        height = screen_h,
        stack,
    }

    UIManager:show(outer)
    self._frame = outer
end

return HomeScreen
```

- [ ] **Step 6: Launch the emulator and visually verify**

```bash
cd ~/Developer/koreader && ./kodev run
```

Open menu → Tools → penjuru → Open home. Expected:
- `penjuru pikiran` masthead in Syne Mono ~76px
- Tagline in Plex Mono ~20px below it, in soft ink
- Dashed rule under the masthead
- Three-cell dateline row: `vol. i · no. 1` / current date in lowercase / `<edition> edition`
- Dotted rule under the dateline
- Italic placeholder text in the body

Take a screenshot, save it to `docs/dev/screenshots/2026-05-23-home-placeholder.png`.

- [ ] **Step 7: Commit**

```bash
cd ~/Developer/koreader-custom-ui
mkdir -p docs/dev/screenshots
cp ~/Developer/koreader/screenshot/*.png docs/dev/screenshots/2026-05-23-home-placeholder.png  # adjust to actual file name
git add penjuru.koplugin/pen_dates.lua penjuru.koplugin/pen_homescreen.lua penjuru.koplugin/spec/pen_dates_spec.lua docs/dev/screenshots/
git commit -m "feat(home): add dateline + masthead rule to placeholder

Home screen now shows masthead, dashed rule, vol/date/edition row,
dotted rule, italic placeholder for the body. Validates the rule +
spaced-row helpers we'll reuse for every section in Plan B."
```

---

## Phase 4 · Plan A wrap-up

### Task 4.1: Snapshot the working state and write Plan A's exit notes

**Files:**
- Create: `docs/superpowers/plans/2026-05-23-plan-A-DONE.md`

- [ ] **Step 1: Capture the install state**

Run:
```bash
cd ~/Developer/koreader-custom-ui
{
  echo "# Plan A · DONE — $(date '+%Y-%m-%d')"
  echo ""
  echo "## What's working"
  echo "- KOReader emulator builds and runs on macOS (\`~/Developer/koreader\`, tag \`$(cd ~/Developer/koreader && git describe --tags --always)\`)"
  echo "- \`penjuru.koplugin\` is enabled in the emulator via symlink at \`~/Developer/koreader/plugins/penjuru.koplugin\`"
  echo "- Home screen shows masthead + tagline + dashed rule + dateline + dotted rule + body placeholder"
  echo "- Fonts (Plex Mono / Syne Mono / VT323) load from bundled TTFs"
  echo "- All pen_fonts, pen_style, pen_dates specs pass"
  echo ""
  echo "## What's NOT yet built (Plan B picks this up)"
  echo "- Currently reading module"
  echo "- Today's ledger module"
  echo "- The almanac module"
  echo "- On the desk module"
  echo "- Newly catalogued module"
  echo "- Recent highlights module"
  echo ""
  echo "## What's deferred to Plan C"
  echo "- Persistent top status bar (clock/wifi/light/disk/battery)"
  echo "- 7-cell paginated bottom nav with our tab roster"
  echo ""
  echo "## What's deferred to Plan D"
  echo "- Settings menu (Menu → Tools → penjuru sub-tree)"
  echo "- Reading goal / location / newly-threshold config"
  echo "- On-Kindle install"
} > docs/superpowers/plans/2026-05-23-plan-A-DONE.md
git add docs/superpowers/plans/2026-05-23-plan-A-DONE.md
git commit -m "docs: Plan A complete — scaffold, typography, placeholder home"
```

- [ ] **Step 2: Push the milestone**

```bash
cd ~/Developer/koreader-custom-ui
git push origin main
```

Expected: push succeeds, all Phase 0–3 commits appear at https://github.com/alfajrd/penjuru-KOReader-UI.

- [ ] **Step 3: Hand off**

Tell the parent agent: "Plan A complete. Emulator shows the placeholder home screen with our typography. Ready for Plan B to fill in the modules."
