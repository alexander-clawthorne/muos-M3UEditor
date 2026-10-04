# M3UEditor

A muOS application for turning entries in an `.m3u` playlist on and off, on the
device, with a d-pad.

Built for IPTV and media playlists on Anbernic handhelds, where a playlist can
run to hundreds of channels and the only thing you actually want is "give me the
next five episodes". Trimming that list by editing the file on a PC and copying
it back gets old fast.

**Nothing is ever deleted.** Disabling an entry comments it out with an `#OFF#`
marker, so the line is still there and one button press brings it back.

Written in LÖVE 11.5, running on the PortMaster runtime.

## Requirements

- muOS (built and tested on an RG35XX-SP, aarch64)
- PortMaster, for its `love_11.5` runtime and `gptokeyb2`
- At least one `.m3u` file in one of the scanned folders

## Install

Copy the contents of [`app/`](app) to:

```
/mnt/mmc/MUOS/application/M3UEditor/
```

Copy the icons so muOS draws it properly:

```
icons/glyph/m3ueditor.png  ->  <theme>/glyph/muxapp/m3ueditor.png
icons/grid/m3ueditor.png   ->  <theme>/image/grid/muxapp/m3ueditor.png
```

Then launch **M3UEditor** from Applications.

> If you install somewhere other than `MUOS/application/M3UEditor`, change
> `APP_DIR` in `mux_launch.sh` to match.

## Controls

| Button    | Playlist list       | Entry list                           |
| --------- | ------------------- | ------------------------------------ |
| D-pad ↑↓  | Move                | Move                                 |
| D-pad ←→  | Page                | Page                                 |
| A         | Open the playlist   | Toggle this entry on/off             |
| B         | Exit                | Back to the playlist list            |
| X         | —                   | Enable everything                    |
| Y         | —                   | Disable everything                   |
| L1 / R1   | —                   | Enable the next 5 from the cursor    |
| START     | —                   | Save                                 |

The header shows how many entries are enabled and marks the file `* UNSAVED`
when there are pending changes. Going back without saving keeps the file
untouched — the warning in the status bar is your only nudge, so save first.

**L1 / R1 is the one that gets used most.** It disables everything, then enables
the next five entries starting at the cursor — the fast way to queue up the next
few episodes from a long series playlist.

## What it preserves

A playlist is rewritten on save, so the editor is careful to put back everything
it did not change:

- **The whole `#EXTINF` line, verbatim.** IPTV playlists carry `tvg-id`,
  `tvg-logo` and `group-title` attributes there. Rebuilding that line from the
  channel name alone would silently strip them, so the original is kept.
- **Tags between entries** — `#EXTGRP`, `#EXTVLCOPT` and blank lines — stay
  attached to their entry and keep their position relative to the `#EXTINF`.
- **The file header** and anything trailing the last URL.
- **Entries with no `#EXTINF`.** A bare URL stays a bare URL; no metadata line
  is invented for it.

Loading and saving a playlist with no edits reproduces the file byte for byte.

## Configuration

Everything lives in [`app/config.ini`](app/config.ini). All keys are optional
and the shipped file documents each one.

| Key              | Default                                                                  | What it is                                  |
| ---------------- | ------------------------------------------------------------------------ | ------------------------------------------- |
| `playlist_dirs`  | `/mnt/sdcard/ROMS/IPTV`, `/mnt/sdcard/ROMS/VIDEO/IPTV`, `/mnt/mmc/ROMS/IPTV` | Folders scanned for `.m3u`, comma separated |
| `marker`         | `#OFF#`                                                                   | What a disabled line is prefixed with       |
| `grab_count`     | `5`                                                                       | How many entries L1 enables from the cursor |

Change `marker` only if your playlists legitimately contain `#OFF#` as content.
Any prefix that makes the line a comment to your player will do.

## A warning about playlist files

**`.m3u` files frequently contain credentials.** Playlists generated from Plex,
Jellyfin, Emby or an IPTV provider usually embed an access token directly in
every URL — for example `?X-Plex-Token=...`. Treat a playlist like a password:
do not paste one into a chat, an issue, or a public repo.

`.m3u` is in this repo's `.gitignore` for that reason.

## Status

Working, but lightly tested — it has been exercised on one device with
Plex-generated playlists. The save path is designed to be conservative (nothing
deleted, everything unrecognised preserved), but **back up a playlist you care
about before the first save.**

## Licence

[MPL-2.0](LICENSE)
