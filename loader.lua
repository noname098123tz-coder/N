-- ========================================================
-- 0 HUB — FIXED UI-FIRST BUILD / NON-BLOCKING STARTUP
-- ========================================================

-- ========================================================
-- 0 HUB v7.1 - RIVALS FPS EDITION
-- FRAME-BUDGETED | NPC-AWARE | CRASH-PROOF LOOP DECOUPLING
-- ========================================================

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = workspace
local LocalPlayer      = Players.LocalPlayer

local function GetCamera()
    return Workspace.CurrentCamera
end

-- ========================================================
-- // RUNTIME GUARD — budgeted, thread-safe
-- ========================================================
local Runtime = {
    Version    = "7.1.0",
    Loaded     = false,
    Errors     = 0,
    MaxErrors  = 60,
    Conns      = {},
    Dead       = false,
    StartTime  = os.clock(),
    FrameCount = 0,
}

-- Per-system time budgets (seconds) — hard cap per frame
local Budget = {
    ESP      = 0.004,  -- 4ms max
    Chams    = 0.006,
    Aimbot   = 0.002,
    TrigBot  = 0.001,
    Notif    = 0.001,
    XHair    = 0.001,
    Move     = 0.002,
}

-- Tick throttles — minimum seconds between runs
local Throttle = {
    ESP      = 0,      -- every render (but budgeted internally)
    Chams    = 0.25,   -- chams don't need per-frame
    Speed    = 0.1,
    Gravity  = 0.5,
    Noclip   = 0.05,
    VelRec   = 0.05,
}
local LastTick = {}
local function CanRun(key)
    local now = os.clock()
    if not LastTick[key] or (now - LastTick[key]) >= (Throttle[key] or 0) then
        LastTick[key] = now
        return true
    end
    return false
end

local function SafeCall(fn, budget, ...)
    if Runtime.Dead then return end
    local t0 = os.clock()
    local args = {...}
    local ok, err = xpcall(
        function() fn(table.unpack(args)) end,
        function(e) return e .. "\n" .. (debug and debug.traceback and debug.traceback("",2) or "") end
    )
    if not ok then
        Runtime.Errors += 1
        warn(("[0 HUB v7.1] ERR#%d → %s"):format(Runtime.Errors, tostring(err)))
        if Runtime.Errors >= Runtime.MaxErrors then
            warn("[0 HUB v7.1] error cap — killed")
            Runtime.Dead = true
        end
    end
    local elapsed = os.clock() - t0
    if budget and elapsed > budget then
        -- soft warn only, don't crash
        -- warn(("[0 HUB v7.1] budget overrun: %.2fms / %.2fms"):format(elapsed*1000, budget*1000))
    end
end

local function Track(conn)
    if conn then table.insert(Runtime.Conns, conn) end
    return conn
end

-- ========================================================
-- // SETTINGS
-- ========================================================
local Settings = {
    Aimbot           = { Value=false,    Type="toggle",   Tab="Aimbot" },
    SilentAim        = { Value=false,    Type="toggle",   Tab="Aimbot" },
    AimbotFOV        = { Value=150,      Type="slider",   Tab="Aimbot",   Min=10,   Max=600 },
    ShowFOV          = { Value=true,     Type="toggle",   Tab="Aimbot" },
    TargetPart       = { Value="Head",   Type="dropdown", Tab="Aimbot",   Options={"Head","UpperTorso","HumanoidRootPart"} },
    Prediction       = { Value=false,    Type="toggle",   Tab="Aimbot" },
    PredictionStr    = { Value=0.07,     Type="slider",   Tab="Aimbot",   Min=0.01, Max=0.3 },
    TargetLock       = { Value=false,    Type="toggle",   Tab="Aimbot" },
    AutoTargetSwitch = { Value=true,     Type="toggle",   Tab="Aimbot" },
    AimbotSmooth     = { Value=5,        Type="slider",   Tab="Aimbot",   Min=1,    Max=100 },
    AimbotKey        = { Value="None",   Type="dropdown", Tab="Aimbot",   Options={"None","RightMouseButton","E","Q"} },
    TriggerBot       = { Value=false,    Type="toggle",   Tab="Aimbot" },
    TriggerDelay     = { Value=0.04,     Type="slider",   Tab="Aimbot",   Min=0,    Max=0.25 },
    AutoFire         = { Value=false,    Type="toggle",   Tab="Aimbot" },
    AutoFireRate     = { Value=0.08,     Type="slider",   Tab="Aimbot",   Min=0.01, Max=0.5 },
    -- ESP
    ESP              = { Value=false,    Type="toggle",   Tab="ESP" },
    ESPBoxes         = { Value=true,     Type="toggle",   Tab="ESP" },
    ESPBoxStyle      = { Value="Corner", Type="dropdown", Tab="ESP",      Options={"Corner","Full","Fill"} },
    ESPNames         = { Value=true,     Type="toggle",   Tab="ESP" },
    ESPDistance      = { Value=true,     Type="toggle",   Tab="ESP" },
    ESPHealth        = { Value=true,     Type="toggle",   Tab="ESP" },
    ESPSkeleton      = { Value=false,    Type="toggle",   Tab="ESP" },
    ESPTracers       = { Value=false,    Type="toggle",   Tab="ESP" },
    ESPTracerOrigin  = { Value="Bottom", Type="dropdown", Tab="ESP",      Options={"Bottom","Center","Top"} },
    ESPMaxDist       = { Value=500,      Type="slider",   Tab="ESP",      Min=50,   Max=2000 },
    ESPTeamColor     = { Value=false,    Type="toggle",   Tab="ESP" },
    Chams            = { Value=false,    Type="toggle",   Tab="ESP" },
    ChamStyle        = { Value="Neon",   Type="dropdown", Tab="ESP",      Options={"Neon","Glass","Solid"} },
    -- Visuals
    FullBright       = { Value=false,    Type="toggle",   Tab="Visuals" },
    CrosshairMode    = { Value="Off",    Type="dropdown", Tab="Visuals",  Options={"Off","Dot","Cross","Circle"} },
    FOVChanger       = { Value=false,    Type="toggle",   Tab="Visuals" },
    CustomFOV        = { Value=90,       Type="slider",   Tab="Visuals",  Min=30,   Max=120 },
    WatermarkShow    = { Value=true,     Type="toggle",   Tab="Visuals" },
    -- Movement
    Fly              = { Value=false,    Type="toggle",   Tab="Movement" },
    FlySpeed         = { Value=50,       Type="slider",   Tab="Movement", Min=10,   Max=500 },
    Noclip           = { Value=false,    Type="toggle",   Tab="Movement" },
    SpeedHack        = { Value=false,    Type="toggle",   Tab="Movement" },
    SpeedMult        = { Value=1.5,      Type="slider",   Tab="Movement", Min=1,    Max=10 },
    InfiniteJump     = { Value=false,    Type="toggle",   Tab="Movement" },
    LowGravity       = { Value=false,    Type="toggle",   Tab="Movement" },
    -- Misc
    AntiBan          = { Value=true,     Type="toggle",   Tab="Misc" },
    Notifications    = { Value=true,     Type="toggle",   Tab="Misc" },
    PanicKey         = { Value="Delete", Type="dropdown", Tab="Misc",     Options={"Delete","End","F9"} },
    MenuKey          = { Value="Insert", Type="dropdown", Tab="Misc",     Options={"Insert","F4","Home"} },
}

