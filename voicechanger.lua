-- voicechanger.lua v6.0 GUI
-- /vc = buka/tutup GUI

local ffi     = require("ffi")
local imgui   = require("mimgui")

ffi.cdef[[
    typedef struct {
        void  (*set_pitch)(float);
        void  (*enable)(void);
        void  (*disable)(void);
        int   (*is_enabled)(void);
        float (*get_pitch)(void);
        void  (*set_formant)(float);
        float (*get_formant)(void);
    } VcAPI;
    typedef unsigned long uintptr_t;
]]

-- ─── State ───────────────────────────────────────────────────
local vc          = nil
local ADDR_FILE   = "/storage/emulated/0/voicefx_addr.txt"
local CONFIG_FILE = getWorkingDirectory() .. "/config/voicefx.ini"

local showGUI     = imgui.new.bool(false)
local sliderPitch   = imgui.new.float(1.0)
local sliderFormant = imgui.new.float(1.0)

-- ─── Config ──────────────────────────────────────────────────
local function saveConfig()
    os.execute('mkdir -p "' .. getWorkingDirectory() .. '/config"')
    local f = io.open(CONFIG_FILE, "w")
    if not f then return end
    f:write("[voicefx]\n")
    f:write(string.format("pitch=%.3f\n",   sliderPitch[0]))
    f:write(string.format("formant=%.3f\n", sliderFormant[0]))
    f:close()
end

local function loadConfig()
    local f = io.open(CONFIG_FILE, "r")
    if not f then return end
    for line in f:lines() do
        local v = line:match("^pitch=(.+)$")
        if v then sliderPitch[0] = tonumber(v) or 1.0 end
        v = line:match("^formant=(.+)$")
        if v then sliderFormant[0] = tonumber(v) or 1.0 end
    end
    f:close()
end

-- ─── Engine Load ─────────────────────────────────────────────
local function loadEngine()
    local f = io.open(ADDR_FILE, "r")
    if not f then return nil end
    local addrStr = f:read("*l"); f:close()
    local addr = tonumber(addrStr)
    if not addr or addr == 0 then return nil end
    local api = ffi.cast("VcAPI*", addr)
    if tonumber(ffi.cast("uintptr_t", api.set_pitch)) == 0 then return nil end
    os.remove(ADDR_FILE)
    return api
end

-- ─── Theme ───────────────────────────────────────────────────
local function applyTheme()
    local style = imgui.GetStyle()
    style.WindowRounding = 16
    style.FrameRounding  = 10
    style.GrabRounding   = 10
    style.WindowBorderSize = 0
    local c = style.Colors
    c[imgui.Col.WindowBg]       = imgui.ImVec4(0.10, 0.10, 0.16, 0.97)
    c[imgui.Col.FrameBg]        = imgui.ImVec4(0.18, 0.18, 0.28, 1)
    c[imgui.Col.FrameBgHovered] = imgui.ImVec4(0.25, 0.25, 0.38, 1)
    c[imgui.Col.SliderGrab]     = imgui.ImVec4(0.2, 0.75, 0.5, 1)
    c[imgui.Col.SliderGrabActive] = imgui.ImVec4(0.3, 0.9, 0.6, 1)
    c[imgui.Col.Button]         = imgui.ImVec4(0.2, 0.6, 0.4, 1)
    c[imgui.Col.ButtonHovered]  = imgui.ImVec4(0.3, 0.7, 0.5, 1)
    c[imgui.Col.ButtonActive]   = imgui.ImVec4(0.2, 0.75, 0.5, 1)
    c[imgui.Col.CheckMark]      = imgui.ImVec4(0.2, 0.9, 0.5, 1)
    c[imgui.Col.Header]         = imgui.ImVec4(0.2, 0.6, 0.4, 0.7)
    c[imgui.Col.HeaderHovered]  = imgui.ImVec4(0.3, 0.7, 0.5, 0.8)
    c[imgui.Col.Separator]      = imgui.ImVec4(0.3, 0.3, 0.4, 1)
end

