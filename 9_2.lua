-- ========================================================
-- 0 HUB v9.1 — STABILITY PATCH / NON-BLOCKING STARTUP
-- ========================================================
-- TTT11
-- ========================================================
-- 0 HUB v9.1 - RIVALS FPS EDITION
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
    Version    = "9.1.0",
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
        function(e) return tostring(e) .. "\n" .. (debug and debug.traceback and debug.traceback("",2) or "") end
    )
    if not ok then
        Runtime.Errors += 1
        warn(("[0 HUB v9] ERR#%d → %s"):format(Runtime.Errors, tostring(err)))
        if Runtime.Errors >= Runtime.MaxErrors then
            warn("[0 HUB v9] error cap — killed")
            Runtime.Dead = true
        end
    end
    local elapsed = os.clock() - t0
    if budget and elapsed > budget then
        -- soft warn only, don't crash
        -- warn(("[0 HUB v8] budget overrun: %.2fms / %.2fms"):format(elapsed*1000, budget*1000))
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
    AntiBan          = { Value=false,    Type="toggle",   Tab="Misc" },
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
-- // HOOKS — disabled in V9.1 for client stability
-- ========================================================
local Hooks = {
    Done       = true,
    OrigIndex  = nil,
    Disabled   = true,
    Reason     = "Disabled for client-initialization stability",
}

function Hooks.Install()
    -- V9.1 intentionally does NOT modify game metatables.
    -- The previous global __namecall/__index hooks could interfere with
    -- the game's own ClientFighter initialization and make debugging
    -- impossible. Keep the hub independent from ReplicatedFirst/client
    -- replicated classes.
    return false
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
        SafeSet(WM.D,"Text",("0 HUB v8  |  errs:%d  |  %ds"):format(
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
    if not Menu or not Menu.Vis then return end
    Menu.ClearDraw()
    if not Drawing then return end
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
    MD("Text",{Text="0 HUB  v9.1",Position=Vector2.new(p.X+12,p.Y+8),Size=15,Color=TPRI,Outline=true,OutlineColor=Color3.fromRGB(0,0,0)})
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
local QueueMenuBuild

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
                Menu.Build()
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
            task.defer(QueueMenuBuild)
        end
    end)
end

QueueMenuBuild = function()
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
                        if row.Key=="AntiBan" then
                            -- Intentionally inert in V9.1; no metatable bypass is installed.
                        elseif row.Key=="Chams" then
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
            "UI ready — fuck yeah, boss man. Hooks disabled for stability.",
            4,
            AC
        )
    end)
end)

task.defer(function()
    SafeCall(RebuildPlayerCache)
end)

task.defer(function()
    -- Hooks intentionally disabled in V9.1 for client stability.
    Hooks.Install()
end)

print("[0 HUB v9.1] UI-first startup complete — hooks disabled, persistent reopen overlay enabled.")

-- ========================================================
-- // V9 — PERSISTENT OVERLAY REOPEN BUTTON
-- // Independent of Menu.Tick(), so it remains available
-- // after F4/Insert/Home closes the main menu.
-- ========================================================

local Overlay = {
    Visible     = true,
    Size        = 34,
    Margin      = 12,
    Position    = nil,
    ClickCD     = 0,
    Hover       = false,
    Draws       = {},
    Initialized = false,
}

local OverlayColors = {
    BG      = Color3.fromRGB(12, 12, 18),
    BGHover = Color3.fromRGB(24, 32, 38),
    Border  = Color3.fromRGB(0, 215, 155),
    Icon    = Color3.fromRGB(235, 235, 235),
    Shadow  = Color3.fromRGB(0, 0, 0),
}

local function OverlayNew(cls, props)
    if not Drawing then
        return nil
    end

    local ok, obj = pcall(function()
        return Drawing.new(cls)
    end)

    if not ok or not obj then
        return nil
    end

    if props then
        for k, v in pairs(props) do
            pcall(function()
                obj[k] = v
            end)
        end
    end

    table.insert(Overlay.Draws, obj)
    return obj
end

function Overlay.Clear()
    for _, obj in ipairs(Overlay.Draws) do
        pcall(function()
            obj:Remove()
        end)
    end

    Overlay.Draws = {}
    Overlay.Initialized = false
end

function Overlay.GetViewport()
    local cam = GetCamera()
    if not cam then
        return nil
    end

    local ok, viewport = pcall(function()
        return cam.ViewportSize
    end)

    return ok and viewport or nil
end

function Overlay.GetPosition()
    local viewport = Overlay.GetViewport()
    if not viewport then
        return nil
    end

    local size = Overlay.Size
    local margin = Overlay.Margin

    return Vector2.new(
        margin,
        viewport.Y - size - margin
    )
end