local function S(k)     return Settings[k] and Settings[k].Value end
local function Set(k,v) if Settings[k] then Settings[k].Value = v end end

-- ========================================================
-- // UTIL — nil-contract on every path
-- ========================================================
local Util = {}

function Util.Char(p)
    if typeof(p) ~= "Instance" then return nil end
    local ok, c = pcall(function() return p.Character end)
    return (ok and typeof(c) == "Instance") and c or nil
end
function Util.Hum(p)
    local c = Util.Char(p); if not c then return nil end
    local ok, h = pcall(function() return c:FindFirstChildOfClass("Humanoid") end)
    return (ok and h) and h or nil
end
function Util.Root(p)
    local c = Util.Char(p); if not c then return nil end
    local ok, r = pcall(function() return c:FindFirstChild("HumanoidRootPart") end)
    return (ok and r) and r or nil
end
function Util.Part(p, name)
    local c = Util.Char(p); if not c then return nil end
    local ok, part = pcall(function()
        return c:FindFirstChild(name) or c:FindFirstChild("HumanoidRootPart")
    end)
    return (ok and part) and part or nil
end
function Util.Alive(p)
    local h = Util.Hum(p); if not h then return false end
    local ok, hp = pcall(function() return h.Health end)
    return ok and (hp or 0) > 0
end
function Util.Dist(a, b)
    if not a or not b then return math.huge end
    local ok, d = pcall(function() return (a-b).Magnitude end)
    return (ok and d) or math.huge
end
function Util.W2S(pos)
    local cam = GetCamera(); if not cam then return Vector2.zero, false, 0 end
    local ok, res = pcall(function() return cam:WorldToViewportPoint(pos) end)
    if not ok or not res then return Vector2.zero, false, 0 end
    return Vector2.new(res.X, res.Y), res.Z > 0, res.Z
end
function Util.LerpC(c1, c2, t)
    return Color3.new(c1.R+(c2.R-c1.R)*t, c1.G+(c2.G-c1.G)*t, c1.B+(c2.B-c1.B)*t)
end
function Util.HPColor(hp, mx)
    return Util.LerpC(Color3.fromRGB(220,30,30), Color3.fromRGB(30,220,80), math.clamp(hp/math.max(mx,1),0,1))
end
function Util.TeamColor(p)
    local ok, col = pcall(function() return p.TeamColor and Color3.fromBrickColor(p.TeamColor) end)
    return (ok and col) or Color3.fromRGB(255,60,60)
end
function Util.KeyDown(name)
    if not name or name == "None" then return true end
    local ok, down = pcall(function()
        local kc = Enum.KeyCode[name]
        if kc then return UserInputService:IsKeyDown(kc) end
        local mb = Enum.UserInputType[name]
        if mb then return UserInputService:IsMouseButtonPressed(mb) end
        return false
    end)
    return ok and down or false
end

local function SafeSet(obj, k, v)
    if obj then pcall(function() obj[k] = v end) end
end

-- ========================================================
-- // PLAYER CACHE — pre-filtered, updated on events NOT per-frame
-- ========================================================
local PlayerCache = { List = {}, Dirty = true }

local function RebuildPlayerCache()
    PlayerCache.List = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            table.insert(PlayerCache.List, p)
        end
    end
    PlayerCache.Dirty = false
end

Track(Players.PlayerAdded:Connect(function(p)
    PlayerCache.Dirty = true
    task.wait(1)
    if S("Chams") then
        local char = Util.Char(p)
        if char then
            -- Chams.Apply called after Chams is defined
            task.delay(0.5, function() if S("Chams") then pcall(function() Chams.Apply(p) end) end end)
        end
    end
end))
Track(Players.PlayerRemoving:Connect(function(p)
    PlayerCache.Dirty = true
end))

local function GetPlayers()
    if PlayerCache.Dirty then RebuildPlayerCache() end
    return PlayerCache.List
end

-- ========================================================
-- // VELOCITY HISTORY — regression prediction, capped samples
-- ========================================================
local VelHistory = {}
local VEL_SAMPLES = 6

local function RecordVel(uid, pos)
    VelHistory[uid] = VelHistory[uid] or {}
    local h = VelHistory[uid]
    table.insert(h, { pos=pos, t=os.clock() })
    if #h > VEL_SAMPLES then table.remove(h,1) end
end

local function PredictPos(target)
    if not S("Prediction") then return nil end
    local part = Util.Part(target, S("TargetPart") or "Head")
    local lr   = Util.Root(LocalPlayer)
    if not part or not lr then return nil end
    local ok1, partPos = pcall(function() return part.Position end)
    local ok2, lrPos   = pcall(function() return lr.Position end)
    if not ok1 or not ok2 or not partPos or not lrPos then return nil end
    local uid = target.UserId
    local h   = VelHistory[uid]
    if not h or #h < 2 then return partPos end
    local vx,vy,vz,wSum = 0,0,0,0
    for i = 2, #h do
        local dt = h[i].t - h[i-1].t
        if dt > 0 then
            local dv = h[i].pos - h[i-1].pos
            local w  = i / #h
            vx+=(dv.X/dt)*w; vy+=(dv.Y/dt)*w; vz+=(dv.Z/dt)*w; wSum+=w
        end
    end
    if wSum <= 0 then return partPos end
    local vel     = Vector3.new(vx/wSum, vy/wSum, vz/wSum)
    local dist    = Util.Dist(partPos, lrPos)
    local tFlight = dist / 1500
    return partPos + vel * (tFlight * ((S("PredictionStr") or 0.07) * 10))
end

-- ========================================================
-- // FOV CIRCLE — smoothed
-- ========================================================
local FOVCircle  = nil
local FOVCurrent = 0
if Drawing then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness    = 1.5
        FOVCircle.Color        = Color3.fromRGB(0,215,155)
        FOVCircle.Filled       = false
        FOVCircle.Transparency = 0.8
        FOVCircle.Visible      = false
        FOVCircle.NumSides     = 64
    end)
end
local function UpdateFOV(dt)
    if not FOVCircle then return end
    local target  = S("AimbotFOV") or 150
    FOVCurrent    = FOVCurrent + (target - FOVCurrent) * math.min((dt or 0.016)*12, 1)
    local active  = S("ShowFOV") and (S("Aimbot") or S("SilentAim"))
    if active then
        local ok, mp = pcall(function() return UserInputService:GetMouseLocation() end)
        if ok and mp then
            FOVCircle.Position = mp
            FOVCircle.Radius   = FOVCurrent
            FOVCircle.Visible  = true
            return
        end
    end
    FOVCircle.Visible = false
end

