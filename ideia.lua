local repoApi =
"https://api.github.com/repos/Matheuskauanjg/Teste-computer/contents"

local dfpwm = require("cc.audio.dfpwm")

local speakers = {}

for _, name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name, "speaker") then
        table.insert(speakers, peripheral.wrap(name))
    end
end

local function clear()
    term.clear()
    term.setCursorPos(1,1)
end

clear()

if #speakers == 0 then
    print("Nenhum speaker encontrado!")
    print("")
    print("Perifericos detectados:")
    print("")

    for _, name in ipairs(peripheral.getNames()) do
        print("- "..name)
    end

    return
end

print("Conectando ao GitHub...")
sleep(1)

local response = http.get(repoApi)

if not response then
    print("Erro ao acessar GitHub!")
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

        table.insert(songs, {
            name = file.name,
            url = raw
        })
    end
end

if #songs == 0 then
    print("Nenhuma musica encontrada!")
    return
end

table.sort(songs, function(a,b)
    return a.name < b.name
end)

local current = 1
local volume = 1
local loopMode = false

local function drawMenu()
    clear()

    print("=== RADIO GITHUB ===")
    print("")
    print("Speakers: "..#speakers)
    print("Volume: "..string.format("%.1f", volume))
    print("Loop: "..tostring(loopMode))
    print("")

    for i, song in ipairs(songs) do
        local prefix = "  "

        if i == current then
            prefix = "> "
        end

        local clean =
            song.name
                :gsub("%.dfpwm","")

        print(prefix..i.." - "..clean)
    end

    print("")
    print("[ENTER] Tocar")
    print("[N] Proxima")
    print("[P] Anterior")
    print("[+] Volume")
    print("[-] Volume")
    print("[L] Loop")
    print("[Q] Sair")
end

local function playSong(song)
    clear()

    print("Streaming:")
    print(song.name)
    print("")
    print("Conectando...")
    print("")

    local request = http.get(song.url)

    if not request then
        print("Erro ao conectar!")
        print("")
        print(song.url)
        sleep(3)
        return
    end

    print("Tocando...")
    print("")
    print("Volume: "..string.format("%.1f", volume))
    print("")

    local decoder = dfpwm.make_decoder()

    while true do
        local chunk = request.read(16 * 1024)

        if not chunk then
            break
        end

        local buffer = decoder(chunk)

        for _, speaker in ipairs(speakers) do
            while not speaker.playAudio(buffer, volume) do
                os.pullEvent("speaker_audio_empty")
            end
        end
    end

    request.close()
end

while true do
    drawMenu()

    local _, key = os.pullEvent("key")

    if key == keys.enter then

        repeat
            playSong(songs[current])
        until not loopMode

    elseif key == keys.n then

        current = current + 1

        if current > #songs then
            current = 1
        end

    elseif key == keys.p then

        current = current - 1

        if current < 1 then
            current = #songs
        end

    elseif key == keys.l then

        loopMode = not loopMode

    elseif key == keys.minus then

        volume = math.max(0.2, volume - 0.2)

    elseif key == keys.equals then

        volume = math.min(3, volume + 0.2)

    elseif key == keys.q then

        clear()
        print("Radio desligada.")
        break
    end
end