function Overlay.Build()
    Overlay.Clear()

    if not Drawing then
        return
    end

    local pos = Overlay.GetPosition()
    if not pos then
        return
    end

    Overlay.Position = pos

    Overlay.Shadow = OverlayNew("Square", {
        Position     = Vector2.new(pos.X - 2, pos.Y - 2),
        Size         = Vector2.new(Overlay.Size + 4, Overlay.Size + 4),
        Color        = OverlayColors.Shadow,
        Filled       = true,
        Transparency = 0.35,
        Visible      = true,
    })

    Overlay.BG = OverlayNew("Square", {
        Position     = pos,
        Size         = Vector2.new(Overlay.Size, Overlay.Size),
        Color        = OverlayColors.BG,
        Filled       = true,
        Transparency = 0.95,
        Visible      = true,
    })

    Overlay.Border = OverlayNew("Square", {
        Position     = pos,
        Size         = Vector2.new(2, Overlay.Size),
        Color        = OverlayColors.Border,
        Filled       = true,
        Transparency = 1,
        Visible      = true,
    })

    Overlay.Icon1 = OverlayNew("Line", {
        From         = Vector2.new(pos.X + 9,  pos.Y + 10),
        To           = Vector2.new(pos.X + 25, pos.Y + 10),
        Thickness    = 2,
        Color        = OverlayColors.Icon,
        Transparency = 1,
        Visible      = true,
    })

    Overlay.Icon2 = OverlayNew("Line", {
        From         = Vector2.new(pos.X + 9,  pos.Y + 16),
        To           = Vector2.new(pos.X + 25, pos.Y + 16),
        Thickness    = 2,
        Color        = OverlayColors.Icon,
        Transparency = 1,
        Visible      = true,
    })

    Overlay.Icon3 = OverlayNew("Line", {
        From         = Vector2.new(pos.X + 9,  pos.Y + 22),
        To           = Vector2.new(pos.X + 25, pos.Y + 22),
        Thickness    = 2,
        Color        = OverlayColors.Icon,
        Transparency = 1,
        Visible      = true,
    })

    Overlay.Initialized = true
end

function Overlay.SetVisible(state)
    Overlay.Visible = state

    for _, obj in ipairs(Overlay.Draws) do
        pcall(function()
            obj.Visible = state
        end)
    end
end

function Overlay.UpdatePosition()
    if not Overlay.Initialized then
        Overlay.Build()
        return
    end

    local pos = Overlay.GetPosition()
    if not pos then
        return
    end

    if not Overlay.Position or (pos - Overlay.Position).Magnitude > 0.5 then
        Overlay.Position = pos

        pcall(function()
            Overlay.Shadow.Position = Vector2.new(pos.X - 2, pos.Y - 2)
            Overlay.BG.Position     = pos
            Overlay.Border.Position = pos

            Overlay.Icon1.From = Vector2.new(pos.X + 9,  pos.Y + 10)
            Overlay.Icon1.To   = Vector2.new(pos.X + 25, pos.Y + 10)

            Overlay.Icon2.From = Vector2.new(pos.X + 9,  pos.Y + 16)
            Overlay.Icon2.To   = Vector2.new(pos.X + 25, pos.Y + 16)

            Overlay.Icon3.From = Vector2.new(pos.X + 9,  pos.Y + 22)
            Overlay.Icon3.To   = Vector2.new(pos.X + 25, pos.Y + 22)
        end)
    end
end

function Overlay.IsInside(mouse)
    local pos = Overlay.Position
    if not pos or not mouse then
        return false
    end

    return
        mouse.X >= pos.X and
        mouse.X <= pos.X + Overlay.Size and
        mouse.Y >= pos.Y and
        mouse.Y <= pos.Y + Overlay.Size
end

function Overlay.SetHover(state)
    if Overlay.Hover == state then
        return
    end

    Overlay.Hover = state

    if Overlay.BG then
        SafeSet(
            Overlay.BG,
            "Color",
            state and OverlayColors.BGHover or OverlayColors.BG
        )
    end

    if Overlay.Border then
        SafeSet(
            Overlay.Border,
            "Color",
            state and Color3.fromRGB(0, 255, 185) or OverlayColors.Border
        )
    end
end

function Overlay.OpenMenu()
    local now = os.clock()

    if (now - Overlay.ClickCD) < 0.15 then
        return
    end

    Overlay.ClickCD = now

    if Menu.Vis then
        return
    end

    Menu.Vis = true

    -- Recover from a stale/aborted scheduler state.
    MenuBuildBusy   = false
    MenuBuildQueued = false

    task.defer(function()
        local ok, err = xpcall(function()
            Menu.ClearDraw()
            Menu.Build()
        end, function(e)
            return tostring(e) .. "\n" ..
                (debug and debug.traceback
                    and debug.traceback("", 2)
                    or "")
        end)

        if not ok then
            warn("[0 HUB V9 UI] Overlay reopen failed: " .. tostring(err))

            task.defer(function()
                pcall(function()
                    QueueMenuBuild()
                end)
            end)
        end
    end)

    pcall(function()
        Notif.Push(
            "0 HUB",
            "Menu reopened.",
            2.5,
            OverlayColors.Border
        )
    end)
end

function Overlay.Tick()
    if not Drawing then
        return
    end

    if not Overlay.Initialized then
        Overlay.Build()
    end

    Overlay.UpdatePosition()

    -- Only show the button while the primary menu is hidden.
    Overlay.SetVisible(not Menu.Vis)

    if Menu.Vis then
        Overlay.SetHover(false)
        return
    end

    local ok, mouse = pcall(function()
        return UserInputService:GetMouseLocation()
    end)

    if not ok or not mouse then
        return
    end

    Overlay.SetHover(Overlay.IsInside(mouse))
end

-- ========================================================
-- // V9 OVERLAY INPUT
-- // Separate from Menu.Tick(), which intentionally stops
-- // running when Menu.Vis == false.
-- ========================================================