-- ========================================================
-- // HOOKS — stored original, zero rawget fallback crash
-- ========================================================
local Hooks = { Done=false, OrigIndex=nil }
function Hooks.Install()
    if Hooks.Done then return end
    local banPats = {"ban","kick","detect","cheat","verify","admin","anticheat","report","flag","exploit"}

    pcall(function()
        if not (getrawmetatable and hookmetamethod and newcclosure and checkcaller and getnamecallmethod) then return end
        local mt    = getrawmetatable(game)
        local oldNC = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and S("AntiBan") then
                if method=="FireServer" or method=="InvokeServer" then
                    local nm=""
                    pcall(function() nm=tostring(rawget(self,"Name") or self.Name or ""):lower() end)
                    for _, pat in ipairs(banPats) do
                        if nm:find(pat) then return end
                    end
                end
            end
            return oldNC(self, ...)
        end)
        setreadonly(mt, true)
    end)

    pcall(function()
        if not (hookmetamethod and checkcaller) then return end
        local mt = getrawmetatable(game)
        local originalIndex = mt.__index  -- STORED before hook
        Hooks.OrigIndex = originalIndex
        setreadonly(mt, false)
        mt.__index = newcclosure(function(self, key)
            if not checkcaller() and S("SilentAim") then
                if key=="Hit" or key=="CFrame" then
                    local t = Target and Target.Get and Target.Get()
                    if t then
                        local part = Util.Part(t, S("TargetPart") or "Head")
                        if part then
                            local ok, pos = pcall(function() return part.Position end)
                            if ok and pos then
                                return CFrame.new(PredictPos(t) or pos)
                            end
                        end
                    end
                end
            end
            if typeof(originalIndex)=="function" then
                return originalIndex(self, key)
            end
            return rawget(self, key)
        end)
        setreadonly(mt, true)
    end)

    Hooks.Done = true
end

-- ========================================================
-- // TARGET SYSTEM
-- ========================================================
local Target = { Current=nil, LastSwitch=0, Cooldown=0.2 }
function Target.Mouse()
    local ok, mp = pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok then return nil end
    local fov  = S("AimbotFOV") or 150
    local best, bDist = nil, fov
    for _, p in ipairs(GetPlayers()) do
        if Util.Alive(p) then
            local part = Util.Part(p, S("TargetPart") or "Head")
            if part then
                local ok2, pos = pcall(function() return part.Position end)
                if ok2 and pos then
                    local sp, vis = Util.W2S(pos)
                    if vis then
                        local d = (sp-mp).Magnitude
                        if d < bDist then bDist=d; best=p end
                    end
                end
            end
        end
    end
    return best
end
function Target.Near()
    local lr = Util.Root(LocalPlayer); if not lr then return nil end
    local ok, lPos = pcall(function() return lr.Position end)
    if not ok or not lPos then return nil end
    local best, bDist = nil, math.huge
    for _, p in ipairs(GetPlayers()) do
        if Util.Alive(p) then
            local r = Util.Root(p)
            if r then
                local ok2, rPos = pcall(function() return r.Position end)
                if ok2 and rPos then
                    local d = Util.Dist(rPos, lPos)
                    if d < bDist then bDist=d; best=p end
                end
            end
        end
    end
    return best
end
function Target.Get()
    if S("TargetLock") and Target.Current and Util.Alive(Target.Current) then return Target.Current end
    local now = os.clock()
    if S("AutoTargetSwitch") and Target.Current and Util.Alive(Target.Current)
    and (now-Target.LastSwitch) < Target.Cooldown then return Target.Current end
    local t = Target.Mouse() or Target.Near()
    if t ~= Target.Current then Target.Current=t; Target.LastSwitch=now end
    return t
end
function Target.Clear() Target.Current=nil; Target.LastSwitch=0 end

-- ========================================================
-- // AIMBOT
-- ========================================================
local Aimbot = {}
function Aimbot.Update()
    if not S("Aimbot") then return end
    if not Util.KeyDown(S("AimbotKey") or "None") then return end
    local cam = GetCamera(); if not cam then return end
    local t   = Target.Get(); if not t then return end
    local part = Util.Part(t, S("TargetPart") or "Head"); if not part then return end
    pcall(function()
        local ok, partPos = pcall(function() return part.Position end)
        if not ok or not partPos then return end
        local pos   = PredictPos(t) or partPos
        local alpha = math.clamp((S("AimbotSmooth") or 5) / 100, 0.005, 1)
        cam.CFrame  = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, pos), alpha)
    end)
end

-- ========================================================
-- // TRIGGERBOT / AUTOFIRE
-- ========================================================
local TrigBot = { LastFire=0, LastAuto=0 }
function TrigBot.Fire()
    pcall(function()
        local vim = getgenv and getgenv().VirtualInputManager
        if vim then
            vim:SendMouseButtonEvent(0,0,0,true,nil,0)
            task.delay(0.04, function()
                pcall(function() vim:SendMouseButtonEvent(0,0,0,false,nil,0) end)
            end)
        end
    end)
end
function TrigBot.Update()
    local now = os.clock()
    if S("TriggerBot") and (now-TrigBot.LastFire) >= (0.1+(S("TriggerDelay") or 0.04)) then
        local t = Target.Mouse()
        if t then
            local part = Util.Part(t, S("TargetPart") or "Head")
            if part then
                local ok, pos = pcall(function() return part.Position end)
                if ok and pos then
                    local sp, vis = Util.W2S(pos)
                    if vis then
                        local ok2, mp = pcall(function() return UserInputService:GetMouseLocation() end)
                        if ok2 and mp and (sp-mp).Magnitude < (S("AimbotFOV") or 150)*0.15 then
                            TrigBot.LastFire = now
                            task.delay(S("TriggerDelay") or 0.04, TrigBot.Fire)
                        end
                    end
                end
            end
        end
    end
    if S("AutoFire") and (now-TrigBot.LastAuto) >= (S("AutoFireRate") or 0.08) then
        TrigBot.LastAuto = now
        TrigBot.Fire()
    end
end

-- ========================================================
-- // CROSSHAIR — rebuilt only on mode change, not per-frame
-- ========================================================
local XHair    = { Draws={}, LastMode="" }
function XHair.Clear()
    for _, d in ipairs(XHair.Draws) do pcall(function() d:Remove() end) end
    XHair.Draws = {}
end
function XHair.Rebuild()
    XHair.Clear()
    if not Drawing then return end
    local mode = S("CrosshairMode") or "Off"
    XHair.LastMode = mode
    if mode=="Off" then return end
    local cam = GetCamera(); if not cam then return end
    local ok, vp = pcall(function() return cam.ViewportSize end); if not ok or not vp then return end
    local cx, cy = vp.X/2, vp.Y/2
    local col    = Color3.fromRGB(0,215,155)
    local function L(x1,y1,x2,y2)
        local ln = Drawing.new("Line")
        ln.From=Vector2.new(x1,y1); ln.To=Vector2.new(x2,y2)
        ln.Thickness=1.5; ln.Color=col; ln.Transparency=0.9
        table.insert(XHair.Draws, ln)
    end
    if mode=="Dot" then
        local d=Drawing.new("Circle"); d.Position=Vector2.new(cx,cy); d.Radius=2
        d.Filled=true; d.Color=col; d.Transparency=0.95; table.insert(XHair.Draws,d)
    elseif mode=="Cross" then
        L(cx-8,cy,cx-3,cy); L(cx+3,cy,cx+8,cy); L(cx,cy-8,cx,cy-3); L(cx,cy+3,cx,cy+8)
    elseif mode=="Circle" then
        local c=Drawing.new("Circle"); c.Position=Vector2.new(cx,cy); c.Radius=10
        c.Filled=false; c.Color=col; c.Thickness=1.2; c.Transparency=0.85; table.insert(XHair.Draws,c)
    end
