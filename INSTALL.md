# Installing penjuru on your Kindle

penjuru is a [KOReader](https://github.com/koreader/koreader) plugin. Before
installing penjuru, you need a jailbroken Kindle with KOReader already
running on it.

## Prerequisites

1. **A jailbroken Kindle.** Follow the
   [MobileRead jailbreak guide](https://www.mobileread.com/forums/forumdisplay.php?f=150)
   for your specific Kindle model. penjuru v1.0 is designed and tested on
   the Paperwhite (PW5/PW11/PW12, 1236×1648 @ 300 ppi); other Kindles may
   work but the typography sizes are tuned for that screen.

2. **KOReader installed and working.** See
   [KOReader's install guide](https://github.com/koreader/koreader/wiki/Installation-on-Kindle-devices).
   You should be able to open KOReader from the Kindle home screen via KUAL
   or a similar launcher.

## Install penjuru

1. **Download the latest release** from
   [github.com/alfajrd/penjuru-KOReader-UI/releases](https://github.com/alfajrd/penjuru-KOReader-UI/releases).
   Grab `penjuru.koplugin.zip`.

2. **Copy it to your Kindle.** Connect the Kindle to your computer via USB.
   You should see a `Kindle/` (or `/mnt/us/`) volume mount on your desktop.

3. **Unzip into the KOReader plugins folder:**

   ```
   Kindle/koreader/plugins/
   ```

   After unzipping, the directory structure must be:

   ```
   Kindle/koreader/plugins/penjuru.koplugin/
     ├── _meta.lua
     ├── main.lua
     ├── pen_*.lua
     ├── home_modules/
     ├── fonts/
     ├── icons/
     └── ...
   ```

   **Important:** the folder name must end in `.koplugin` — KOReader uses
   that suffix to recognize plugin folders.

4. **Eject the Kindle** and unplug.

5. **Open KOReader** from your jailbreak launcher (KUAL etc.).

6. **Enable the plugin.** In KOReader:
   - Open the menu (hamburger icon top-right).
   - Tools → Plugin management.
   - Find "penjuru" in the list. Tap to enable.
   - Restart KOReader when prompted.

7. **Open the home screen.** Menu → Tools → penjuru → Open home.
   You should see the masthead, the dateline, the currently-reading lead,
   the on-the-desk grid, the newly-catalogued rows, recent highlights, and
   the 7-cell paginated nav at the bottom.

## First-run configuration

The plugin ships with sensible defaults:

- **Annual reading goal:** 40 books
- **Location** for sunrise/moon: Jakarta (lat -6.2088, lon 106.8456, tz +7)
- **"Newly catalogued" threshold:** 30 days
- **Tab roster:**
  - Page 1 — `manga · books · home · wi-fi · games`
  - Page 2 — `stats · brightness · power · search · library`

Change any of these via **Menu → Tools → penjuru → Settings**.

The "manga" and "books" tabs default to `/mnt/us/koreader/mangas/` and
`/mnt/us/koreader/books/` — adjust the paths via the Settings menu if you
keep your books elsewhere.

## What lives where on the Kindle

- **Plugin folder:** `/mnt/us/koreader/plugins/penjuru.koplugin/`
- **Plugin settings:** stored in KOReader's `settings.reader.lua` under the
  `penjuru` key
- **Test data the plugin reads:** KOReader's existing `history.lua` and
  per-book `<book>.sdr/metadata.epub.lua` sidecars under your library folder.
  No new on-device data is created by the plugin.

## Troubleshooting

- **"penjuru" doesn't appear in Plugin management** — make sure the folder
  is named exactly `penjuru.koplugin` (not `penjuru` or
  `penjuru.koplugin-main`). KOReader requires the `.koplugin` suffix.
- **Plugin loads but the home screen is empty or just shows the masthead**
  — your KOReader has no reading history yet. Open a book through
  KOReader's file browser once; close it; then revisit the home screen and
  it'll populate with the lead / desk / highlights modules.
- **Sunrise/sunset wrong** — set your location via Settings → Location.
  Format is `lat,lon,tz` (e.g. `40.7128,-74.0060,-5` for New York).
- **The home screen looks too big / cropped** — penjuru's typography is
  tuned for the 1236×1648 Paperwhite resolution. On other Kindle models,
  open an issue at the GitHub repo with your model name and a screenshot.

## Uninstall

Delete the `penjuru.koplugin/` folder from `/mnt/us/koreader/plugins/`,
restart KOReader, and you're done. Your KOReader settings file may still
have a `penjuru` entry — harmless; delete it manually if you wish.

## Reporting bugs

Open an issue at
[github.com/alfajrd/penjuru-KOReader-UI/issues](https://github.com/alfajrd/penjuru-KOReader-UI/issues)
with:

- Your Kindle model
- KOReader version (Menu → Help → About)
- A description of what you did and what you expected vs. what happened
- If KOReader crashed: the contents of `/mnt/us/koreader/crash.log`
