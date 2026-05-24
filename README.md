# penjuru — a KOReader UI for Kindle

A custom UI plugin for [KOReader](https://github.com/koreader/koreader) on
Kindle Paperwhite. Replaces the default home / library chrome with a
newspaper-flavored home screen typed in monospace, plus a persistent top
status bar and a persistent paginated bottom nav.

Carries the voice of [penjurupikiran.com](https://penjurupikiran.com) onto
e-ink — lowercase everywhere, triple-monospace type system (Syne Mono · IBM
Plex Mono · VT323), small quiet archive mood.

## Status

**Design phase.** No code yet. The repo currently contains:

- [`docs/superpowers/specs/2026-05-23-koreader-ui-design.md`](docs/superpowers/specs/2026-05-23-koreader-ui-design.md) — the full design spec
- [`home-v3.html`](home-v3.html) — a browser mockup of the home screen at the
  Kindle Paperwhite's native resolution (1236 × 1648). Open in any browser to
  preview.

Implementation will fork [simpleui.koplugin](https://github.com/doctorhetfield-cmd/simpleui.koplugin)
as a starting point — it already solves the hard problems (monkey-patching
KOReader's chrome to insert persistent bars, module registry, settings menu,
icon-pack hot-swap) — then heavily reskin and rebuild the home screen, bottom
nav, and typography layer.

## What's in the design

**Home screen, top to bottom:**

- Top status bar — clock · wi-fi · light · disk · battery
- Masthead — `penjuru pikiran` / `a reader's almanac · mind-wide`
- Dateline — `vol. i · no. 143 · saturday 23 may 2026 · morning edition`
- **Currently reading** (lead) — the single most-recently-opened book as a
  headline, byline, pull quote (your most recent highlight from it), body
  lede, progress bar
- **Today's ledger** — reading minutes, pages, streak, year goal
- **The almanac** — day of year, week, sunrise / sunset, moon phase (all
  offline-calculable)
- **On the desk** — 5 covers of books with progress > 0 and < 100%
- **Newly catalogued** — 3 tap-rows of books recently added but not started
- **Recent highlights** — 3 most-recent annotations across all books

**Paginated bottom nav (7 cells: chevron · 5 tabs · chevron):**

- Page 1 · content: `prev · manga · books · home · wi-fi · games · next`
- Page 2 · utilities: `prev · stats · brightness · power · search · library · next`

Each tab can target a built-in screen, a custom folder shortcut, a
[KUAL](https://www.mobileread.com/forums/showthread.php?t=225030) launcher,
or any installed KOReader plugin.

## Visual system

- **Typography:** Syne Mono (display), IBM Plex Mono (body), VT323 (numerals)
- **Color:** monochrome only; tonal variation via 45° diagonal dither at four
  densities, which both reads on e-ink without ghosting and visually echoes
  the riso textures of penjurupikiran.com
- **Voice:** lowercase everywhere, em-dash bylines, intimate

## Acknowledgments

penjuru is a fork of
[simpleui.koplugin](https://github.com/doctorhetfield-cmd/simpleui.koplugin)
by **Doctor Hetfield**, the original author of the KOReader UI plugin this
project is built on. SimpleUI solved the hard problems of injecting custom
chrome into KOReader and providing a modular home-screen system; penjuru
forks those foundations and replaces the visual layer with a monospace
newspaper aesthetic. Thank you Doctor Hetfield — without your work
penjuru would not exist.

Additional thanks to:

- The [KOReader](https://github.com/koreader/koreader) team for the
  open, hackable e-reader platform this all runs on.
- [IBM Plex Mono](https://github.com/IBM/plex),
  [Syne Mono](https://gitlab.com/bonjour-monde/fonderie/syne-typeface), and
  [VT323](https://github.com/phoikoi/VT323) — the three typefaces bundled
  with the plugin, all under the SIL Open Font License v1.1.

## License

MIT — see [`penjuru.koplugin/LICENSE`](penjuru.koplugin/LICENSE) for full
text. Portions Copyright © 2024–2026 Doctor Hetfield (simpleui.koplugin).
