-- voicechanger.lua v5.0
-- /vc  = toggle ON/OFF
-- /vc1 = pitch rendah (0.8)
-- /vc2 = pitch tinggi (1.3)

local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        void         (*set_pitch)(float);
        void         (*enable)(void);
        void         (*disable)(void);
        int          (*is_enabled)(void);
        float        (*get_pitch)(void);
    } VcAPI;
    typedef unsigned long uintptr_t;
]]

local vc          = nil
local ADDR_FILE   = "/storage/emulated/0/voicefx_addr.txt"
local CONFIG_FILE = getWorkingDirectory() .. "/config/voicefx.ini"

local function saveConfig(pitch)
    os.execute('mkdir -p "' .. getWorkingDirectory() .. '/config"')
    local f = io.open(CONFIG_FILE, "w")
    if not f then sampAddChatMessage("[VFX] Gagal simpan config", 0xFF4444); return end
    f:write("[voicefx]\npitch=" .. string.format("%.2f", pitch) .. "\n")
    f:close()
    sampAddChatMessage("[VFX] Config disimpan: pitch=" .. string.format("%.2f", pitch), 0x00FF88)
end

local function loadConfig()
    local f = io.open(CONFIG_FILE, "r")
    if not f then return nil end
    local pitch = nil
    for line in f:lines() do
        local v = line:match("^pitch=(.+)$")
        if v then pitch = tonumber(v) end
    end
    f:close()
    return pitch
end

local function loadEngine()
    local f = io.open(ADDR_FILE, "r")
    if not f then
        sampAddChatMessage("[VFX] ERROR: voicefx_addr.txt tidak ditemukan!", 0xFF4444)
        return nil
    end
    local addrStr = f:read("*l"); f:close()
    local addr = tonumber(addrStr)
    if not addr or addr == 0 then
        sampAddChatMessage("[VFX] ERROR: addr tidak valid", 0xFF4444)
        return nil
    end
    sampAddChatMessage("[VFX] addr: 0x" .. string.format("%x", addr), 0x00FFFF)
    local api = ffi.cast("VcAPI*", addr)
    if tonumber(ffi.cast("uintptr_t", api.set_pitch)) == 0 then
        sampAddChatMessage("[VFX] ERROR: set_pitch null!", 0xFF4444)
        return nil
    end
    os.remove(ADDR_FILE)
    sampAddChatMessage("[VFX] Engine OK", 0x00FF88)
    return api
end

function main()
    while not isSampAvailable() do wait(100) end
    wait(2000)
    sampAddChatMessage("[VoiceFX] v5.0 + SoundTouch loading...", 0xFFFF00)

    for attempt = 1, 10 do
        vc = loadEngine()
        if vc then break end
        sampAddChatMessage("[VFX] Retry " .. attempt .. "/10...", 0xFFAA00)
        wait(1000)
    end

    if not vc then sampAddChatMessage("[VFX] GAGAL load engine.", 0xFF4444); return end

    local savedPitch = loadConfig()
    if savedPitch and savedPitch >= 0.25 and savedPitch <= 4.0 then
        vc.set_pitch(savedPitch)
        sampAddChatMessage("[VFX] Config loaded: pitch=" .. string.format("%.2f", savedPitch), 0x00FFFF)
    else
        vc.set_pitch(1.0)
    end

    sampAddChatMessage("[VFX] /vc=ON/OFF | /vc1=rendah | /vc2=tinggi", 0x00FF88)

    sampRegisterChatCommand("vc", function()
        if not vc then return end
        if vc.is_enabled() == 0 then
            vc.enable()
            sampAddChatMessage("[VFX] ON | pitch=" .. string.format("%.2f", vc.get_pitch()), 0x00FF88)
        else
            vc.disable()
            sampAddChatMessage("[VFX] OFF", 0xFF8800)
        end
    end)

    sampRegisterChatCommand("vc1", function()
        if not vc then return end
        vc.set_pitch(0.8); saveConfig(0.8)
        sampAddChatMessage("[VFX] Preset RENDAH | pitch=0.80", 0x00FFFF)
        if vc.is_enabled() == 0 then vc.enable() end
    end)

    sampRegisterChatCommand("vc2", function()
        if not vc then return end
        vc.set_pitch(1.3); saveConfig(1.3)
        sampAddChatMessage("[VFX] Preset TINGGI | pitch=1.30", 0x00FFFF)
        if vc.is_enabled() == 0 then vc.enable() end
    end)

    while true do wait(1000) end
end