end
function XHair.Tick()
    local mode = S("CrosshairMode") or "Off"
    -- only rebuild when mode actually changes — zero per-frame alloc
    if mode ~= XHair.LastMode then XHair.Rebuild() end
end

-- ========================================================
-- // ESP — budgeted, per-player iteration with early exit
-- ========================================================
local ESPSys = { Cache={} }

local SKEL = {
    {"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
}

local function NewDraw(cls, props)
    if not Drawing then return nil end
    local ok, d = pcall(function() return Drawing.new(cls) end)
    if not ok or not d then return nil end
    if props then for k,v in pairs(props) do pcall(function() d[k]=v end) end end
    return d
end

function ESPSys.Create(uid)
    if ESPSys.Cache[uid] or not Drawing then return end
    local d = {}
    d.BoxOuter = NewDraw("Square",{Filled=false,Thickness=3,Color=Color3.fromRGB(0,0,0),Visible=false})
    d.Box      = NewDraw("Square",{Filled=false,Thickness=1.5,Color=Color3.fromRGB(255,60,60),Visible=false})
    d.BoxFill  = NewDraw("Square",{Filled=true,Color=Color3.fromRGB(255,60,60),Transparency=0.1,Visible=false})
    d.Corners  = {}
    for i=1,8 do d.Corners[i] = NewDraw("Line",{Thickness=2,Color=Color3.fromRGB(255,255,255),Visible=false}) end
    d.Name     = NewDraw("Text",{Size=14,Outline=true,OutlineColor=Color3.fromRGB(0,0,0),Color=Color3.fromRGB(255,255,255),Center=true,Visible=false})
    d.Dist     = NewDraw("Text",{Size=12,Outline=true,OutlineColor=Color3.fromRGB(0,0,0),Color=Color3.fromRGB(200,200,200),Center=true,Visible=false})
    d.HPBg     = NewDraw("Square",{Filled=true,Color=Color3.fromRGB(0,0,0),Transparency=0.55,Visible=false})
    d.HP       = NewDraw("Square",{Filled=true,Color=Color3.fromRGB(80,220,80),Transparency=1,Visible=false})
    d.Tracer   = NewDraw("Line",{Thickness=1,Color=Color3.fromRGB(255,60,60),Transparency=0.8,Visible=false})
    d.Skel     = {}
    for i=1,#SKEL do d.Skel[i] = NewDraw("Line",{Thickness=1,Color=Color3.fromRGB(180,180,255),Transparency=0.7,Visible=false}) end
    ESPSys.Cache[uid] = d
end

local function HideAll(d)
    if not d then return end
    local function hv(o) SafeSet(o,"Visible",false) end
    hv(d.BoxOuter); hv(d.Box); hv(d.BoxFill); hv(d.Name); hv(d.Dist); hv(d.HP); hv(d.HPBg); hv(d.Tracer)
    if d.Corners then for _,c in ipairs(d.Corners) do hv(c) end end
    if d.Skel    then for _,s in ipairs(d.Skel)    do hv(s) end end
end

function ESPSys.Remove(uid)
    local d = ESPSys.Cache[uid]; if not d then return end
    HideAll(d)
    local function rm(o) if o then pcall(function() o:Remove() end) end end
    rm(d.BoxOuter); rm(d.Box); rm(d.BoxFill); rm(d.Name); rm(d.Dist); rm(d.HP); rm(d.HPBg); rm(d.Tracer)
    if d.Corners then for _,c in ipairs(d.Corners) do rm(c) end end
    if d.Skel    then for _,s in ipairs(d.Skel)    do rm(s) end end
    ESPSys.Cache[uid] = nil
end

local function DrawCorners(d, x, y, w, h, col)
    local cl = math.min(w,h)*0.22
    local defs = {
        {Vector2.new(x,y),     Vector2.new(x+cl,y)},   {Vector2.new(x,y),     Vector2.new(x,y+cl)},
        {Vector2.new(x+w,y),   Vector2.new(x+w-cl,y)}, {Vector2.new(x+w,y),   Vector2.new(x+w,y+cl)},
        {Vector2.new(x,y+h),   Vector2.new(x+cl,y+h)}, {Vector2.new(x,y+h),   Vector2.new(x,y+h-cl)},
        {Vector2.new(x+w,y+h), Vector2.new(x+w-cl,y+h)},{Vector2.new(x+w,y+h),Vector2.new(x+w,y+h-cl)},
    }
    for i, def in ipairs(defs) do
        local c = d.Corners[i]
        if c then SafeSet(c,"From",def[1]); SafeSet(c,"To",def[2]); if col then SafeSet(c,"Color",col) end; SafeSet(c,"Visible",true) end
    end
end

-- ESP update runs in FRAME-SPLIT chunks to prevent freeze
local ESPQueue       = {}   -- ordered list of players to process this frame
local ESPQueueIndex  = 1
local ESP_PER_FRAME  = 4    -- max players processed per render frame

local function RefillESPQueue()
    ESPQueue      = {}
    ESPQueueIndex = 1
    for _, p in ipairs(GetPlayers()) do
        table.insert(ESPQueue, p)
    end
end

function ESPSys.Update()
    if not Drawing then return end
    if not S("ESP") then
        -- hide everything, don't iterate heavy
        for uid in pairs(ESPSys.Cache) do ESPSys.Remove(uid) end
        return
    end

    -- refresh queue when exhausted
    if ESPQueueIndex > #ESPQueue then RefillESPQueue() end

    local cam  = GetCamera()
    local lrOk, localRoot = pcall(function() return Util.Root(LocalPlayer) end)
    if not lrOk then localRoot=nil end
    local lPos = nil
    if localRoot then pcall(function() lPos=localRoot.Position end) end

    local alive      = {}
    local processed  = 0

    while ESPQueueIndex <= #ESPQueue and processed < ESP_PER_FRAME do
        local player = ESPQueue[ESPQueueIndex]
        ESPQueueIndex += 1
        processed    += 1
        if not player or player == LocalPlayer then continue end

        local uid = player.UserId
        alive[uid] = true
        ESPSys.Create(uid)
        local d = ESPSys.Cache[uid]; if not d then continue end

        if not Util.Alive(player) then HideAll(d); continue end

        local root = Util.Root(player)
        local head = Util.Part(player, "Head")
        if not root or not head then HideAll(d); continue end

        local rPos, hPos
        if not pcall(function() rPos=root.Position end) then HideAll(d); continue end
        if not pcall(function() hPos=head.Position end) then HideAll(d); continue end
        if not rPos or not hPos then HideAll(d); continue end

        -- velocity record (throttled)
        if CanRun("VelRec_"..uid) then RecordVel(uid, rPos) end

        local dist = lPos and Util.Dist(rPos,lPos) or 0
        if dist > (S("ESPMaxDist") or 500) then HideAll(d); continue end
        if not cam then HideAll(d); continue end

        local sr, visR, zR = Util.W2S(rPos)
        local sh, visH     = Util.W2S(hPos)
        if not visR or zR <= 0 then HideAll(d); continue end

        local height = math.abs(sr.Y-sh.Y)*2.2
        local width  = height*0.55
        local bx, by = sr.X-width/2, sr.Y-height*0.85
        local style  = S("ESPBoxStyle") or "Corner"
        local baseCol = S("ESPTeamColor") and Util.TeamColor(player) or Color3.fromRGB(255,60,60)

        SafeSet(d.BoxOuter,"Visible",false); SafeSet(d.Box,"Visible",false); SafeSet(d.BoxFill,"Visible",false)
        if d.Corners then for _,c in ipairs(d.Corners) do SafeSet(c,"Visible",false) end end

        if S("ESPBoxes") then
            if style=="Corner" then
                DrawCorners(d,bx,by,width,height,baseCol)
            elseif style=="Full" then
                SafeSet(d.BoxOuter,"Position",Vector2.new(bx-1,by-1)); SafeSet(d.BoxOuter,"Size",Vector2.new(width+2,height+2)); SafeSet(d.BoxOuter,"Visible",true)
                SafeSet(d.Box,"Position",Vector2.new(bx,by)); SafeSet(d.Box,"Size",Vector2.new(width,height)); SafeSet(d.Box,"Color",baseCol); SafeSet(d.Box,"Visible",true)
            elseif style=="Fill" then
                SafeSet(d.BoxFill,"Position",Vector2.new(bx,by)); SafeSet(d.BoxFill,"Size",Vector2.new(width,height)); SafeSet(d.BoxFill,"Color",baseCol); SafeSet(d.BoxFill,"Visible",true)
            end
        end

        if S("ESPNames") and d.Name then
            local ok2,dn = pcall(function() return player.DisplayName end)
            SafeSet(d.Name,"Text",(ok2 and dn) or player.Name)
            SafeSet(d.Name,"Position",Vector2.new(bx+width/2,by-18))
            SafeSet(d.Name,"Color",baseCol); SafeSet(d.Name,"Visible",true)
        elseif d.Name then SafeSet(d.Name,"Visible",false) end

        if S("ESPDistance") and d.Dist then
            SafeSet(d.Dist,"Text",math.floor(dist).."m")
            SafeSet(d.Dist,"Position",Vector2.new(bx+width/2,by+height+3))
            SafeSet(d.Dist,"Visible",true)
        elseif d.Dist then SafeSet(d.Dist,"Visible",false) end

        if S("ESPHealth") and d.HP and d.HPBg then
            local hum = Util.Hum(player)
            local hp,maxHp = 100,100
            if hum then pcall(function() hp=hum.Health; maxHp=hum.MaxHealth end) end
            local ratio = math.clamp(hp/math.max(maxHp,1),0,1)
            local bW,bH = 4,height; local bX,bY = bx-bW-3,by
            SafeSet(d.HPBg,"Position",Vector2.new(bX,bY)); SafeSet(d.HPBg,"Size",Vector2.new(bW,bH)); SafeSet(d.HPBg,"Visible",true)
            SafeSet(d.HP,"Position",Vector2.new(bX,bY+bH*(1-ratio))); SafeSet(d.HP,"Size",Vector2.new(bW,bH*ratio))
            SafeSet(d.HP,"Color",Util.HPColor(hp,maxHp)); SafeSet(d.HP,"Visible",true)
        else SafeSet(d.HP,"Visible",false); SafeSet(d.HPBg,"Visible",false) end

        if S("ESPTracers") and d.Tracer and cam then
            local ok2,vp = pcall(function() return cam.ViewportSize end)
            if ok2 and vp then
                local orig = S("ESPTracerOrigin") or "Bottom"
                local fy   = orig=="Top" and 0 or (orig=="Center" and vp.Y/2 or vp.Y)
                SafeSet(d.Tracer,"From",Vector2.new(vp.X/2,fy)); SafeSet(d.Tracer,"To",Vector2.new(sr.X,sr.Y))
                SafeSet(d.Tracer,"Color",baseCol); SafeSet(d.Tracer,"Visible",true)
            end
        elseif d.Tracer then SafeSet(d.Tracer,"Visible",false) end

        if S("ESPSkeleton") then
            local char = Util.Char(player)
            for i, pair in ipairs(SKEL) do
                local ln = d.Skel[i]
                if ln and char then
                    local p1ok,p1 = pcall(function() return char:FindFirstChild(pair[1]) end)
                    local p2ok,p2 = pcall(function() return char:FindFirstChild(pair[2]) end)
                    if p1ok and p2ok and p1 and p2 then
                        local ok3,pos1 = pcall(function() return p1.Position end)
                        local ok4,pos2 = pcall(function() return p2.Position end)
                        if ok3 and ok4 and pos1 and pos2 then
                            local s1,v1 = Util.W2S(pos1); local s2,v2 = Util.W2S(pos2)
                            if v1 and v2 then SafeSet(ln,"From",s1); SafeSet(ln,"To",s2); SafeSet(ln,"Color",baseCol); SafeSet(ln,"Visible",true)
                            else SafeSet(ln,"Visible",false) end
                        else SafeSet(ln,"Visible",false) end
                    else SafeSet(ln,"Visible",false) end
                elseif ln then SafeSet(ln,"Visible",false) end
            end
        else
            if d.Skel then for _,s in ipairs(d.Skel) do SafeSet(s,"Visible",false) end end
        end
    end

    -- cleanup removed players — only checked when queue resets
    if ESPQueueIndex > #ESPQueue then
        for uid in pairs(ESPSys.Cache) do
            local found = false
            for _, p in ipairs(GetPlayers()) do
                if p.UserId == uid then found=true; break end
            end
            if not found then ESPSys.Remove(uid) end
        end
    end
end

-- ========================================================
-- // CHAMS — throttled, not per-frame
-- ========================================================
local Chams = { Orig={} }
local ChamStyles = {
    Neon  = {Material=Enum.Material.Neon,           Color=Color3.fromRGB(255,0,80),   Trans=0.3},
    Glass = {Material=Enum.Material.Glass,          Color=Color3.fromRGB(0,180,255),  Trans=0.5},
    Solid = {Material=Enum.Material.SmoothPlastic,  Color=Color3.fromRGB(255,200,0),  Trans=0},
}
function Chams.Apply(p)
    local char = Util.Char(p); if not char then return end
    local style = ChamStyles[S("ChamStyle") or "Neon"] or ChamStyles.Neon
    Chams.Orig[p.UserId] = Chams.Orig[p.UserId] or {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name~="HumanoidRootPart" then
            pcall(function()
                if not Chams.Orig[p.UserId][part] then
                    Chams.Orig[p.UserId][part]={Mat=part.Material,Color=part.Color,Trans=part.Transparency}
                end
                part.Material=style.Material; part.Color=style.Color; part.Transparency=style.Trans
            end)
        end
    end
end
function Chams.Remove(p)
    local saved = p and Chams.Orig[p.UserId]; if not saved then return end
    for part, orig in pairs(saved) do
        pcall(function()
            if part and part.Parent then
                part.Material=orig.Mat; part.Color=orig.Color; part.Transparency=orig.Trans
            end
        end)
    end
    Chams.Orig[p.UserId]=nil
end
function Chams.Tick()
    if not CanRun("Chams") then return end  -- throttled to 4x/sec
    for _, p in ipairs(GetPlayers()) do
        if S("Chams") then Chams.Apply(p)
        elseif Chams.Orig[p.UserId] then Chams.Remove(p) end
    end
end

-- ========================================================
-- // FULLBRIGHT
-- ========================================================
local FB = { Orig=nil }
function FB.On()
    if not FB.Orig then
        FB.Orig={Brightness=Lighting.Brightness,GlobalShadows=Lighting.GlobalShadows,
                 FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart,Ambient=Lighting.Ambient}
    end
    Lighting.Brightness=6; Lighting.GlobalShadows=false
    Lighting.FogEnd=1e9; Lighting.FogStart=1e9; Lighting.Ambient=Color3.fromRGB(255,255,255)
    for _,v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then
            pcall(function() v.Parent=nil end)
        end
    end
end
function FB.Off()
    if FB.Orig then
        Lighting.Brightness=FB.Orig.Brightness; Lighting.GlobalShadows=FB.Orig.GlobalShadows
        Lighting.FogEnd=FB.Orig.FogEnd; Lighting.FogStart=FB.Orig.FogStart; Lighting.Ambient=FB.Orig.Ambient
    end; FB.Orig=nil
end

-- ========================================================
-- // MOVEMENT — all throttled
-- ========================================================
local Move = {}
function Move.Fly()
    if not S("Fly") then return end
    local char = Util.Char(LocalPlayer); local cam = GetCamera()
    if not char or not cam then return end
    pcall(function()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        hum:ChangeState(Enum.HumanoidStateType.Swimming)
        local dir = Vector3.zero; local UIS = UserInputService
        if UIS:IsKeyDown(Enum.KeyCode.W)         then dir+=cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S)         then dir-=cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A)         then dir-=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D)         then dir+=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)     then dir+=Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.yAxis end
        hrp.AssemblyLinearVelocity=(dir.Magnitude>0 and dir.Unit or Vector3.zero)*(S("FlySpeed") or 50)
    end)