Track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
        return
    end

    if Menu.Vis then
        return
    end

    local ok, mouse = pcall(function()
        return UserInputService:GetMouseLocation()
    end)

    if not ok or not mouse then
        return
    end

    if Overlay.IsInside(mouse) then
        Overlay.OpenMenu()
    end
end))

-- ========================================================
-- // V9 OVERLAY RENDER LOOP
-- // Runs independently from the main menu loop.
-- ========================================================

Track(RunService.RenderStepped:Connect(function()
    if Runtime.Dead then
        return
    end

    SafeCall(Overlay.Tick, 0.001)
end))

-- ========================================================
-- // V9 OVERLAY INITIALIZATION
-- ========================================================

task.defer(function()
    pcall(function()
        Overlay.Build()
        Overlay.Tick()
    end)
end)


-- ========================================================
-- // V9.1 — ROBLOX GUI FALLBACK
-- // If Drawing is unavailable/blocked, the original menu
-- // cannot render. This fallback uses ordinary ScreenGui
-- // instances so the hub still has a visible control panel.
-- ========================================================

local FallbackUI = {
    Gui = nil,
    Main = nil,
    Body = nil,
    OpenButton = nil,
    Visible = true,
    Dragging = false,
    DragOffset = nil,
    Connections = {},
    Built = false,
}

local function FallbackTrack(conn)
    if conn then
        table.insert(FallbackUI.Connections, conn)
    end
    return conn
end

local function GetGuiParent()
    local ok, result = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return game:GetService("CoreGui")
    end)

    if ok and result then
        return result
    end

    local ok2, playerGui = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)

    return ok2 and playerGui or nil
end

local function NewGui(className)
    local ok, obj = pcall(function()
        return Instance.new(className)
    end)

    return ok and obj or nil
end

local function Apply(inst, props)
    if not inst then
        return inst
    end

    for key, value in pairs(props or {}) do
        pcall(function()
            inst[key] = value
        end)
    end

    return inst
end

local function AddCorner(parent, radius)
    local corner = NewGui("UICorner")
    if not corner then
        return
    end

    corner.CornerRadius = UDim.new(0, radius or 6)
    corner.Parent = parent
end

local function AddStroke(parent, color, thickness)
    local stroke = NewGui("UIStroke")
    if not stroke then
        return
    end

    stroke.Color = color or Color3.fromRGB(0, 215, 155)
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.15
    stroke.Parent = parent
end

local function MakeButton(parent, text, size, position)
    local button = NewGui("TextButton")
    if not button then
        return nil
    end

    Apply(button, {
        Parent = parent,
        BackgroundColor3 = Color3.fromRGB(28, 28, 36),
        BorderSizePixel = 0,
        Size = size,
        Position = position,
        Text = text,
        TextColor3 = Color3.fromRGB(235, 235, 235),
        TextSize = 13,
        Font = Enum.Font.Gotham,
        AutoButtonColor = true,
    })

    AddCorner(button, 5)
    return button
end

