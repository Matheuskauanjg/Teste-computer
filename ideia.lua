local repoApi =
    "https://api.github.com/repos/Matheuskauanjg/Teste-computer/contents"

local dfpwm = require("cc.audio.dfpwm")

local speakers = {}

for _, name in ipairs(peripheral.getNames()) do
    local ok, result = pcall(peripheral.hasType, name, "speaker")
    if ok and result then
        table.insert(speakers, peripheral.wrap(name))
    end
end

if #speakers == 0 then
    term.clear()
    term.setCursorPos(1, 1)
    print("Nenhum speaker encontrado!")
    return
end

local function clear()
    term.clear()
    term.setCursorPos(1, 1)
end

clear()
print("Conectando GitHub...")

local response = http.get(repoApi, nil, true)
if not response then
    print("Erro GitHub!")
    return
end

local data = textutils.unserializeJSON(response.readAll())
response.close()

local songs = {}

for _, file in ipairs(data) do
    if file.name and file.name:match("%.dfpwm$") then
        local fixed =
            file.name
                :gsub(" ", "%%20")
                :gsub("ã", "%%C3%%A3")
                :gsub("ç", "%%C3%%A7")
                :gsub("á", "%%C3%%A1")
                :gsub("é", "%%C3%%A9")
                :gsub("í", "%%C3%%AD")
                :gsub("ó", "%%C3%%B3")
                :gsub("ú", "%%C3%%BA")

        local raw =
            "https://raw.githubusercontent.com/" ..
            "Matheuskauanjg/Teste-computer/main/" ..
            fixed

        table.insert(songs, { name = file.name, url = raw })
    end
end

if #songs == 0 then
    print("Nenhuma musica encontrada!")
    return
end

table.sort(songs, function(a, b) return a.name < b.name end)

local current   = 1
local volume    = 1
local loopMode  = false

-- Sinalização entre threads
local stopFlag   = false  -- pede parada do áudio
local skipAction = nil    -- "next" | "prev" | "quit"

local function drawMenu()
    clear()
    print("=== RADIO ===")
    print("")
    print("Volume: " .. string.format("%.1f", volume))
    print("Loop: " .. tostring(loopMode))
    print("")
    for i, song in ipairs(songs) do
        local prefix = (i == current) and "> " or "  "
        print(prefix .. i .. " - " .. song.name:gsub("%.dfpwm", ""))
    end
    print("")
    print("[ENTER] Tocar  [N] Proxima  [P] Anterior")
    print("[+/-] Volume   [L] Loop     [Q] Sair")
end

local function drawPlayer()
    clear()
    print("=== TOCANDO ===")
    print("")
    print(songs[current].name:gsub("%.dfpwm", ""))
    print("")
    print("Volume : " .. string.format("%.1f", volume))
    print("Loop   : " .. tostring(loopMode))
    print("")
    print("[N] Proxima    [P] Anterior")
    print("[+/-] Volume   [L] Loop")
    print("[Q] Parar / Sair")
end

-- Thread de áudio: toca a música e respeita stopFlag
local function audioThread(song)
    local request = http.get(song.url, nil, true)
    if not request then
        print("Erro ao conectar!")
        sleep(2)
        stopFlag = true
        return
    end

    local decoder = dfpwm.make_decoder()

    while not stopFlag do
        local chunk = request.read(16 * 1024)
        if not chunk then break end

        local buffer = decoder(chunk)
        local waiting = false

        repeat
            waiting = false
            for _, speaker in ipairs(speakers) do
                local ok = speaker.playAudio(buffer, volume)
                if not ok then waiting = true end
            end
            if waiting then
                -- Aguarda mas também checa stopFlag
                local timer = os.startTimer(0.05)
                local ev = { os.pullEvent() }
                if ev[1] == "speaker_audio_empty" then
                    -- continua normalmente
                elseif ev[1] == "timer" then
                    -- só checar stopFlag novamente
                end
            end
        until not waiting or stopFlag
    end

    request.close()
    stopFlag = true  -- garante saída
end

-- Thread de teclas durante reprodução
local function keyThread()
    while not stopFlag do
        drawPlayer()
        local _, key = os.pullEvent("key")

        if key == keys.q then
            skipAction = "quit"
            stopFlag = true

        elseif key == keys.n then
            skipAction = "next"
            stopFlag = true

        elseif key == keys.p then
            skipAction = "prev"
            stopFlag = true

        elseif key == keys.l then
            loopMode = not loopMode

        elseif key == keys.equals then
            volume = math.min(3, volume + 0.2)

        elseif key == keys.minus then
            volume = math.max(0.2, volume - 0.2)
        end
    end
end

local function playSong(song)
    stopFlag   = false
    skipAction = nil
    parallel.waitForAny(
        function() audioThread(song) end,
        function() keyThread() end
    )
end

-- Loop principal
while true do
    drawMenu()
    local _, key = os.pullEvent("key")

    if key == keys.enter then
        -- Toca com controle total durante reprodução
        repeat
            playSong(songs[current])

            if skipAction == "quit" then break end

            if skipAction == "next" then
                current = current % #songs + 1
            elseif skipAction == "prev" then
                current = (current - 2) % #songs + 1
            end
            -- se skipAction == nil: música terminou normalmente
        until not loopMode and skipAction ~= "next" and skipAction ~= "prev"

        if skipAction == "quit" then
            clear()
            print("Radio desligada.")
            break
        end

    elseif key == keys.n then
        current = current % #songs + 1

    elseif key == keys.p then
        current = (current - 2) % #songs + 1

    elseif key == keys.l then
        loopMode = not loopMode

    elseif key == keys.equals then
        volume = math.min(3, volume + 0.2)

    elseif key == keys.minus then
        volume = math.max(0.2, volume - 0.2)

    elseif key == keys.q then
        clear()
        print("Radio desligada.")
        break
    end
end