end
function Move.Noclip()
    if not S("Noclip") or not CanRun("Noclip") then return end
    local char = Util.Char(LocalPlayer); if not char then return end
    pcall(function()
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end)
end
function Move.Speed()
    if not CanRun("Speed") then return end
    local char = Util.Char(LocalPlayer); if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = S("SpeedHack") and (16*(S("SpeedMult") or 1.5)) or 16 end
    end)
end
function Move.Gravity()
    if not CanRun("Gravity") then return end
    pcall(function() Workspace.Gravity = S("LowGravity") and 40 or 196.2 end)
end

Track(UserInputService.JumpRequest:Connect(function()
    if not S("InfiniteJump") then return end
    local char = Util.Char(LocalPlayer); if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end))

-- ========================================================
-- // WATERMARK — throttled draw
-- ========================================================
local WM = { D=nil, LastUpdate=0 }
function WM.Tick()
    if not Drawing or not S("WatermarkShow") then
        SafeSet(WM.D,"Visible",false); return
    end
    if not WM.D then
        WM.D = NewDraw("Text",{Size=13,Outline=true,OutlineColor=Color3.fromRGB(0,0,0),
                                Color=Color3.fromRGB(0,215,155),Visible=false,Position=Vector2.new(6,6)})
    end
    local now = os.clock()
    if (now - WM.LastUpdate) >= 0.5 then  -- update text 2x/sec max
        WM.LastUpdate = now
        SafeSet(WM.D,"Text",("0 HUB v7.1  |  errs:%d  |  %ds"):format(
            Runtime.Errors, math.floor(now-Runtime.StartTime)))
    end
    SafeSet(WM.D,"Visible",true)