-- ─── GUI Render ──────────────────────────────────────────────
imgui.OnFrame(function() return showGUI[0] end, function()
    applyTheme()
    imgui.SetNextWindowSize(imgui.ImVec2(360, 420), imgui.Cond.FirstUseEver)
    imgui.SetNextWindowPos(imgui.ImVec2(100, 100), imgui.Cond.FirstUseEver)
    imgui.Begin("VoiceFX v4.0", showGUI)

    if not vc then
        imgui.TextColored(imgui.ImVec4(1,0.3,0.3,1), "Engine tidak loaded!")
        imgui.End()
        return
    end

    -- Status
    local enabled = vc.is_enabled() == 1
    local statusColor = enabled
        and imgui.ImVec4(0.2, 1.0, 0.4, 1)
        or  imgui.ImVec4(1.0, 0.4, 0.4, 1)
    imgui.TextColored(statusColor, enabled and "Status: ON" or "Status: OFF")
    imgui.SameLine()
    if imgui.Button(enabled and "Matikan" or "Hidupkan", imgui.ImVec2(100, 30)) then
        if enabled then vc.disable() else vc.enable() end
    end

    imgui.Separator()

    -- Pitch Slider
    imgui.Text("Pitch")
    imgui.SetNextItemWidth(280)
    if imgui.SliderFloat("##pitch", sliderPitch, 0.25, 4.0, "%.2f") then
        vc.set_pitch(sliderPitch[0])
    end
    imgui.SameLine()
    if imgui.Button("Reset##p", imgui.ImVec2(50, 0)) then
        sliderPitch[0] = 1.0
        vc.set_pitch(1.0)
    end

    -- Formant Slider
    imgui.Spacing()
    imgui.Text("Formant")
    imgui.SetNextItemWidth(280)
    if imgui.SliderFloat("##formant", sliderFormant, 0.25, 4.0, "%.2f") then
        vc.set_formant(sliderFormant[0])
    end
    imgui.SameLine()
    if imgui.Button("Reset##f", imgui.ImVec2(50, 0)) then
        sliderFormant[0] = 1.0
        vc.set_formant(1.0)
    end

    imgui.Separator()

    -- Presets
    imgui.Text("Presets")
    imgui.Spacing()

    local presets = {
        { label = "Normal",       pitch = 1.0,  formant = 1.0  },
        { label = "Cowok Berat",  pitch = 0.7,  formant = 1.0  },
        { label = "Cewek Natural",pitch = 1.4,  formant = 0.71 },
        { label = "Robot",        pitch = 0.5,  formant = 2.0  },
        { label = "Chipmunk",     pitch = 2.0,  formant = 2.0  },
        { label = "Shift Natural",pitch = 1.3,  formant = 0.77 },
    }

    local btnW = 160
    for i, p in ipairs(presets) do
        if imgui.Button(p.label, imgui.ImVec2(btnW, 32)) then
            sliderPitch[0]   = p.pitch
            sliderFormant[0] = p.formant
            vc.set_pitch(p.pitch)
            vc.set_formant(p.formant)
            if vc.is_enabled() == 0 then vc.enable() end
        end
        if i % 2 == 1 then imgui.SameLine() end
    end

    imgui.Separator()

    -- Save config
    if imgui.Button("Simpan Config", imgui.ImVec2(160, 35)) then
        saveConfig()
        sampAddChatMessage("[VFX] Config disimpan", 0x00FF88)
    end

    imgui.End()
end)

-- ─── Main ────────────────────────────────────────────────────
function main()
    while not isSampAvailable() do wait(100) end
    wait(2000)

    sampAddChatMessage("[VoiceFX] v6.0 GUI loading...", 0xFFFF00)

    for i = 1, 10 do
        vc = loadEngine()
        if vc then break end
        sampAddChatMessage("[VFX] Retry " .. i .. "/10...", 0xFFAA00)
        wait(1000)
    end

    if not vc then
        sampAddChatMessage("[VFX] GAGAL load engine!", 0xFF4444)
        return
    end

    loadConfig()
    vc.set_pitch(sliderPitch[0])
    vc.set_formant(sliderFormant[0])
    sampAddChatMessage("[VFX] OK | /vc = buka GUI", 0x00FF88)

    sampRegisterChatCommand("vc", function()
        showGUI[0] = not showGUI[0]
    end)

    while true do wait(1000) end
end
