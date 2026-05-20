local repo = "https://api.github.com/repos/Matheuskauanjg/Teste-computer/contents"
 
local dfpwm = require("cc.audio.dfpwm")
 
local speakers = {}
 
for _, name in pairs(peripheral.getNames()) do
    if peripheral.getType(name) == "speaker" then
        table.insert(speakers, peripheral.wrap(name))
    end
end
 
if #speakers == 0 then
    print("Nenhum speaker encontrado!")
    return
end
 
print("Buscando musicas...")
 
local response = http.get(repo)
 
if not response then
    print("Erro ao acessar GitHub")
    return
end
 
local files = textutils.unserializeJSON(response.readAll())
response.close()
 
local songs = {}
 
for _, file in pairs(files) do
    if file.name:match("%.dfpwm$") then
        table.insert(songs, file)
    end
end
 
if #songs == 0 then
    print("Nenhuma musica encontrada")
    return
end
 
local current = 1
local volume = 1
local loop = false
 
local function clear()
    term.clear()
    term.setCursorPos(1,1)
end
 
local function menu()
    clear()
 
    print("=== RADIO GITHUB ===")
    print("Volume: "..volume)
    print("Loop: "..tostring(loop))
    print("")
 
    for i, song in pairs(songs) do
        if i == current then
            print("> "..i.." - "..song.name)
        else
            print("  "..i.." - "..song.name)
        end
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
    print("Baixando...")
 
    shell.run("delete temp.dfpwm")
    shell.run("wget "..song.download_url.." temp.dfpwm")
 
    local file = fs.open("temp.dfpwm", "rb")
 
    if not file then
        print("Erro no arquivo")
        return
    end
 
    local decoder = dfpwm.make_decoder()
 
    repeat
        local chunk = file.read(16 * 1024)
 
        if not chunk then
            break
        end
 
        local buffer = decoder(chunk)
 
        for _, speaker in pairs(speakers) do
            while not speaker.playAudio(buffer, volume) do
                os.pullEvent("speaker_audio_empty")
            end
        end
    until false
 
    file.close()
end
 
while true do
    menu()
 
    local event, key = os.pullEvent("key")
 
    if key == keys.enter then
        repeat
            playSong(songs[current])
        until not loop
 
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
        loop = not loop
 
    elseif key == keys.minus then
        volume = math.max(0.1, volume - 0.2)
 
    elseif key == keys.equals then
        volume = math.min(3, volume + 0.2)
 
    elseif key == keys.q then
        break
    end
end