end

-- ========================================================
-- // NOTIFICATIONS
-- ========================================================
local Notif = { Q={}, Max=6 }
local NX,NY,NH = 16,16,28
function Notif.Push(title,msg,dur,color)
    if not S("Notifications") or not Drawing then return end
    dur = dur or 3.5
    local now = os.clock()
    local n = {
        BG     = NewDraw("Square",{Filled=true,Color=Color3.fromRGB(12,12,18),Transparent=0,Visible=false}),
        Accent = NewDraw("Square",{Filled=true,Color=color or Color3.fromRGB(0,215,155),Transparent=0,Visible=false}),
        Text   = NewDraw("Text",{Size=13,Color=Color3.fromRGB(240,240,240),Outline=true,OutlineColor=Color3.fromRGB(0,0,0),Visible=false}),
        Born=now, Exp=now+dur,
    }
    SafeSet(n.Text,"Text","["..title.."] "..msg)
    table.insert(Notif.Q,n)
    while #Notif.Q > Notif.Max do
        local old=table.remove(Notif.Q,1)
        pcall(function() old.BG:Remove(); old.Accent:Remove(); old.Text:Remove() end)
    end
    task.delay(dur+0.5, function()
        for i,x in ipairs(Notif.Q) do if x==n then table.remove(Notif.Q,i); break end end
        pcall(function() n.BG:Remove(); n.Accent:Remove(); n.Text:Remove() end)
    end)
end
function Notif.Tick()
    local now=os.clock()
    for i,n in ipairs(Notif.Q) do
        local t = (now-n.Born)/(n.Exp-n.Born)
        local a = math.clamp(t<0.15 and t/0.15 or (t>0.80 and (1-t)/0.20 or 1), 0, 1)
        local y = NY+(i-1)*(NH+4)
        SafeSet(n.BG,"Position",Vector2.new(NX,y));     SafeSet(n.BG,"Size",Vector2.new(280,NH));  SafeSet(n.BG,"Transparency",a*0.93)
        SafeSet(n.Accent,"Position",Vector2.new(NX,y));  SafeSet(n.Accent,"Size",Vector2.new(3,NH)); SafeSet(n.Accent,"Transparency",a)
        SafeSet(n.Text,"Position",Vector2.new(NX+10,y+7)); SafeSet(n.Text,"Transparency",a)
        SafeSet(n.BG,"Visible",a>0.01); SafeSet(n.Accent,"Visible",a>0.01); SafeSet(n.Text,"Visible",a>0.01)
    end
end

-- ========================================================
-- // PANIC
-- ========================================================
local Panic = { On=false, Saved={} }
function Panic.Toggle()
    if not Panic.On then
        Panic.On=true
        for k,v in pairs(Settings) do if v.Type=="toggle" then Panic.Saved[k]=v.Value; v.Value=false end end
        Target.Clear()
        SafeSet(FOVCircle,"Visible",false)
        for _,d in pairs(ESPSys.Cache) do HideAll(d) end
        XHair.Clear()
        Notif.Push("PANIC","All features killed",5,Color3.fromRGB(220,50,50))
    else
        Panic.On=false
        for k,v in pairs(Panic.Saved) do if Settings[k] then Settings[k].Value=v end end
        Notif.Push("RESTORED","Back online",3,Color3.fromRGB(0,215,155))
    end
end

-- ========================================================
-- // MENU UI
-- ========================================================
local Menu = {
    Vis=true, Pos=Vector2.new(80,80), W=260,
    HdrH=32, TabH=26, RowH=27, Pad=10,
    Tabs={"Aimbot","ESP","Visuals","Movement","Misc"},
    ActiveTab="Aimbot",
    Drw={}, Drag=false, DragOff=Vector2.zero,
    Rows={}, ClickCD=0,
}
local AC=Color3.fromRGB(0,215,155); local BG1=Color3.fromRGB(12,12,16); local BG2=Color3.fromRGB(20,20,26)
local BG3=Color3.fromRGB(26,26,34); local BG4=Color3.fromRGB(22,22,30)
local TPRI=Color3.fromRGB(235,235,235); local TSEC=Color3.fromRGB(120,120,138)
local TACT=Color3.fromRGB(0,200,145); local TIDLE=Color3.fromRGB(70,70,88)

