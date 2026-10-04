-- M3U Editor for muOS
-- Browse .m3u playlists, toggle entries on/off, save.
-- Disabling an entry comments it out with a #OFF# marker; nothing is deleted.

local PLAYLIST_DIRS = {
    "/mnt/sdcard/ROMS/IPTV",
    "/mnt/sdcard/ROMS/VIDEO/IPTV",
    "/mnt/mmc/ROMS/IPTV",
}

local MARKER = "#OFF#"
local ROWS = 11

local state = "files"      -- "files" | "entries"
local files = {}
local fileIndex = 1
local fileScroll = 0

local entries = {}
local header = {}
local entryIndex = 1
local entryScroll = 0
local currentPath = nil
local dirty = false
local status = ""
local statusUntil = 0

local font, fontSmall

-- ---------------------------------------------------------------- helpers

local function setStatus(text)
    status = text
    statusUntil = love.timer.getTime() + 3
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function basename(path)
    return path:match("([^/]+)$") or path
end

local function listPlaylists()
    local found = {}
    for _, dir in ipairs(PLAYLIST_DIRS) do
        local pipe = io.popen('ls -1 "' .. dir .. '"/*.m3u 2>/dev/null')
        if pipe then
            for line in pipe:lines() do
                local path = trim(line)
                if path ~= "" then
                    found[#found + 1] = path
                end
            end
            pipe:close()
        end
    end
    return found
end

-- Parse an m3u into a list of {label, url, enabled}.
local function loadPlaylist(path)
    local handle = io.open(path, "r")
    if not handle then
        return nil, "cannot open file"
    end

    local newHeader, newEntries = {}, {}
    local pendingLabel, pendingEnabled = nil, true
    local seenEntry = false

    for raw in handle:lines() do
        local line = raw:gsub("\r$", "")
        local body = line
        local disabled = false
        if body:sub(1, #MARKER) == MARKER then
            disabled = true
            body = body:sub(#MARKER + 1)
        end

        if body:match("^#EXTINF") then
            pendingLabel = body:match("^#EXTINF:[^,]*,(.*)$") or body
            pendingEnabled = not disabled
            seenEntry = true
        elseif body ~= "" and not body:match("^#") then
            newEntries[#newEntries + 1] = {
                label = pendingLabel or basename(body),
                url = body,
                enabled = not disabled and pendingEnabled,
            }
            pendingLabel = nil
            pendingEnabled = true
        elseif not seenEntry then
            newHeader[#newHeader + 1] = line
        end
    end
    handle:close()

    if #newHeader == 0 then
        newHeader = { "#EXTM3U" }
    end
    return newEntries, newHeader
end

local function savePlaylist()
    if not currentPath then return end
    local handle = io.open(currentPath, "w")
    if not handle then
        setStatus("SAVE FAILED - read only?")
        return
    end
    for _, line in ipairs(header) do
        handle:write(line, "\n")
    end
    for _, entry in ipairs(entries) do
        local prefix = entry.enabled and "" or MARKER
        handle:write(prefix, "#EXTINF:-1,", entry.label, "\n")
        handle:write(prefix, entry.url, "\n")
    end
    handle:close()
    dirty = false
    local on = 0
    for _, entry in ipairs(entries) do
        if entry.enabled then on = on + 1 end
    end
    setStatus("SAVED - " .. on .. " of " .. #entries .. " enabled")
end

local function setAll(value)
    for _, entry in ipairs(entries) do
        entry.enabled = value
    end
    dirty = true
    setStatus(value and "ALL ENABLED" or "ALL DISABLED")
end

-- Disable everything, then enable `count` entries starting at the cursor.
local function grabNext(count)
    for _, entry in ipairs(entries) do
        entry.enabled = false
    end
    local taken = 0
    for i = entryIndex, #entries do
        entries[i].enabled = true
        taken = taken + 1
        if taken >= count then break end
    end
    dirty = true
    setStatus("ENABLED NEXT " .. taken .. " FROM CURSOR")
end

local function clampScroll(index, scroll, total)
    if index < scroll + 1 then
        scroll = index - 1
    elseif index > scroll + ROWS then
        scroll = index - ROWS
    end
    if scroll < 0 then scroll = 0 end
    local maxScroll = math.max(0, total - ROWS)
    if scroll > maxScroll then scroll = maxScroll end
    return scroll
end

local function move(delta)
    if state == "files" then
        if #files == 0 then return end
        fileIndex = math.max(1, math.min(#files, fileIndex + delta))
        fileScroll = clampScroll(fileIndex, fileScroll, #files)
    else
        if #entries == 0 then return end
        entryIndex = math.max(1, math.min(#entries, entryIndex + delta))
        entryScroll = clampScroll(entryIndex, entryScroll, #entries)
    end
end

-- ---------------------------------------------------------------- love

function love.load()
    love.graphics.setBackgroundColor(0.07, 0.08, 0.11)
    font = love.graphics.newFont(16)
    fontSmall = love.graphics.newFont(12)
    files = listPlaylists()
    if #files == 0 then
        setStatus("NO .M3U FILES FOUND")
    end
end

function love.keypressed(key)
    if key == "escape" then
        if state == "entries" then
            state = "files"
            setStatus(dirty and "BACK - UNSAVED CHANGES" or "")
        else
            love.event.quit()
        end
        return
    end

    if key == "up" then move(-1) return end
    if key == "down" then move(1) return end
    if key == "left" then move(-ROWS) return end
    if key == "right" then move(ROWS) return end

    if state == "files" then
        if key == "return" and files[fileIndex] then
            local loaded, head = loadPlaylist(files[fileIndex])
            if not loaded then
                setStatus("COULD NOT OPEN FILE")
                return
            end
            entries, header = loaded, head
            currentPath = files[fileIndex]
            entryIndex, entryScroll, dirty = 1, 0, false
            state = "entries"
            setStatus(#entries .. " ENTRIES LOADED")
        end
        return
    end

    -- entries screen
    if key == "return" and entries[entryIndex] then
        entries[entryIndex].enabled = not entries[entryIndex].enabled
        dirty = true
    elseif key == "e" then
        setAll(true)
    elseif key == "d" then
        setAll(false)
    elseif key == "n" then
        grabNext(5)
    elseif key == "s" then
        savePlaylist()
    end
end

local function drawHeader(title, subtitle)
    love.graphics.setColor(0.13, 0.15, 0.20)
    love.graphics.rectangle("fill", 0, 0, 640, 52)
    love.graphics.setColor(0.95, 0.96, 1.0)
    love.graphics.setFont(font)
    love.graphics.print(title, 14, 10)
    love.graphics.setColor(0.55, 0.60, 0.70)
    love.graphics.setFont(fontSmall)
    love.graphics.print(subtitle, 14, 32)
end

local function drawFooter(hints)
    love.graphics.setColor(0.13, 0.15, 0.20)
    love.graphics.rectangle("fill", 0, 438, 640, 42)
    love.graphics.setFont(fontSmall)
    if love.timer.getTime() < statusUntil and status ~= "" then
        love.graphics.setColor(0.45, 0.85, 0.55)
        love.graphics.print(status, 14, 446)
    else
        love.graphics.setColor(0.55, 0.60, 0.70)
        love.graphics.print(hints, 14, 446)
    end
end

function love.draw()
    if state == "files" then
        drawHeader("M3U EDITOR", #files .. " playlists found")
        love.graphics.setFont(font)
        for row = 1, ROWS do
            local index = fileScroll + row
            local file = files[index]
            if not file then break end
            local y = 60 + (row - 1) * 33
            if index == fileIndex then
                love.graphics.setColor(0.20, 0.40, 0.65)
                love.graphics.rectangle("fill", 8, y - 4, 624, 30)
                love.graphics.setColor(1, 1, 1)
            else
                love.graphics.setColor(0.72, 0.76, 0.84)
            end
            love.graphics.print(basename(file), 18, y)
        end
        drawFooter("A OPEN   B EXIT   DPAD MOVE")
        return
    end

    local on = 0
    for _, entry in ipairs(entries) do
        if entry.enabled then on = on + 1 end
    end
    drawHeader(basename(currentPath or "?"),
        on .. " of " .. #entries .. " enabled" .. (dirty and "   * UNSAVED" or ""))

    love.graphics.setFont(fontSmall)
    for row = 1, ROWS do
        local index = entryScroll + row
        local entry = entries[index]
        if not entry then break end
        local y = 60 + (row - 1) * 33
        if index == entryIndex then
            love.graphics.setColor(0.20, 0.40, 0.65)
            love.graphics.rectangle("fill", 8, y - 4, 624, 30)
        end
        if entry.enabled then
            love.graphics.setColor(0.40, 0.85, 0.50)
            love.graphics.print("[ON ]", 18, y + 4)
            love.graphics.setColor(0.95, 0.96, 1.0)
        else
            love.graphics.setColor(0.55, 0.35, 0.35)
            love.graphics.print("[OFF]", 18, y + 4)
            love.graphics.setColor(0.45, 0.48, 0.55)
        end
        local label = entry.label
        if #label > 64 then label = label:sub(1, 63) .. "\u{2026}" end
        love.graphics.print(label, 72, y + 4)
    end

    drawFooter("A TOGGLE  X ALL ON  Y ALL OFF  L1 NEXT5  START SAVE  B BACK")
end
