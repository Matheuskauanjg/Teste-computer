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
    term.clear(); term.setCursorPos(1,1)
    print("Nenhum speaker encontrado!")
    return
end

local function clear()
    term.clear(); term.setCursorPos(1,1)
end

clear()
print("Conectando GitHub...")

local response = http.get(repoApi, nil, true)
if not response then print("Erro GitHub!") return end

local data = textutils.unserializeJSON(response.readAll())
response.close()

local songs = {}
for _, file in ipairs(data) do
    if file.name and file.name:match("%.dfpwm$") then
        local fixed = file.name
            :gsub(" ",  "%%20")
            :gsub("ã", "%%C3%%A3")
            :gsub("ç", "%%C3%%A7")
            :gsub("á", "%%C3%%A1")
            :gsub("é", "%%C3%%A9")
            :gsub("í", "%%C3%%AD")
            :gsub("ó", "%%C3%%B3")
            :gsub("ú", "%%C3%%BA")
        local raw =
            "https://raw.githubusercontent.com/" ..
            "Matheuskauanjg/Teste-computer/main/" .. fixed
        table.insert(songs, { name = file.name, url = raw })
    end
end

if #songs == 0 then print("Nenhuma musica encontrada!") return end
table.sort(songs, function(a,b) return a.name < b.name end)

local current = 1

-- Estado compartilhado entre threads via tabela (passagem por referência)
local state = {
    volume = 1,
    loop   = false,
    stop   = false,
    action = nil,
}

local function drawMenu()
    clear()
    print("=== RADIO ===")
    print("")
    print("Volume: " .. string.format("%.1f", state.volume))
    print("Loop:   " .. tostring(state.loop))
    print("")
    for i, song in ipairs(songs) do
        local prefix = (i == current) and "> " or "  "
        print(prefix .. i .. " - " .. song.name:gsub("%.dfpwm",""))
    end
    print("")
    print("[ENTER] Tocar  [N] Proxima  [P] Anterior")
    print("[+/-] Volume   [L] Loop     [Q] Sair")
end

local function drawPlayer()
    clear()
    print("=== TOCANDO ===")
    print("")
    print(songs[current].name:gsub("%.dfpwm",""))
    print("")
    print("Volume : " .. string.format("%.1f", state.volume))
    print("Loop   : " .. tostring(state.loop))
    print("")
    print("[N] Proxima    [P] Anterior")
    print("[+/-] Volume   [L] Loop")
    print("[Q] Parar / Sair")
end

local function audioThread(song)
    local request = http.get(song.url, nil, true)
    if not request then
        print("Erro ao conectar!")
        sleep(2)
        state.stop = true
        return
    end

    local decoder = dfpwm.make_decoder()

    while not state.stop do
        local chunk = request.read(16 * 1024)
        if not chunk then break end

        local buffer = decoder(chunk)
        local waiting = false

        repeat
            waiting = false
            for _, speaker in ipairs(speakers) do
                -- Lê state.volume aqui: sempre pega o valor mais recente
                local ok = speaker.playAudio(buffer, state.volume)
                if not ok then waiting = true end
            end
            if waiting then
                os.pullEvent("speaker_audio_empty")
            end
        until not waiting or state.stop
    end

    request.close()
    state.stop = true
end

local function keyThread()
    while not state.stop do
        drawPlayer()
        local _, key = os.pullEvent("key")

        if
