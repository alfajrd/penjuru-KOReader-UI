# Screenshot capture checklist

The tutorial at [docs/tutorial.md](./tutorial.md) has 14 image placeholders. This checklist tells you exactly what each one is, how to capture it, and what to look for.

Three capture methods are used:

- **📱 Phone photo** — point a phone at the Kindle. Best for: Kindle's native UI (Settings, KUAL menu) since KOReader's screenshot mechanism doesn't reach those screens. Crop tight in your photo app afterwards.
- **🖼️ Device screenshot** — KOReader's built-in screenshot. **Tap all four corners of the screen at the same time** while inside KOReader. The PNG saves to `/mnt/us/koreader/screenshots/`. USB-transfer to your computer afterwards.
- **🖥️ Computer screenshot** — macOS `Cmd-Shift-4` or Windows `Win-Shift-S` for the GitHub releases page and Finder/Explorer shots.

Tip: save each file under the filename listed below (matches the tutorial's `![…](screenshots/XX-…)` references). Put them in `docs/screenshots/` in the repo or wherever your blog stores images.

---

## Checklist

### Prereq + jailbreak

- [ ] **01 — `01-home-overview.png`** 🖼️
  *Full penjuru home screen with everything visible — masthead, dateline, recent highlights, on-the-desk row with covers, ledger | almanac row, bottom nav.*
  → In KOReader open penjuru home, four-corner tap.

- [ ] **02 — `02-device-info.png`** 📱
  *Kindle native UI: Home → Menu → Settings → Device Options → Device Info, showing your model and software version.*
  → Phone photo of the actual settings screen.

### KUAL + KOReader install

- [ ] **03 — `03-kual-empty.png`** 📱
  *KUAL menu open on your Kindle BEFORE you add penjuru. Showing whatever extensions you already have installed (KOReader, etc.).*
  → Phone photo.

- [ ] **04 — `04-koreader-fm.png`** 🖼️
  *KOReader's file manager view — what you see on first launch before installing penjuru. Books listed, navigation bar at top.*
  → Launch KOReader, four-corner tap on the file manager screen. (You can also take this from the emulator if you prefer — see the cheat sheet at the bottom of the tutorial.)

### penjuru install

- [ ] **05 — `05-github-releases.png`** 🖥️
  *Your browser on the [penjuru releases page](https://github.com/alfajrd/penjuru-KOReader-UI/releases), with the two zip files (`penjuru.koplugin.zip` + `penjuru-kual.zip`) visible / highlighted.*
  → `Cmd-Shift-4` (Mac) or `Win-Shift-S` (Windows) area-select around the assets list.

- [ ] **06 — `06-kindle-mounted.png`** 🖥️
  *Finder (Mac) or Explorer (Windows) showing the Kindle as a USB volume — folder listing of the Kindle's root with `koreader/`, `extensions/`, etc. visible.*
  → `Cmd-Shift-4` on the Finder window, or use `Cmd-Shift-5` for window-only capture.

### First launch

- [ ] **07 — `07-kual-penjuru.png`** 📱
  *KUAL menu AFTER installing penjuru, with the `penjuru` entry visible (should be at or near the top).*
  → Phone photo.

- [ ] **08 — `08-home-first-launch.png`** 🖼️
  *penjuru home immediately after tapping the KUAL menu entry — the "tada, here it is" moment. Same as #01 visually, but you can take this one as a phone photo if you want the warmer "first time it worked" tone.*
  → Four-corner tap OR phone photo, your call.

- [ ] **09 — `09-plugin-mgmt.png`** 🖼️
  *KOReader's Plugin Management screen with the `penjuru` row visible (enabled / toggleable). Hamburger → Tools → Plugin management.*
  → Open the plugin management screen, four-corner tap. Best taken from the emulator if you want a clean shot without any other custom plugins in the list.

### Module tour (zoom crops)

- [ ] **10 — `10-on-the-desk.png`** 🖼️
  *Zoomed crop of the "on the desk" row — the 5 cover thumbnails with percent bands and titles. Should clearly show the layout.*
  → Take a full home screenshot, then crop in your image editor to just that row.

- [ ] **11 — `11-ledger-almanac.png`** 🖼️
  *Zoomed crop of the side-by-side "today's ledger | the almanac" row with the vertical rule between them. Numbers should be legible.*
  → Crop from a home screenshot.

- [ ] **12 — `12-nav-page1.png`** 🖼️
  *Close-up of the bottom nav page 1: `< | mangas | books | home | wi-fi | library | >` — icons, labels, dividers all visible.*
  → Crop from a home screenshot (nav is the bottom row).

- [ ] **13 — `13-nav-page2.png`** 🖼️
  *Close-up of the bottom nav page 2: `< | stats | brightness | power | search | >` — same framing as #12 but on page 2.*
  → Tap the `>` chevron on the home, then take a screenshot and crop.

### Settings

- [ ] **14 — `14-settings.png`** 🖼️
  *KOReader showing penjuru's Settings sub-menu: hamburger → Tools → penjuru → Settings. Should show the goal / location / threshold items.*
  → Open the settings sub-menu, four-corner tap. Best from emulator for a clean shot.

---

## Quick reference: getting screenshots off the Kindle

After taking device screenshots via four-corner tap, they're saved to `/mnt/us/koreader/screenshots/` on the Kindle.

To transfer:

1. Connect Kindle via USB.
2. Open the Kindle volume.
3. Navigate to `koreader/screenshots/`.
4. Copy the PNGs you want to your computer.
5. Rename to match the filenames above and drop into `docs/screenshots/` in your fork or your blog's image folder.

---

## Heads-up: which shots are affected by recent fixes

If you took any of these **before v1.2.14.18**, retake — the layout / content changed:

- **#01 (home overview)** and **#10 (on-the-desk zoom)** — v1.2.14.18 filtered shell scripts and installer files out of the desk row. If your earlier screenshot showed entries like `gnomechess.sh` or `ganbatte`, retake after restarting KOReader; the desk should now be book-only.
- **#12 (nav page 1)** — must be the current 5-tab layout: `< · mangas · books · home · wi-fi · library · >`. (If your shot still has `games` in slot 5, it's pre-v1.2.14.16 — retake.)
- **#13 (nav page 2)** — must be the current 4-tab layout: `< · stats · brightness · power · search · >`. (If yours has `library` in slot 5, it's pre-v1.2.14.17 — retake.)

## Optional new shot worth adding

- [ ] **15 — `15-wifi-network-picker.png`** 🖼️
  *KOReader's network-picker dialog (the "scanning for networks…" / SSID list dialog) that pops up when you tap the **wi-fi** tab on page 1 of the bottom nav. Shows the user what the button actually does — much more informative than just "toggles Wi-Fi."*
  → Tap **wi-fi** on the bottom nav, wait for the network list, four-corner tap. To reference it in the tutorial, add this near the bottom-nav section:
  ```
  ![wi-fi network picker](screenshots/15-wifi-network-picker.png)
  ```

## What if you skip some?

The tutorial reads fine without screenshots — the placeholders are inside HTML comments that GitHub / Hugo / Jekyll won't render. Prioritize:

- **#01** (home overview) — single most important shot, sells the whole thing
- **#07** (KUAL with penjuru) — proves the install worked
- **#12 + #13** (nav close-ups) — shows the iconography

The rest add polish but aren't required to make the tutorial work.