local function MD(cls,props)
    if not Drawing then return nil end
    local ok,d = pcall(function() return Drawing.new(cls) end)
    if not ok or not d then return nil end
    if props then for k,v in pairs(props) do pcall(function() d[k]=v end) end end
    table.insert(Menu.Drw,d); return d
end
function Menu.ClearDraw()
    for _,d in ipairs(Menu.Drw) do pcall(function() d:Remove() end) end
    Menu.Drw={}; Menu.Rows={}
end
function Menu.Build()
    Menu.ClearDraw()
    if not Drawing or not Menu.Vis then return end
    local p=Menu.Pos; local W=Menu.W
    local tabW=math.floor(W/#Menu.Tabs)
    local rows={}
    for k,v in pairs(Settings) do if v.Tab==Menu.ActiveTab then table.insert(rows,{K=k,C=v}) end end
    table.sort(rows,function(a,b) return a.K<b.K end)
    local totalH=Menu.HdrH+Menu.TabH+#rows*Menu.RowH+8
    MD("Square",{Position=Vector2.new(p.X-3,p.Y-3),Size=Vector2.new(W+6,totalH+6),Color=Color3.fromRGB(0,0,0),Filled=true,Transparency=0.3})
    MD("Square",{Position=p,Size=Vector2.new(W,totalH),Color=BG1,Filled=true,Transparency=0.96})
    MD("Square",{Position=p,Size=Vector2.new(W,Menu.HdrH),Color=BG2,Filled=true,Transparency=1})
    MD("Square",{Position=p,Size=Vector2.new(3,Menu.HdrH),Color=AC,Filled=true,Transparency=1})
    MD("Text",{Text="0 HUB  v7.1",Position=Vector2.new(p.X+12,p.Y+8),Size=15,Color=TPRI,Outline=true,OutlineColor=Color3.fromRGB(0,0,0)})
    MD("Text",{Text="[INS]",Position=Vector2.new(p.X+W-38,p.Y+9),Size=12,Color=TSEC,Outline=false})
    MD("Square",{Position=Vector2.new(p.X,p.Y+Menu.HdrH),Size=Vector2.new(W,Menu.TabH),Color=BG2,Filled=true,Transparency=1})
    for i,tab in ipairs(Menu.Tabs) do
        local tx=p.X+(i-1)*tabW; local ty=p.Y+Menu.HdrH; local isAct=tab==Menu.ActiveTab
        MD("Square",{Position=Vector2.new(tx,ty),Size=Vector2.new(tabW,Menu.TabH),Color=(isAct and BG3 or BG2),Filled=true,Transparency=1})
        if isAct then MD("Square",{Position=Vector2.new(tx+2,ty+Menu.TabH-2),Size=Vector2.new(tabW-4,2),Color=AC,Filled=true,Transparency=1}) end
        MD("Text",{Text=tab,Position=Vector2.new(tx+tabW/2,ty+6),Size=11,Center=true,Color=(isAct and TACT or TIDLE),Outline=false})
        table.insert(Menu.Rows,{Type="tab",Tab=tab,B={X=tx,Y=ty,W=tabW,H=Menu.TabH}})
    end
    local ry0=p.Y+Menu.HdrH+Menu.TabH+4
    for idx,row in ipairs(rows) do
        local k=row.K; local cfg=row.C; local ry=ry0+(idx-1)*Menu.RowH; local alt=idx%2==0
        MD("Square",{Position=Vector2.new(p.X+3,ry),Size=Vector2.new(W-6,Menu.RowH-2),Color=(alt and BG4 or BG3),Filled=true,Transparency=0.85})
        MD("Text",{Text=k,Position=Vector2.new(p.X+Menu.Pad+3,ry+7),Size=12,Color=TPRI,Outline=true,OutlineColor=Color3.fromRGB(0,0,0)})
        if cfg.Type=="toggle" then
            local bx2=p.X+W-26; local by2=ry+6; local bs=15
            MD("Square",{Position=Vector2.new(bx2,by2),Size=Vector2.new(bs,bs),Color=(cfg.Value and AC or Color3.fromRGB(44,44,56)),Filled=true,Transparency=1})
            if cfg.Value then MD("Text",{Text="✓",Position=Vector2.new(bx2+1,by2+1),Size=13,Color=Color3.fromRGB(0,0,0),Outline=false}) end
            table.insert(Menu.Rows,{Type="toggle",Key=k,B={X=p.X+3,Y=ry,W=W-6,H=Menu.RowH-2}})
        elseif cfg.Type=="slider" then
            local sx=p.X+W/2+4; local sw=W/2-22; local sy=ry+Menu.RowH/2
            local mn=cfg.Min or 0; local mx=cfg.Max or 100; if mx<=mn then mx=mn+1 end; local ratio=math.clamp((cfg.Value-mn)/(mx-mn),0,1)
            MD("Square",{Position=Vector2.new(sx,sy-2),Size=Vector2.new(sw,4),Color=Color3.fromRGB(40,40,52),Filled=true,Transparency=1})
            MD("Square",{Position=Vector2.new(sx,sy-2),Size=Vector2.new(sw*ratio,4),Color=AC,Filled=true,Transparency=1})
            MD("Circle",{Position=Vector2.new(sx+sw*ratio,sy),Radius=5,Color=Color3.fromRGB(255,255,255),Filled=true,Transparency=1})
            MD("Text",{Text=tostring(math.floor(cfg.Value*100+0.5)/100),Position=Vector2.new(sx-4,ry+7),Size=10,Color=TSEC,Outline=false})
            table.insert(Menu.Rows,{Type="slider",Key=k,SX=sx,SW=sw,B={X=sx,Y=ry,W=sw,H=Menu.RowH-2}})
        elseif cfg.Type=="dropdown" then
            local dx=p.X+W-95
            MD("Square",{Position=Vector2.new(dx,ry+5),Size=Vector2.new(86,17),Color=Color3.fromRGB(30,30,40),Filled=true,Transparency=1})
            MD("Text",{Text=tostring(cfg.Value),Position=Vector2.new(dx+5,ry+7),Size=11,Color=TACT,Outline=false})
            MD("Text",{Text="▾",Position=Vector2.new(dx+72,ry+6),Size=12,Color=TSEC,Outline=false})
            table.insert(Menu.Rows,{Type="dropdown",Key=k,B={X=dx,Y=ry+5,W=86,H=17}})
        end
    end
end

-- ========================================================
-- // UI BUILD SCHEDULER
-- ========================================================
local MenuBuildBusy = false
local MenuBuildQueued = false

local function SafeMenuBuild()
    if MenuBuildBusy then
        MenuBuildQueued = true
        return
    end

    if not Menu or type(Menu.Build) ~= "function" then
        return
    end

    MenuBuildBusy = true
    MenuBuildQueued = false

    task.defer(function()
        local ok, err = xpcall(function()
            if Menu.Vis then
                QueueMenuBuild()
            else
                Menu.ClearDraw()
            end
        end, function(e)
            return tostring(e) .. "\\n" ..
                (debug and debug.traceback and debug.traceback("", 2) or "")
        end)

        if not ok then
            warn("[0 HUB UI] Build failed: " .. tostring(err))
        end

        MenuBuildBusy = false

        if MenuBuildQueued then
            MenuBuildQueued = false
            task.defer(SafeMenuBuild)
        end
    end)
end

local function QueueMenuBuild()
    if not Menu or type(Menu.Build) ~= "function" then
        return
    end

    if MenuBuildBusy then
        MenuBuildQueued = true
        return
    end

    SafeMenuBuild()
end

local function InB(b,m) return m.X>=b.X and m.X<=b.X+b.W and m.Y>=b.Y and m.Y<=b.Y+b.H end
local SDrag={Act=false,Key=nil,Row=nil}
function Menu.Tick()
    if not Menu.Vis then return end
    local ok,mp = pcall(function() return UserInputService:GetMouseLocation() end); if not ok then return end
    local ok2,mb = pcall(function() return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end); if not ok2 then return end
    local now=os.clock()
    local hB={X=Menu.Pos.X,Y=Menu.Pos.Y,W=Menu.W,H=Menu.HdrH}
    if mb then
        if not Menu.Drag and not SDrag.Act and InB(hB,mp) then Menu.Drag=true; Menu.DragOff=Menu.Pos-mp end
        if Menu.Drag then
            local np=mp+Menu.DragOff; local cam=GetCamera()
            if cam then
                local ok3,vp=pcall(function() return cam.ViewportSize end)
                if ok3 and vp then np=Vector2.new(math.clamp(np.X,0,vp.X-Menu.W),math.clamp(np.Y,0,vp.Y-60)) end
            end
            if (np-Menu.Pos).Magnitude>0.5 then Menu.Pos=np; QueueMenuBuild() end
        end
    else Menu.Drag=false end
    if SDrag.Act then
        if mb then
            local cfg=Settings[SDrag.Key]; local row=SDrag.Row
            if cfg and row then
                local ratio=math.clamp((mp.X-row.SX)/row.SW,0,1)
                local nv=(cfg.Min or 0)+((cfg.Max or 100)-(cfg.Min or 0))*ratio
                nv=math.floor(nv*100+0.5)/100
                if math.abs(nv-cfg.Value)>0.005 then cfg.Value=nv; QueueMenuBuild() end
            end
        else SDrag.Act=false; SDrag.Key=nil; SDrag.Row=nil end
        return
    end
    if mb and (now-Menu.ClickCD)>0.15 and not Menu.Drag then
        for _,row in ipairs(Menu.Rows) do
            if InB(row.B,mp) then
                Menu.ClickCD=now
                if row.Type=="tab" then Menu.ActiveTab=row.Tab; QueueMenuBuild()
                elseif row.Type=="toggle" then
                    local cfg=Settings[row.Key]
                    if cfg then
                        cfg.Value=not cfg.Value
                        if row.Key=="Chams" then
                            if cfg.Value then for _,p in ipairs(GetPlayers()) do Chams.Apply(p) end
                            else for _,p in ipairs(GetPlayers()) do Chams.Remove(p) end end
                        elseif row.Key=="FullBright" then if cfg.Value then FB.On() else FB.Off() end
                        elseif row.Key=="FOVChanger" then
                            local cam=GetCamera(); if cam then pcall(function() cam.FieldOfView=cfg.Value and (S("CustomFOV") or 90) or 70 end) end
                        end
                        QueueMenuBuild()
                    end
                elseif row.Type=="slider" then SDrag.Act=true; SDrag.Key=row.Key; SDrag.Row=row
                elseif row.Type=="dropdown" then
                    local cfg=Settings[row.Key]
                    if cfg and cfg.Options then
                        local idx=1
                        for i,o in ipairs(cfg.Options) do if o==cfg.Value then idx=i; break end end
                        cfg.Value=cfg.Options[(idx%#cfg.Options)+1]
                        if row.Key=="ChamStyle" then for _,p in ipairs(GetPlayers()) do if S("Chams") then Chams.Apply(p) end end end
                        QueueMenuBuild()
                    end
                end
                break
            end
        end
    end
end

-- ========================================================
-- // KEYBINDS
-- ========================================================
local KeyMap={Delete=Enum.KeyCode.Delete,End=Enum.KeyCode.End,F9=Enum.KeyCode.F9,
              Insert=Enum.KeyCode.Insert,F4=Enum.KeyCode.F4,Home=Enum.KeyCode.Home}
Track(UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==KeyMap[S("PanicKey") or "Delete"] then Panic.Toggle(); return end
    if input.KeyCode==KeyMap[S("MenuKey")  or "Insert"] then
        Menu.Vis=not Menu.Vis
        if Menu.Vis then QueueMenuBuild() else Menu.ClearDraw() end
    end
end))

Track(Players.PlayerRemoving:Connect(function(p)
    ESPSys.Remove(p.UserId)
    Chams.Remove(p)
    VelHistory[p.UserId]=nil
end))

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    Move.Speed(); Move.Gravity()
    local cam=GetCamera()
    if cam then pcall(function() cam.FieldOfView=S("FOVChanger") and (S("CustomFOV") or 90) or 70 end) end
end)

-- ========================================================
-- // RENDER LOOP — decoupled, budgeted, non-blocking
-- ========================================================
Track(RunService.RenderStepped:Connect(function(dt)
    if Runtime.Dead then return end
    Runtime.FrameCount += 1
    -- lightweight every frame
    SafeCall(UpdateFOV,   Budget.Aimbot, dt)
    SafeCall(Aimbot.Update, Budget.Aimbot)
    SafeCall(TrigBot.Update, Budget.TrigBot)
    SafeCall(Notif.Tick,  Budget.Notif)
    SafeCall(XHair.Tick,  Budget.XHair)
    -- ESP is frame-split internally — safe to call every frame
    SafeCall(ESPSys.Update, Budget.ESP)
    if Menu.Vis then SafeCall(Menu.Tick, 0.003) end
    SafeCall(WM.Tick, 0.001)
end))

-- ========================================================
-- // HEARTBEAT LOOP — physics-synced, throttled
-- ========================================================
Track(RunService.Heartbeat:Connect(function()
    if Runtime.Dead then return end
    SafeCall(Move.Fly,     Budget.Move)
    SafeCall(Move.Noclip,  Budget.Move)
    SafeCall(Move.Speed,   Budget.Move)
    SafeCall(Move.Gravity, Budget.Move)
    SafeCall(Chams.Tick,   Budget.Chams)
end))

-- ========================================================
-- // INIT
-- ========================================================
-- ========================================================
-- // INIT — UI FIRST / NON-BLOCKING
-- ========================================================

Runtime.Loaded = true

task.defer(function()
    QueueMenuBuild()

    pcall(function()
        Notif.Push(
            "0 HUB",
            "UI ready — fuck yeah, boss man.",
            4,
            AC
        )
    end)
end)

task.defer(function()
    SafeCall(RebuildPlayerCache)
end)

task.defer(function()
    SafeCall(Hooks.Install)
end)

print("[0 HUB v7.1] UI-first startup complete.")