local function DestroyFallback()
    for _, conn in ipairs(FallbackUI.Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    FallbackUI.Connections = {}

    if FallbackUI.Gui then
        pcall(function()
            FallbackUI.Gui:Destroy()
        end)
    end

    FallbackUI.Gui = nil
    FallbackUI.Main = nil
    FallbackUI.Body = nil
    FallbackUI.OpenButton = nil
end

local function FallbackSetVisible(state)
    FallbackUI.Visible = state

    if FallbackUI.Main then
        FallbackUI.Main.Visible = state
    end

    if FallbackUI.OpenButton then
        FallbackUI.OpenButton.Visible = not state
    end
end

local function SettingKeys(tab)
    local result = {}

    for key, cfg in pairs(Settings) do
        if cfg.Tab == tab then
            table.insert(result, key)
        end
    end

    table.sort(result)
    return result
end

local function SettingDisplayValue(cfg)
    if cfg.Type == "toggle" then
        return cfg.Value and "ON" or "OFF"
    end

    return tostring(cfg.Value)
end

local function FallbackApplySetting(key, amount)
    local cfg = Settings[key]
    if not cfg then
        return
    end

    if cfg.Type == "toggle" then
        cfg.Value = not cfg.Value

        if key == "FullBright" then
            if cfg.Value then
                FB.On()
            else
                FB.Off()
            end

        elseif key == "FOVChanger" then
            local cam = GetCamera()
            if cam then
                pcall(function()
                    cam.FieldOfView =
                        cfg.Value and (S("CustomFOV") or 90) or 70
                end)
            end

        elseif key == "Chams" then
            if cfg.Value then
                for _, player in ipairs(GetPlayers()) do
                    pcall(function()
                        Chams.Apply(player)
                    end)
                end
            else
                for _, player in ipairs(GetPlayers()) do
                    pcall(function()
                        Chams.Remove(player)
                    end)
                end
            end
        end

    elseif cfg.Type == "dropdown" then
        if cfg.Options and #cfg.Options > 0 then
            local current = 1

            for index, option in ipairs(cfg.Options) do
                if option == cfg.Value then
                    current = index
                    break
                end
            end

            cfg.Value = cfg.Options[(current % #cfg.Options) + 1]
        end

    elseif cfg.Type == "slider" then
        local minValue = cfg.Min or 0
        local maxValue = cfg.Max or 100
        local step = amount or ((maxValue - minValue) / 20)

        cfg.Value = math.clamp(
            (tonumber(cfg.Value) or minValue) + step,
            minValue,
            maxValue
        )

        cfg.Value = math.floor(cfg.Value * 100 + 0.5) / 100
    end
end

local function BuildFallbackTab(tabName)
    if not FallbackUI.Body then
        return
    end

    for _, child in ipairs(FallbackUI.Body:GetChildren()) do
        pcall(function()
            if not child:IsA("UIListLayout") then
                child:Destroy()
            end
        end)
    end

    local keys = SettingKeys(tabName)

    for _, key in ipairs(keys) do
        local cfg = Settings[key]

        local row = NewGui("Frame")
        if not row then
            continue
        end

        Apply(row, {
            Parent = FallbackUI.Body,
            BackgroundColor3 = Color3.fromRGB(24, 24, 31),
            BorderSizePixel = 0,
            Size = UDim2.new(1, -8, 0, 34),
        })

        AddCorner(row, 5)

        local label = NewGui("TextLabel")
        Apply(label, {
            Parent = row,
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(0.55, 0, 1, 0),
            Text = key,
            TextColor3 = Color3.fromRGB(235, 235, 235),
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        local button = MakeButton(
            row,
            SettingDisplayValue(cfg),
            UDim2.new(0.37, -4, 0, 24),
            UDim2.new(0.63, 0, 0.5, -12)
        )

        if button then
            FallbackTrack(button.MouseButton1Click:Connect(function()
                FallbackApplySetting(key)
                button.Text = SettingDisplayValue(cfg)

                -- Re-apply dependent settings safely.
                pcall(function()
                    if key == "ChamStyle" and S("Chams") then
                        for _, player in ipairs(GetPlayers()) do
                            Chams.Apply(player)
                        end
                    end
                end)
            end))
        end
    end

    local layout = NewGui("UIListLayout")
    if layout then
        layout.Parent = FallbackUI.Body
        layout.Padding = UDim.new(0, 4)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
    end
end

local function BuildFallback()
    DestroyFallback()

    local parent = GetGuiParent()
    if not parent then
        warn("[0 HUB V9.1] No GUI parent available; Drawing is also unavailable.")
        return false
    end

    local gui = NewGui("ScreenGui")
    if not gui then
        return false
    end

    Apply(gui, {
        Name = "ZeroHubV91Fallback",
        Parent = parent,
        ResetOnSpawn = false,
        IgnoreGuiInset = true,
        DisplayOrder = 1000000,
        ZIndexBehavior = Enum.ZIndexBehavior.Global,
    })

    FallbackUI.Gui = gui

    local main = NewGui("Frame")
    if not main then
        DestroyFallback()
        return false
    end

    Apply(main, {
        Parent = gui,
        Name = "Main",
        Position = UDim2.fromOffset(90, 90),
        Size = UDim2.fromOffset(430, 470),
        BackgroundColor3 = Color3.fromRGB(12, 12, 17),
        BackgroundTransparency = 0.03,
        BorderSizePixel = 0,
        Active = true,
        Visible = true,
    })

    AddCorner(main, 8)
    AddStroke(main, Color3.fromRGB(0, 215, 155), 1)

    FallbackUI.Main = main

    local header = NewGui("Frame")
    Apply(header, {
        Parent = main,
        BackgroundColor3 = Color3.fromRGB(20, 20, 27),
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 42),
        Active = true,
    })

    AddCorner(header, 8)

    local title = NewGui("TextLabel")
    Apply(title, {
        Parent = header,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -80, 1, 0),
        Text = "0 HUB v9.1  |  FALLBACK UI",
        TextColor3 = Color3.fromRGB(235, 235, 235),
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local close = MakeButton(
        header,
        "×",
        UDim2.fromOffset(34, 28),
        UDim2.new(1, -42, 0.5, -14)
    )

    if close then
        FallbackTrack(close.MouseButton1Click:Connect(function()
            FallbackSetVisible(false)
        end))
    end

    -- Dragging.
    local dragStart
    local startPos

    FallbackTrack(header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FallbackUI.Dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end))

    FallbackTrack(UserInputService.InputChanged:Connect(function(input)
        if not FallbackUI.Dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        local delta = input.Position - dragStart

        main.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end))

    FallbackTrack(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            FallbackUI.Dragging = false
        end
    end))

    local tabsFrame = NewGui("Frame")
    Apply(tabsFrame, {
        Parent = main,
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(8, 48),
        Size = UDim2.new(1, -16, 0, 34),
    })

    local tabLayout = NewGui("UIListLayout")
    Apply(tabLayout, {
        Parent = tabsFrame,
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local body = NewGui("ScrollingFrame")
    Apply(body, {
        Parent = main,
        Name = "Body",
        Position = UDim2.fromOffset(8, 88),
        Size = UDim2.new(1, -16, 1, -98),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
    })

    FallbackUI.Body = body

    local tabs = {"Aimbot", "ESP", "Visuals", "Movement", "Misc"}
    local activeTab = "Aimbot"

    for _, tabName in ipairs(tabs) do
        local tabButton = MakeButton(
            tabsFrame,
            tabName,
            UDim2.fromOffset(72, 30),
            UDim2.fromOffset(0, 0)
        )

        if tabButton then
            FallbackTrack(tabButton.MouseButton1Click:Connect(function()
                activeTab = tabName
                BuildFallbackTab(activeTab)
            end))
        end
    end

    local openButton = MakeButton(
        gui,
        "0",
        UDim2.fromOffset(42, 42),
        UDim2.fromOffset(14, 14)
    )

    if openButton then
        openButton.TextSize = 18
        openButton.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
        openButton.TextColor3 = Color3.fromRGB(0, 215, 155)
        AddStroke(openButton, Color3.fromRGB(0, 215, 155), 1)
        openButton.Visible = false

        FallbackTrack(openButton.MouseButton1Click:Connect(function()
            FallbackSetVisible(true)
        end))
    end

    FallbackUI.OpenButton = openButton
    FallbackUI.Built = true

    BuildFallbackTab(activeTab)

    return true
end

-- Build only when Drawing isn't available. This is the missing UI path
-- shown by the "startup complete" console message with no visible hub.
local DrawingAvailable = (Drawing ~= nil)

if not DrawingAvailable then
    local ok, err = xpcall(BuildFallback, debug.traceback)

    if ok and err then
        print("[0 HUB v9.1] Drawing unavailable -> ScreenGui fallback enabled.")
    else
        warn("[0 HUB v9.1] Fallback UI failed:", tostring(err))
    end
else
    print("[0 HUB v9.1] Drawing API detected -> native overlay/menu path active.")
end

-- Independent fallback hotkeys. These do not touch game-owned modules.
FallbackTrack(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.Insert
        or input.KeyCode == Enum.KeyCode.F4
        or input.KeyCode == Enum.KeyCode.Home then

        if not DrawingAvailable and FallbackUI.Built then
            FallbackSetVisible(not FallbackUI.Visible)
        end
    end
end))


-- ========================================================
-- // V9.2 — UI REPAIR
-- // Native ScreenGui is now the primary UI path.
-- // Fixes:
-- //   * invisible main panel
-- //   * dead hamburger/reopen button
-- //   * Insert/F4/Home state inversion
-- //   * unreliable CoreGui/gethui parenting
-- //   * broken slider/dropdown interaction
-- //   * duplicate Drawing UI
-- ========================================================

local NativeUI = {
    Gui = nil,
    Main = nil,
    Open = nil,
    Body = nil,
    TabBar = nil,
    ActiveTab = "Aimbot",
    Visible = true,
    Dragging = false,
    DragStart = nil,
    MainStart = nil,
    Connections = {},
}

local UI_COLORS = {
    Background = Color3.fromRGB(10, 10, 14),
    Panel      = Color3.fromRGB(16, 16, 22),
    Header     = Color3.fromRGB(21, 21, 29),
    Row        = Color3.fromRGB(23, 23, 31),
    RowAlt     = Color3.fromRGB(27, 27, 36),
    Accent     = Color3.fromRGB(0, 215, 155),
    Text       = Color3.fromRGB(235, 235, 240),
    Muted      = Color3.fromRGB(135, 135, 150),
    Off        = Color3.fromRGB(54, 54, 66),
    White      = Color3.fromRGB(255, 255, 255),
}

local function UITrack(conn)
    if conn then
        table.insert(NativeUI.Connections, conn)
    end
    return conn
end

local function UIDisconnect()
    for _, conn in ipairs(NativeUI.Connections) do
        pcall(function()
            conn:Disconnect()
        end)
    end

    NativeUI.Connections = {}
end

local function UIMake(className, parent, props)
    local ok, obj = pcall(function()
        return Instance.new(className)
    end)

    if not ok or not obj then
        return nil
    end

    for key, value in pairs(props or {}) do
        pcall(function()
            obj[key] = value
        end)
    end

    obj.Parent = parent
    return obj
end

local function UICorner(parent, radius)
    return UIMake("UICorner", parent, {
        CornerRadius = UDim.new(0, radius or 6),
    })
end

local function UIStroke(parent, color, thickness)
    return UIMake("UIStroke", parent, {
        Color = color or UI_COLORS.Accent,
        Thickness = thickness or 1,
        Transparency = 0.1,
    })
end

local function UIGetPlayerGui()
    local ok, gui = pcall(function()
        return LocalPlayer:FindFirstChildOfClass("PlayerGui")
    end)

    if ok and gui then
        return gui
    end

    local ok2, fallback = pcall(function()
        if type(gethui) == "function" then
            return gethui()
        end
        return nil
    end)

    return ok2 and fallback or nil
end

local function UISettingValue(cfg)
    if not cfg then
        return ""
    end

    if cfg.Type == "toggle" then
        return cfg.Value and "ON" or "OFF"
    end

    if cfg.Type == "slider" then
        return tostring(math.floor((tonumber(cfg.Value) or 0) * 100 + 0.5) / 100)
    end

    return tostring(cfg.Value)
end

local function UIApplySetting(key, newValue)
    local cfg = Settings[key]
    if not cfg then
        return
    end

    cfg.Value = newValue

    if key == "Chams" then
        for _, player in ipairs(GetPlayers()) do
            pcall(function()
                if cfg.Value then
                    Chams.Apply(player)
                else
                    Chams.Remove(player)
                end
            end)
        end

    elseif key == "FullBright" then
        pcall(function()
            if cfg.Value then
                FB.On()
            else
                FB.Off()
            end
        end)

    elseif key == "FOVChanger" then
        local camera = GetCamera()
        if camera then
            pcall(function()
                camera.FieldOfView =
                    cfg.Value and (S("CustomFOV") or 90) or 70
            end)
        end

    elseif key == "CustomFOV" then
        if S("FOVChanger") then
            local camera = GetCamera()
            if camera then
                pcall(function()
                    camera.FieldOfView = cfg.Value
                end)
            end
        end

    elseif key == "ChamStyle" and S("Chams") then
        for _, player in ipairs(GetPlayers()) do
            pcall(function()
                Chams.Apply(player)
            end)
        end
    end
end

local function UIRefreshButton(button, cfg)
    if not button or not cfg then
        return
    end

    button.Text = UISettingValue(cfg)

    if cfg.Type == "toggle" then
        button.BackgroundColor3 = cfg.Value
            and UI_COLORS.Accent
            or UI_COLORS.Off

        button.TextColor3 = cfg.Value
            and Color3.fromRGB(5, 12, 12)
            or UI_COLORS.Text
    end
end

local function UICycleDropdown(cfg)
    if not cfg or not cfg.Options or #cfg.Options == 0 then
        return
    end

    local current = 1

    for index, value in ipairs(cfg.Options) do
        if value == cfg.Value then
            current = index
            break
        end
    end

    UIApplySetting(
        cfg.__Key,
        cfg.Options[(current % #cfg.Options) + 1]
    )
end

local function UISliderValue(cfg, mouseX, absoluteX, trackWidth)
    local minValue = cfg.Min or 0
    local maxValue = cfg.Max or 100

    if maxValue <= minValue then
        maxValue = minValue + 1
    end

    local ratio = math.clamp(
        (mouseX - absoluteX) / math.max(trackWidth, 1),
        0,
        1
    )

    local value = minValue + (maxValue - minValue) * ratio

    if maxValue - minValue >= 10 then
        value = math.floor(value + 0.5)
    else
        value = math.floor(value * 100 + 0.5) / 100
    end

    return value
end

local function UIGetTabs()
    local tabs = {}

    for _, cfg in pairs(Settings) do
        if cfg.Tab and not table.find(tabs, cfg.Tab) then
            table.insert(tabs, cfg.Tab)
        end
    end

    table.sort(tabs)

    -- Keep the original order for readability.
    local preferred = {
        Aimbot = 1,
        ESP = 2,
        Visuals = 3,
        Movement = 4,
        Misc = 5,
    }

    table.sort(tabs, function(a, b)
        return (preferred[a] or 99) < (preferred[b] or 99)
    end)

    return tabs
end

local function UIGetSettings(tabName)
    local list = {}

    for key, cfg in pairs(Settings) do
        if cfg.Tab == tabName then
            cfg.__Key = key
            table.insert(list, {
                Key = key,
                Config = cfg,
            })
        end
    end

    table.sort(list, function(a, b)
        return a.Key < b.Key
    end)

    return list
end

local function UIShow(state)
    NativeUI.Visible = state

    if NativeUI.Main then
        NativeUI.Main.Visible = state
    end

    if NativeUI.Open then
        NativeUI.Open.Visible = not state
    end
end

local function UIClearBody()
    if not NativeUI.Body then
        return
    end

    for _, child in ipairs(NativeUI.Body:GetChildren()) do
        pcall(function()
            child:Destroy()
        end)
    end
end

local function UIRenderTab(tabName)
    NativeUI.ActiveTab = tabName
    UIClearBody()

    if not NativeUI.Body then
        return
    end

    local entries = UIGetSettings(tabName)

    for index, entry in ipairs(entries) do
        local key = entry.Key
        local cfg = entry.Config

        local row = UIMake("Frame", NativeUI.Body, {
            Name = "Row_" .. key,
            BackgroundColor3 =
                (index % 2 == 0)
                and UI_COLORS.RowAlt
                or UI_COLORS.Row,
            BorderSizePixel = 0,
            Size = UDim2.new(1, -8, 0, 42),
        })

        UICorner(row, 6)

        UIMake("TextLabel", row, {
            BackgroundTransparency = 1,
            Position = UDim2.fromOffset(12, 0),
            Size = UDim2.new(0.45, 0, 1, 0),
            Text = key,
            TextColor3 = UI_COLORS.Text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        if cfg.Type == "toggle" then
            local button = UIMake("TextButton", row, {
                BackgroundColor3 =
                    cfg.Value and UI_COLORS.Accent or UI_COLORS.Off,
                BorderSizePixel = 0,
                Position = UDim2.new(1, -92, 0.5, -13),
                Size = UDim2.fromOffset(76, 26),
                Text = UISettingValue(cfg),
                TextColor3 =
                    cfg.Value
                    and Color3.fromRGB(5, 12, 12)
                    or UI_COLORS.Text,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                AutoButtonColor = true,
            })

            UICorner(button, 5)

            UITrack(button.Activated:Connect(function()
                UIApplySetting(key, not cfg.Value)
                UIRefreshButton(button, cfg)
            end))

        elseif cfg.Type == "dropdown" then
            local button = UIMake("TextButton", row, {
                BackgroundColor3 = UI_COLORS.Off,
                BorderSizePixel = 0,
                Position = UDim2.new(1, -168, 0.5, -13),
                Size = UDim2.fromOffset(152, 26),
                Text = tostring(cfg.Value) .. "  ▾",
                TextColor3 = UI_COLORS.Text,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                AutoButtonColor = true,
            })

            UICorner(button, 5)

            UITrack(button.Activated:Connect(function()
                UICycleDropdown(cfg)
                button.Text = tostring(cfg.Value) .. "  ▾"
            end))

        elseif cfg.Type == "slider" then
            local valueLabel = UIMake("TextLabel", row, {
                BackgroundTransparency = 1,
                Position = UDim2.new(1, -58, 0, 4),
                Size = UDim2.fromOffset(50, 18),
                Text = UISettingValue(cfg),
                TextColor3 = UI_COLORS.Accent,
                TextSize = 11,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
            })

            local track = UIMake("TextButton", row, {
                BackgroundColor3 = UI_COLORS.Off,
                BorderSizePixel = 0,
                Position = UDim2.new(0.50, 0, 0.5, -3),
                Size = UDim2.new(0.38, 0, 0, 6),
                Text = "",
                AutoButtonColor = false,
            })

            UICorner(track, 3)

            local fill = UIMake("Frame", track, {
                BackgroundColor3 = UI_COLORS.Accent,
                BorderSizePixel = 0,
                Size = UDim2.new(
                    math.clamp(
                        ((cfg.Value - (cfg.Min or 0)) /
                        math.max((cfg.Max or 100) - (cfg.Min or 0), 1)),
                        0,
                        1
                    ),
                    0,
                    1,
                    0
                ),
                Position = UDim2.fromScale(0, 0),
            })

            UICorner(fill, 3)

            local function SetSlider(mouseX)
                local abs = track.AbsolutePosition.X
                local width = track.AbsoluteSize.X
                local value = UISliderValue(cfg, mouseX, abs, width)

                UIApplySetting(key, value)

                local ratio = math.clamp(
                    (value - (cfg.Min or 0)) /
                    math.max((cfg.Max or 100) - (cfg.Min or 0), 1),
                    0,
                    1
                )

                fill.Size = UDim2.new(ratio, 0, 1, 0)
                valueLabel.Text = UISettingValue(cfg)
            end

            UITrack(track.Activated:Connect(function(input)
                local mousePos = UserInputService:GetMouseLocation()
                SetSlider(mousePos.X)
            end))

            UITrack(track.MouseButton1Down:Connect(function()
                local moveConn
                moveConn = UserInputService.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement then
                        SetSlider(input.Position.X)
                    end
                end)

                local endConn
                endConn = UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 then
                        pcall(function() moveConn:Disconnect() end)
                        pcall(function() endConn:Disconnect() end)
                    end
                end)

                UITrack(moveConn)
                UITrack(endConn)
            end))
        end
    end

    local layout = UIMake("UIListLayout", NativeUI.Body, {
        Padding = UDim.new(0, 5),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })

    local padding = UIMake("UIPadding", NativeUI.Body, {
        PaddingLeft = UDim.new(0, 2),
        PaddingRight = UDim.new(0, 2),
        PaddingTop = UDim.new(0, 2),
        PaddingBottom = UDim.new(0, 6),
    })

    -- Keep references alive in the hierarchy; explicit locals are not needed.
    return layout, padding
end

local function UIRebuildTabs()
    if not NativeUI.TabBar then
        return
    end

    for _, child in ipairs(NativeUI.TabBar:GetChildren()) do
        if not child:IsA("UIListLayout") then
            pcall(function()
                child:Destroy()
            end)
        end
    end

    local tabs = UIGetTabs()

    for _, tabName in ipairs(tabs) do
        local button = UIMake("TextButton", NativeUI.TabBar, {
            BackgroundColor3 =
                tabName == NativeUI.ActiveTab
                and UI_COLORS.RowAlt
                or UI_COLORS.Header,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(74, 28),
            Text = tabName,
            TextColor3 =
                tabName == NativeUI.ActiveTab
                and UI_COLORS.Accent
                or UI_COLORS.Muted,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            AutoButtonColor = true,
        })

        UICorner(button, 5)

        UITrack(button.Activated:Connect(function()
            NativeUI.ActiveTab = tabName
            UIRenderTab(tabName)
            UIRebuildTabs()
        end))
    end

    UIMake("UIListLayout", NativeUI.TabBar, {
        FillDirection = Enum.FillDirection.Horizontal,
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
end

local function UIDestroy()
    UIDisconnect()

    if NativeUI.Gui then
        pcall(function()
            NativeUI.Gui:Destroy()
        end)
    end

    NativeUI.Gui = nil
    NativeUI.Main = nil
    NativeUI.Open = nil
    NativeUI.Body = nil
    NativeUI.TabBar = nil
end

local function UIBuild()
    UIDestroy()

    -- The previous Drawing UI can remain alive and steal visual space.
    pcall(function()
        if Menu then
            Menu.Vis = false
            Menu.ClearDraw()
        end
    end)

    pcall(function()
        if Overlay then
            Overlay.Clear()
        end
    end)

    local parent = UIGetPlayerGui()

    if not parent then
        warn("[0 HUB V9.2] PlayerGui unavailable; UI was not created.")
        return false
    end

    local gui = UIMake("ScreenGui", parent, {
        Name = "ZeroHubV92",
        ResetOnSpawn = false,
        IgnoreGuiInset = false,
        DisplayOrder = 999999,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Enabled = true,
    })

    if not gui then
        return false
    end

    NativeUI.Gui = gui

    local main = UIMake("Frame", gui, {
        Name = "Main",
        Position = UDim2.new(0, 80, 0, 80),
        Size = UDim2.fromOffset(560, 500),
        BackgroundColor3 = UI_COLORS.Background,
        BorderSizePixel = 0,
        Active = true,
        Visible = true,
    })

    if not main then
        UIDestroy()
        return false
    end

    NativeUI.Main = main
    UICorner(main, 9)
    UIStroke(main, UI_COLORS.Accent, 1)

    local header = UIMake("Frame", main, {
        Name = "Header",
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = UI_COLORS.Header,
        BorderSizePixel = 0,
        Active = true,
    })

    UICorner(header, 9)

    UIMake("TextLabel", header, {
        BackgroundTransparency = 1,
        Position = UDim2.fromOffset(14, 0),
        Size = UDim2.new(1, -110, 1, 0),
        Text = "0 HUB v9.2",
        TextColor3 = UI_COLORS.Text,
        TextSize = 15,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    UIMake("TextLabel", header, {
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -180, 0, 0),
        Size = UDim2.fromOffset(75, 42),
        Text = "INSERT",
        TextColor3 = UI_COLORS.Muted,
        TextSize = 9,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local close = UIMake("TextButton", header, {
        BackgroundColor3 = UI_COLORS.Off,
        BorderSizePixel = 0,
        Position = UDim2.new(1, -42, 0.5, -13),
        Size = UDim2.fromOffset(30, 26),
        Text = "×",
        TextColor3 = UI_COLORS.Text,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = true,
    })

    UICorner(close, 5)

    UITrack(close.Activated:Connect(function()
        UIShow(false)
    end))

    -- Drag support.
    UITrack(header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            NativeUI.Dragging = true
            NativeUI.DragStart = input.Position
            NativeUI.MainStart = main.Position
        end
    end))

    UITrack(UserInputService.InputChanged:Connect(function(input)
        if not NativeUI.Dragging then
            return
        end

        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        if not NativeUI.DragStart or not NativeUI.MainStart then
            return
        end

        local delta = input.Position - NativeUI.DragStart

        main.Position = UDim2.new(
            NativeUI.MainStart.X.Scale,
            NativeUI.MainStart.X.Offset + delta.X,
            NativeUI.MainStart.Y.Scale,
            NativeUI.MainStart.Y.Offset + delta.Y
        )
    end))

    UITrack(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            NativeUI.Dragging = false
        end
    end))

    local tabs = UIMake("Frame", main, {
        Position = UDim2.fromOffset(8, 48),
        Size = UDim2.new(1, -16, 0, 30),
        BackgroundTransparency = 1,
    })

    NativeUI.TabBar = tabs

    local body = UIMake("ScrollingFrame", main, {
        Position = UDim2.fromOffset(8, 84),
        Size = UDim2.new(1, -16, 1, -92),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        Active = true,
    })

    NativeUI.Body = body

    -- Reopen button. It is a real TextButton now; no Drawing hit testing.
    local open = UIMake("TextButton", gui, {
        Name = "Reopen",
        Position = UDim2.fromOffset(14, 14),
        Size = UDim2.fromOffset(44, 44),
        BackgroundColor3 = Color3.fromRGB(12, 12, 18),
        BorderSizePixel = 0,
        Text = "☰",
        TextColor3 = UI_COLORS.Accent,
        TextSize = 21,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = true,
        Visible = false,
        Active = true,
        ZIndex = 50,
    })

    NativeUI.Open = open

    UICorner(open, 7)
    UIStroke(open, UI_COLORS.Accent, 1)

    UITrack(open.Activated:Connect(function()
        UIShow(true)
    end))

    UIRebuildTabs()
    UIRenderTab("Aimbot")
    UIShow(true)

    return true
end

local NativeUIReady = false

task.defer(function()
    local ok, result = xpcall(UIBuild, debug.traceback)

    NativeUIReady = ok and result == true

    if NativeUIReady then
        print("[0 HUB V9.2] Native ScreenGui UI ready.")
    else
        warn("[0 HUB V9.2] Native UI build failed:", tostring(result))
    end
end)

-- ========================================================
-- // V9.2 — GLOBAL UI HOTKEY
-- // The hotkey only controls OUR ScreenGui and never depends
-- // on Menu.Tick(), Drawing, or game-owned character modules.
-- ========================================================

UITrack(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    local key = input.KeyCode

    if key == Enum.KeyCode.Insert
        or key == Enum.KeyCode.F4
        or key == Enum.KeyCode.Home then

        if NativeUIReady then
            UIShow(not NativeUI.Visible)
        end
    end
end))

-- ========================================================
-- // V9.2 — KEEP UI ABOVE GAME UI AFTER RESPAWN
-- ========================================================

UITrack(LocalPlayer.CharacterAdded:Connect(function()
    task.defer(function()
        if NativeUI.Gui then
            pcall(function()
                NativeUI.Gui.ResetOnSpawn = false
                NativeUI.Gui.Enabled = true
            end)
        end
    end)
end))

print("[0 HUB V9.2] UI repair layer installed.")
