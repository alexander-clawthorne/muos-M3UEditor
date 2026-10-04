#!/bin/bash
# HELP: Enable or disable entries inside m3u playlists
# ICON: m3ueditor
# GRID: m3ueditor

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

APP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/M3UEditor"
controlfolder="$(GET_VAR "device" "storage/rom/mount")/MUOS/PortMaster"

> "$APP_DIR/log.txt" && exec > >(tee "$APP_DIR/log.txt") 2>&1

export DEVICE_ARCH="aarch64"
. "$controlfolder/runtimes/love_11.5/love.txt"

SET_VAR "system" "foreground_process" "love.aarch64"

cd "$APP_DIR" || exit 1

"$controlfolder/gptokeyb2" -1 "love.aarch64" -c "$APP_DIR/m3u-editor.gptk" &
GPTOKEYB_PID=$!

$LOVE_RUN "$APP_DIR"
status=$?

kill -9 "$GPTOKEYB_PID" 2>/dev/null
unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
exit "$status"
