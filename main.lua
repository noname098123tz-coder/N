-- ========================================================
-- BIBILABU HUB v6.1 - RIVALS FPS EDITION
-- NIL-HARDENED | CAMERA LIVE-FETCH | EXECUTOR COMPAT
-- ========================================================

-- // SERVICES
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Workspace        = workspace
local LocalPlayer      = Players.LocalPlayer

-- // CAMERA: always fetched live — never cached at load time
local function GetCamera()
    return Workspace.CurrentCamera
end

-- ========================================================
-- // RUNTIME GUARD
-- ========================================================
local Runtime = {
    Version   = "6.1.0",
    Loaded    = false,
    Errors    = 0,
    MaxErrors = 30,
    Conns     = {},
    Dead      = false,
}

local function SafeCall(fn, ...)
    if Runtime.Dead then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        Runtime.Errors = Runtime.Errors + 1
        warn("[BIBILABU v6.1] err#" .. Runtime.Errors .. ": " .. tostring(err))
        if Runtime.Errors >= Runtime.MaxErrors then
            warn("[BIBILABU v6.1] too many errors — killing script")
            Runtime.Dead = true
        end
    end
end

local function Track(conn)
    table.insert(Runtime.Conns, conn)
    return conn
end

-- ========================================================
-- // SETTINGS
-- ========================================================
local Settings = {
    -- Aimbot
    Aimbot           = { Value=false,   Type="toggle",   Tab="Aimbot" },
    SilentAim        = { Value=false,   Type="toggle",   Tab="Aimbot" },
    AimbotFOV        = { Value=150,     Type="slider",   Tab="Aimbot",   Min=20,   Max=500 },
    ShowFOV          = { Value=true,    Type="toggle",   Tab="Aimbot" },
    TargetPart       = { Value="Head",  Type="dropdown", Tab="Aimbot",   Options={"Head","UpperTorso","HumanoidRootPart"} },
    Prediction       = { Value=false,   Type="toggle",   Tab="Aimbot" },
    TargetLock       = { Value=false,   Type="toggle",   Tab="Aimbot" },
    AutoTargetSwitch = { Value=true,    Type="toggle",   Tab="Aimbot" },
    AimbotSmooth     = { Value=5,       Type="slider",   Tab="Aimbot",   Min=1,    Max=50 },
    TriggerBot       = { Value=false,   Type="toggle",   Tab="Aimbot" },
    AutoFire         = { Value=false,   Type="toggle",   Tab="Aimbot" },
    AutoFireRate     = { Value=0.08,    Type="slider",   Tab="Aimbot",   Min=0.01, Max=0.5 },
    -- ESP
    ESP              = { Value=false,   Type="toggle",   Tab="ESP" },
    ESPBoxes         = { Value=true,    Type="toggle",   Tab="ESP" },
    ESPNames         = { Value=true,    Type="toggle",   Tab="ESP" },
    ESPDistance      = { Value=true,    Type="toggle",   Tab="ESP" },
    ESPHealth        = { Value=true,    Type="toggle",   Tab="ESP" },
    ESPSkeleton      = { Value=false,   Type="toggle",   Tab="ESP" },
    ESPTracers       = { Value=false,   Type="toggle",   Tab="ESP" },
    ESPTracerOrigin  = { Value="Bottom",Type="dropdown", Tab="ESP",      Options={"Bottom","Center","Top"} },
    ESPMaxDist       = { Value=500,     Type="slider",   Tab="ESP",      Min=50,   Max=2000 },
    Chams            = { Value=false,   Type="toggle",   Tab="ESP" },
    -- Visuals
    FullBright       = { Value=false,   Type="toggle",   Tab="Visuals" },
    -- Movement
    Fly              = { Value=false,   Type="toggle",   Tab="Movement" },
    FlySpeed         = { Value=50,      Type="slider",   Tab="Movement", Min=10,   Max=300 },
    Noclip           = { Value=false,   Type="toggle",   Tab="Movement" },
    SpeedHack        = { Value=false,   Type="toggle",   Tab="Movement" },
    SpeedMult        = { Value=1.5,     Type="slider",   Tab="Movement", Min=1,    Max=10 },
    InfiniteJump     = { Value=false,   Type="toggle",   Tab="Movement" },
    -- Misc
    AntiBan          = { Value=true,    Type="toggle",   Tab="Misc" },
    Notifications    = { Value=true,    Type="toggle",   Tab="Misc" },
}

local function S(k)   return Settings[k] and Settings[k].Value end
local function Set(k,v) if Settings[k] then Settings[k].Value = v end end

-- ========================================================
-- // UTILITY — every single access nil-guarded
-- ========================================================
local Util = {}

function Util.Char(p)
    if not p then return nil end
    local ok, c = pcall(function() return p.Character end)
    return ok and c or nil
end

function Util.Hum(p)
    local c = Util.Char(p)
    if not c then return nil end
    local ok, h = pcall(function() return c:FindFirstChildOfClass("Humanoid") end)
    return ok and h or nil
end

function Util.Root(p)
    local c = Util.Char(p)
    if not c then return nil end
    local ok, r = pcall(function() return c:FindFirstChild("HumanoidRootPart") end)
    return ok and r or nil
end

function Util.Part(p, name)
    local c = Util.Char(p)
    if not c then return nil end
    local ok, part = pcall(function()
        return c:FindFirstChild(name) or c:FindFirstChild("HumanoidRootPart")
    end)
    return ok and part or nil
end

function Util.Alive(p)
    local h = Util.Hum(p)
    if not h then return false end
    local ok, alive = pcall(function() return h.Health > 0 end)
    return ok and alive or false
end

function Util.Dist(a, b)
    if not a or not b then return math.huge end
    local ok, d = pcall(function() return (a - b).Magnitude end)
    return ok and d or math.huge
end

-- Live camera fetch with nil guard
function Util.W2S(pos)
    local cam = GetCamera()
    if not cam then return Vector2.zero, false, 0 end
    local ok, res = pcall(function()
        return cam:WorldToViewportPoint(pos)
    end)
    if not ok or not res then return Vector2.zero, false, 0 end
    return Vector2.new(res.X, res.Y), res.Z > 0, res.Z
end

function Util.LerpC(c1, c2, t)
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end

function Util.HPColor(hp, max)
    local t = math.clamp(hp / math.max(max, 1), 0, 1)
    return Util.LerpC(Color3.fromRGB(220,30,30), Color3.fromRGB(30,220,80), t)
end

-- ========================================================
-- // TARGET SYSTEM
-- ========================================================
local Target = { Current=nil, LastSwitch=0, Cooldown=0.25 }

function Target.Mouse()
    local best, bDist = nil, S("AimbotFOV") or 150
    local ok, mouse = pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Util.Alive(p) then
            local part = Util.Part(p, S("TargetPart") or "Head")
            if part then
                local ok2, pos = pcall(function() return part.Position end)
                if ok2 and pos then
                    local sp, vis = Util.W2S(pos)
                    if vis then
                        local d = (sp - mouse).Magnitude
                        if d < bDist then bDist=d; best=p end
                    end
                end
            end
        end
    end
    return best
end

function Target.Near()
    local best, bDist = nil, math.huge
    local lr = Util.Root(LocalPlayer)
    if not lr then return nil end
    local lOk, lPos = pcall(function() return lr.Position end)
    if not lOk then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Util.Alive(p) then
            local r = Util.Root(p)
            if r then
                local rOk, rPos = pcall(function() return r.Position end)
                if rOk and rPos then
                    local d = Util.Dist(rPos, lPos)
                    if d < bDist then bDist=d; best=p end
                end
            end
        end
    end
    return best
end

function Target.Get()
    if S("TargetLock") and Target.Current and Util.Alive(Target.Current) then
        return Target.Current
    end
    local now = os.clock()
    if S("AutoTargetSwitch") and Target.Current and Util.Alive(Target.Current)
    and (now - Target.LastSwitch) < Target.Cooldown then
        return Target.Current
    end
    local t = Target.Mouse() or Target.Near()
    if t ~= Target.Current then Target.Current=t; Target.LastSwitch=now end
    return t
end

function Target.Clear()
    Target.Current=nil; Target.LastSwitch=0
end

-- ========================================================
-- // PREDICTION
-- ========================================================
local function PredictPos(target)
    if not S("Prediction") then return nil end
    local h    = Util.Hum(target)
    local part = Util.Part(target, S("TargetPart") or "Head")
    local lr   = Util.Root(LocalPlayer)
    if not h or not part or not lr then return nil end
    local ok, res = pcall(function()
        local vel  = h.MoveDirection * h.WalkSpeed
        local dist = Util.Dist(part.Position, lr.Position)
        return part.Position + vel * (dist / 1500)
    end)
    return ok and res or nil
end

-- ========================================================
-- // FOV CIRCLE
-- ========================================================
local FOVCircle = nil
if Drawing then
    pcall(function()
        FOVCircle = Drawing.new("Circle")
        FOVCircle.Thickness    = 1.5
        FOVCircle.Color        = Color3.fromRGB(0,215,155)
        FOVCircle.Filled       = false
        FOVCircle.Transparency = 0.85
        FOVCircle.Visible      = false
    end)
end

local function UpdateFOV()
    if not FOVCircle then return end
    local active = S("ShowFOV") and (S("Aimbot") or S("SilentAim"))
    if active then
        local ok, mp = pcall(function() return UserInputService:GetMouseLocation() end)
        if ok and mp then
            FOVCircle.Position = mp
            FOVCircle.Radius   = S("AimbotFOV") or 150
            FOVCircle.Visible  = true
        end
    else
        FOVCircle.Visible = false
    end
end

-- ========================================================
-- // HOOK SYSTEM
-- ========================================================
local Hooks = { Done=false }

function Hooks.Install()
    if Hooks.Done then return end
    local banPats = {"ban","kick","detect","cheat","verify","admin","anticheat","report","flag"}

    -- Anti-ban namecall filter
    pcall(function()
        if not (getrawmetatable and hookmetamethod and newcclosure and checkcaller and getnamecallmethod) then return end
        local mt    = getrawmetatable(game)
        local oldNC = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() and S("AntiBan") then
                if method == "FireServer" or method == "InvokeServer" then
                    local nm = ""
                    pcall(function() nm = tostring(self.Name or ""):lower() end)
                    for _, pat in ipairs(banPats) do
                        if nm:find(pat) then return nil end
                    end
                end
            end
            return oldNC(self, ...)
        end)
        setreadonly(mt, true)
    end)

    -- Silent aim __index hook
    pcall(function()
        if not hookmetamethod then return end
        hookmetamethod(game, "__index", function(obj, key)
            -- we can't call oldIndex here safely without storing it,
            -- so we skip and let the executor's default handle non-silent paths
            if not (checkcaller and checkcaller()) and S("SilentAim") then
                if key == "Hit" or key == "CFrame" then
                    local t = Target.Get()
                    if t then
                        local part = Util.Part(t, S("TargetPart") or "Head")
                        if part then
                            local ok, pos = pcall(function() return part.Position end)
                            if ok and pos then
                                local pred = PredictPos(t)
                                return CFrame.new(pred or pos)
                            end
                        end
                    end
                end
            end
            -- fallthrough to real value
            return rawget(obj, key)
        end)
    end)

    Hooks.Done = true
end

-- ========================================================
-- // AIMBOT
-- ========================================================
local Aimbot = {}
function Aimbot.Update()
    if not S("Aimbot") then return end
    local cam = GetCamera()
    if not cam then return end
    local t = Target.Get()
    if not t then return end
    local part = Util.Part(t, S("TargetPart") or "Head")
    if not part then return end
    pcall(function()
        local pos   = PredictPos(t) or part.Position
        local alpha = math.clamp((S("AimbotSmooth") or 5) / 100, 0.01, 1)
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
            task.wait(0.04)
            vim:SendMouseButtonEvent(0,0,0,false,nil,0)
        end
    end)
end

function TrigBot.Update()
    local now = os.clock()
    if S("TriggerBot") and (now - TrigBot.LastFire) >= 0.1 then
        local t = Target.Mouse()
        if t then
            local part = Util.Part(t, S("TargetPart") or "Head")
            if part then
                local ok, pos = pcall(function() return part.Position end)
                if ok and pos then
                    local sp, vis = Util.W2S(pos)
                    if vis then
                        local ok2, mp = pcall(function() return UserInputService:GetMouseLocation() end)
                        if ok2 and mp and (sp - mp).Magnitude < (S("AimbotFOV") or 150) * 0.18 then
                            TrigBot.LastFire = now
                            TrigBot.Fire()
                        end
                    end
                end
            end
        end
    end
    if S("AutoFire") and (now - TrigBot.LastAuto) >= (S("AutoFireRate") or 0.08) then
        TrigBot.LastAuto = now
        TrigBot.Fire()
    end
end

-- ========================================================
-- // ESP
-- ========================================================
local ESPSys = { Cache={} }

local SKEL = {
    {"Head","UpperTorso"},
    {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},
    {"LeftUpperArm","LeftLowerArm"},
    {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},
    {"RightUpperArm","RightLowerArm"},
    {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},
    {"LeftUpperLeg","LeftLowerLeg"},
    {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},
    {"RightUpperLeg","RightLowerLeg"},
    {"RightLowerLeg","RightFoot"},
}

local function NewLine()
    if not Drawing then return nil end
    local l = Drawing.new("Line")
    l.Thickness=1; l.Transparency=1; l.Visible=false
    return l
end
local function NewSquare()
    if not Drawing then return nil end
    local s = Drawing.new("Square")
    s.Filled=false; s.Transparency=1; s.Visible=false
    return s
end
local function NewText()
    if not Drawing then return nil end
    local t = Drawing.new("Text")
    t.Size=14; t.Outline=true; t.Transparency=1; t.Visible=false
    return t
end

function ESPSys.Create(uid)
    if ESPSys.Cache[uid] or not Drawing then return end
    local d = {}

    d.BoxOuter = NewSquare(); if d.BoxOuter then d.BoxOuter.Color=Color3.fromRGB(0,0,0); d.BoxOuter.Thickness=3 end
    d.Box      = NewSquare(); if d.Box      then d.Box.Color=Color3.fromRGB(255,60,60);  d.Box.Thickness=1.5 end

    d.Corners = {}
    for i=1,8 do
        local ln = NewLine()
        if ln then ln.Color=Color3.fromRGB(255,255,255); ln.Thickness=2 end
        d.Corners[i] = ln
    end

    d.Name = NewText(); if d.Name then d.Name.Color=Color3.fromRGB(255,255,255); d.Name.Center=true; d.Name.OutlineColor=Color3.fromRGB(0,0,0) end
    d.Dist = NewText(); if d.Dist then d.Dist.Color=Color3.fromRGB(200,200,200); d.Dist.Size=12; d.Dist.Center=true; d.Dist.OutlineColor=Color3.fromRGB(0,0,0) end

    d.HPBg = Drawing.new("Square"); d.HPBg.Filled=true; d.HPBg.Color=Color3.fromRGB(0,0,0); d.HPBg.Transparency=0.6; d.HPBg.Visible=false
    d.HP   = Drawing.new("Square"); d.HP.Filled=true;   d.HP.Color=Color3.fromRGB(80,220,80);   d.HP.Transparency=1;   d.HP.Visible=false

    d.Tracer = NewLine(); if d.Tracer then d.Tracer.Color=Color3.fromRGB(255,60,60); d.Tracer.Transparency=0.85 end

    d.Skel = {}
    for i=1,#SKEL do
        local ln = NewLine()
        if ln then ln.Color=Color3.fromRGB(200,200,255); ln.Transparency=0.75 end
        d.Skel[i] = ln
    end

    ESPSys.Cache[uid] = d
end

local function HideAll(d)
    if not d then return end
    local function hd(o) if o and typeof(o)=="userdata" then pcall(function() o.Visible=false end) end end
    hd(d.BoxOuter); hd(d.Box); hd(d.Name); hd(d.Dist); hd(d.HP); hd(d.HPBg); hd(d.Tracer)
    if d.Corners then for _,c in ipairs(d.Corners) do hd(c) end end
    if d.Skel    then for _,s in ipairs(d.Skel)    do hd(s) end end
end

function ESPSys.Remove(uid)
    local d = ESPSys.Cache[uid]
    if not d then return end
    HideAll(d)
    local function rm(o)
        if o and typeof(o)=="userdata" then pcall(function() o:Remove() end) end
    end
    rm(d.BoxOuter); rm(d.Box); rm(d.Name); rm(d.Dist); rm(d.HP); rm(d.HPBg); rm(d.Tracer)
    if d.Corners then for _,c in ipairs(d.Corners) do rm(c) end end
    if d.Skel    then for _,s in ipairs(d.Skel)    do rm(s) end end
    ESPSys.Cache[uid] = nil
end

local function Corners(d, x, y, w, h)
    local cl = math.min(w,h)*0.22
    local defs = {
        {Vector2.new(x,y),       Vector2.new(x+cl,y)},
        {Vector2.new(x,y),       Vector2.new(x,y+cl)},
        {Vector2.new(x+w,y),     Vector2.new(x+w-cl,y)},
        {Vector2.new(x+w,y),     Vector2.new(x+w,y+cl)},
        {Vector2.new(x,y+h),     Vector2.new(x+cl,y+h)},
        {Vector2.new(x,y+h),     Vector2.new(x,y+h-cl)},
        {Vector2.new(x+w,y+h),   Vector2.new(x+w-cl,y+h)},
        {Vector2.new(x+w,y+h),   Vector2.new(x+w,y+h-cl)},
    }
    for i,def in ipairs(defs) do
        local c = d.Corners[i]
        if c then c.From=def[1]; c.To=def[2]; c.Visible=true end
    end
end

function ESPSys.Update()
    if not Drawing then return end
    local cam = GetCamera()
    local lrOk, localRoot = pcall(function() return Util.Root(LocalPlayer) end)
    if not lrOk then localRoot=nil end
    local lPos = nil
    if localRoot then pcall(function() lPos = localRoot.Position end) end

    local alive = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            alive[player.UserId] = true
            local uid = player.UserId
            ESPSys.Create(uid)
            local d = ESPSys.Cache[uid]
            if not d then goto nextesp end

            if not S("ESP") then HideAll(d); goto nextesp end

            -- all reads wrapped so a single nil doesn't blow the loop
            local isAlive = Util.Alive(player)
            if not isAlive then HideAll(d); goto nextesp end

            local root = Util.Root(player)
            local head = Util.Part(player, "Head")
            if not root or not head then HideAll(d); goto nextesp end

            local rPos, hPos
            local rOk = pcall(function() rPos = root.Position end)
            local hOk = pcall(function() hPos = head.Position end)
            if not rOk or not hOk or not rPos or not hPos then HideAll(d); goto nextesp end

            local dist = lPos and Util.Dist(rPos, lPos) or 0
            if dist > (S("ESPMaxDist") or 500) then HideAll(d); goto nextesp end

            if not cam then HideAll(d); goto nextesp end

            local sr, visR, zR = Util.W2S(rPos)
            local sh, visH     = Util.W2S(hPos)
            if not visR or zR <= 0 then HideAll(d); goto nextesp end

            local height = math.abs(sr.Y - sh.Y) * 2.2
            local width  = height * 0.55
            local bx, by = sr.X - width/2, sr.Y - height*0.85

            -- Box
            if S("ESPBoxes") then
                if d.BoxOuter then d.BoxOuter.Position=Vector2.new(bx-1,by-1); d.BoxOuter.Size=Vector2.new(width+2,height+2); d.BoxOuter.Visible=true end
                if d.Box      then d.Box.Position=Vector2.new(bx,by);          d.Box.Size=Vector2.new(width,height);          d.Box.Visible=true end
                Corners(d,bx,by,width,height)
            else
                if d.BoxOuter then d.BoxOuter.Visible=false end
                if d.Box      then d.Box.Visible=false end
                if d.Corners  then for _,c in ipairs(d.Corners) do if c then c.Visible=false end end end
            end

            -- Name
            if S("ESPNames") and d.Name then
                local ok, dn = pcall(function() return player.DisplayName end)
                d.Name.Text    = ok and dn or player.Name
                d.Name.Position= Vector2.new(bx+width/2, by-18)
                d.Name.Visible = true
            elseif d.Name then d.Name.Visible=false end

            -- Distance
            if S("ESPDistance") and d.Dist then
                d.Dist.Text    = math.floor(dist).."m"
                d.Dist.Position= Vector2.new(bx+width/2, by+height+3)
                d.Dist.Visible = true
            elseif d.Dist then d.Dist.Visible=false end

            -- Health
            if S("ESPHealth") and d.HP and d.HPBg then
                local hum = Util.Hum(player)
                local hp, maxHp = 100, 100
                if hum then
                    pcall(function() hp=hum.Health; maxHp=hum.MaxHealth end)
                end
                local ratio = math.clamp(hp/math.max(maxHp,1),0,1)
                local bW,bH = 4,height
                local bX,bY = bx-bW-3, by
                d.HPBg.Position=Vector2.new(bX,bY); d.HPBg.Size=Vector2.new(bW,bH); d.HPBg.Visible=true
                d.HP.Position  =Vector2.new(bX,bY+bH*(1-ratio)); d.HP.Size=Vector2.new(bW,bH*ratio)
                d.HP.Color     = Util.HPColor(hp,maxHp); d.HP.Visible=true
            elseif d.HP then d.HP.Visible=false; d.HPBg.Visible=false end

            -- Tracer
            if S("ESPTracers") and d.Tracer and cam then
                local ok2,vp = pcall(function() return cam.ViewportSize end)
                if ok2 and vp then
                    local orig = S("ESPTracerOrigin") or "Bottom"
                    local fy = orig=="Top" and 0 or (orig=="Center" and vp.Y/2 or vp.Y)
                    d.Tracer.From=Vector2.new(vp.X/2,fy); d.Tracer.To=Vector2.new(sr.X,sr.Y); d.Tracer.Visible=true
                end
            elseif d.Tracer then d.Tracer.Visible=false end

            -- Skeleton
            if S("ESPSkeleton") then
                local char = Util.Char(player)
                for i,pair in ipairs(SKEL) do
                    local ln = d.Skel[i]
                    if ln and char then
                        local p1ok,p1 = pcall(function() return char:FindFirstChild(pair[1]) end)
                        local p2ok,p2 = pcall(function() return char:FindFirstChild(pair[2]) end)
                        if p1ok and p2ok and p1 and p2 then
                            local s1,v1 = Util.W2S(p1.Position)
                            local s2,v2 = Util.W2S(p2.Position)
                            if v1 and v2 then
                                ln.From=s1; ln.To=s2; ln.Visible=true
                            else ln.Visible=false end
                        else ln.Visible=false end
                    elseif ln then ln.Visible=false end
                end
            else
                if d.Skel then for _,s in ipairs(d.Skel) do if s then s.Visible=false end end end
            end

            ::nextesp::
        end
    end

    -- clean up left players
    for uid in pairs(ESPSys.Cache) do
        if not alive[uid] then
            ESPSys.Remove(uid)
        end
    end
end

-- ========================================================
-- // CHAMS
-- ========================================================
local Chams = { Orig={} }
function Chams.Apply(p)
    local char = Util.Char(p)
    if not char then return end
    Chams.Orig[p.UserId] = Chams.Orig[p.UserId] or {}
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            pcall(function()
                if not Chams.Orig[p.UserId][part] then
                    Chams.Orig[p.UserId][part]={Mat=part.Material,Color=part.Color,Trans=part.Transparency}
                end
                part.Material=Enum.Material.Neon; part.Color=Color3.fromRGB(255,0,80); part.Transparency=0.3
            end)
        end
    end
end
function Chams.Remove(p)
    local saved = p and Chams.Orig[p.UserId]
    if not saved then return end
    for part,orig in pairs(saved) do
        pcall(function()
            if part and part.Parent then
                part.Material=orig.Mat; part.Color=orig.Color; part.Transparency=orig.Trans
            end
        end)
    end
    Chams.Orig[p.UserId]=nil
end
function Chams.Tick()
    for _,p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if S("Chams") then Chams.Apply(p)
            elseif Chams.Orig[p.UserId] then Chams.Remove(p) end
        end
    end
end

-- ========================================================
-- // FULLBRIGHT
-- ========================================================
local FB = { Orig=nil }
function FB.On()
    if not FB.Orig then
        FB.Orig={Brightness=Lighting.Brightness,GlobalShadows=Lighting.GlobalShadows,FogEnd=Lighting.FogEnd,FogStart=Lighting.FogStart}
    end
    Lighting.Brightness=5; Lighting.GlobalShadows=false; Lighting.FogEnd=1e6; Lighting.FogStart=1e6
    for _,v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then
            pcall(function() v.Parent=nil end)
        end
    end
end
function FB.Off()
    if FB.Orig then
        Lighting.Brightness=FB.Orig.Brightness; Lighting.GlobalShadows=FB.Orig.GlobalShadows
        Lighting.FogEnd=FB.Orig.FogEnd; Lighting.FogStart=FB.Orig.FogStart
    end
    FB.Orig=nil
end

-- ========================================================
-- // MOVEMENT
-- ========================================================
local Move = {}

function Move.Fly()
    if not S("Fly") then return end
    local char = Util.Char(LocalPlayer)
    if not char then return end
    local cam = GetCamera()
    if not cam then return end
    pcall(function()
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        hum:ChangeState(Enum.HumanoidStateType.Swimming)
        local dir = Vector3.zero
        local UIS = UserInputService
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=cam.CFrame.LookVector  end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=cam.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space)     then dir+=Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.yAxis end
        hrp.AssemblyLinearVelocity = (dir.Magnitude>0 and dir.Unit or Vector3.zero)*(S("FlySpeed") or 50)
    end)
end

function Move.Noclip()
    if not S("Noclip") then return end
    local char = Util.Char(LocalPlayer)
    if not char then return end
    pcall(function()
        for _,p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide=false end
        end
    end)
end

function Move.Speed()
    local char = Util.Char(LocalPlayer)
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = S("SpeedHack") and (16*(S("SpeedMult") or 1.5)) or 16 end
    end)
end

Track(UserInputService.JumpRequest:Connect(function()
    if not S("InfiniteJump") then return end
    local char = Util.Char(LocalPlayer)
    if not char then return end
    pcall(function()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end)
end))

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
        BG     = Drawing.new("Square"),
        Accent = Drawing.new("Square"),
        Text   = Drawing.new("Text"),
        Born   = now,
        Exp    = now+dur,
    }
    n.BG.Filled=true; n.BG.Color=Color3.fromRGB(16,16,22); n.BG.Transparency=0
    n.Accent.Filled=true; n.Accent.Color=(color or Color3.fromRGB(0,215,155)); n.Accent.Transparency=0
    n.Text.Size=14; n.Text.Color=Color3.fromRGB(240,240,240); n.Text.Outline=true
    n.Text.OutlineColor=Color3.fromRGB(0,0,0)
    n.Text.Text="["..title.."] "..msg
    table.insert(Notif.Q,n)
    if #Notif.Q > Notif.Max then
        local old = table.remove(Notif.Q,1)
        pcall(function() old.BG:Remove(); old.Accent:Remove(); old.Text:Remove() end)
    end
    task.delay(dur,function()
        for i,x in ipairs(Notif.Q) do
            if x==n then table.remove(Notif.Q,i); break end
        end
        task.wait(0.4)
        pcall(function() n.BG:Remove(); n.Accent:Remove(); n.Text:Remove() end)
    end)
end

function Notif.Tick()
    local now=os.clock()
    for i,n in ipairs(Notif.Q) do
        local life=n.Exp-n.Born
        local t=(now-n.Born)/life
        local a = t<0.15 and t/0.15 or (t>0.80 and (1-t)/0.20 or 1)
        a=math.clamp(a,0,1)
        local y=NY+(i-1)*(NH+4)
        pcall(function()
            n.BG.Position=Vector2.new(NX,y);     n.BG.Size=Vector2.new(260,NH);  n.BG.Transparency=a*0.92
            n.Accent.Position=Vector2.new(NX,y);  n.Accent.Size=Vector2.new(3,NH); n.Accent.Transparency=a
            n.Text.Position=Vector2.new(NX+10,y+7); n.Text.Transparency=a
        end)
    end
end

-- ========================================================
-- // PANIC
-- ========================================================
local Panic = { On=false, Saved={} }
function Panic.Toggle()
    if not Panic.On then
        Panic.On=true
        for k,v in pairs(Settings) do
            if v.Type=="toggle" then Panic.Saved[k]=v.Value; v.Value=false end
        end
        Target.Clear()
        if FOVCircle then FOVCircle.Visible=false end
        for _,d in pairs(ESPSys.Cache) do HideAll(d) end
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
    Vis=true, Pos=Vector2.new(80,80), W=240,
    HdrH=30, TabH=24, RowH=26, Pad=10,
    Tabs={"Aimbot","ESP","Visuals","Movement","Misc"},
    ActiveTab="Aimbot",
    Drw={}, Drag=false, DragOff=Vector2.zero,
    Rows={}, ClickCD=0,
}

local AC   = Color3.fromRGB(0,215,155)
local BG1  = Color3.fromRGB(14,14,18)
local BG2  = Color3.fromRGB(22,22,28)
local BG3  = Color3.fromRGB(28,28,36)
local BG4  = Color3.fromRGB(24,24,32)
local TPRI = Color3.fromRGB(235,235,235)
local TSEC = Color3.fromRGB(130,130,145)
local TACT = Color3.fromRGB(0,200,145)
local TIDLE= Color3.fromRGB(75,75,90)

local function MD(class)
    if not Drawing then return nil end
    local ok,o = pcall(function() return Drawing.new(class) end)
    if ok and o then table.insert(Menu.Drw,o); return o end
    return nil
end

function Menu.Build()
    for _,d in ipairs(Menu.Drw) do pcall(function() d:Remove() end) end
    Menu.Drw={}; Menu.Rows={}
    if not Drawing or not Menu.Vis then return end

    local p=Menu.Pos; local W=Menu.W
    local tabW = W/#Menu.Tabs

    local rows={}
    for k,v in pairs(Settings) do
        if v.Tab==Menu.ActiveTab then table.insert(rows,{K=k,C=v}) end
    end
    table.sort(rows,function(a,b) return a.K<b.K end)

    local contentH = #rows*Menu.RowH + 8
    local totalH   = Menu.HdrH + Menu.TabH + contentH

    -- shadow
    local sh=MD("Square"); if sh then sh.Position=Vector2.new(p.X-3,p.Y-3); sh.Size=Vector2.new(W+6,totalH+6); sh.Color=Color3.fromRGB(0,0,0); sh.Filled=true; sh.Transparency=0.35 end
    -- bg
    local bg=MD("Square"); if bg then bg.Position=p; bg.Size=Vector2.new(W,totalH); bg.Color=BG1; bg.Filled=true; bg.Transparency=0.95 end
    -- header
    local hdr=MD("Square"); if hdr then hdr.Position=p; hdr.Size=Vector2.new(W,Menu.HdrH); hdr.Color=BG2; hdr.Filled=true; hdr.Transparency=1 end
    -- accent strip
    local st=MD("Square"); if st then st.Position=p; st.Size=Vector2.new(3,Menu.HdrH); st.Color=AC; st.Filled=true; st.Transparency=1 end
    -- title
    local tl=MD("Text"); if tl then tl.Text="BIBILABU HUB  v6.1"; tl.Position=Vector2.new(p.X+12,p.Y+7); tl.Size=15; tl.Color=TPRI; tl.Outline=true; tl.OutlineColor=Color3.fromRGB(0,0,0) end
    -- close hint
    local ch=MD("Text"); if ch then ch.Text="[INS]"; ch.Position=Vector2.new(p.X+W-38,p.Y+8); ch.Size=12; ch.Color=TSEC; ch.Outline=false end

    -- tab bar bg
    local tbg=MD("Square"); if tbg then tbg.Position=Vector2.new(p.X,p.Y+Menu.HdrH); tbg.Size=Vector2.new(W,Menu.TabH); tbg.Color=BG2; tbg.Filled=true; tbg.Transparency=1 end

    for i,tab in ipairs(Menu.Tabs) do
        local tx=p.X+(i-1)*tabW; local ty=p.Y+Menu.HdrH
        local isActive=tab==Menu.ActiveTab
        local btn=MD("Square"); if btn then btn.Position=Vector2.new(tx,ty); btn.Size=Vector2.new(tabW,Menu.TabH); btn.Color=(isActive and Color3.fromRGB(20,20,26) or BG2); btn.Filled=true; btn.Transparency=1 end
        if isActive then
            local ul=MD("Square"); if ul then ul.Position=Vector2.new(tx+2,ty+Menu.TabH-3); ul.Size=Vector2.new(tabW-4,2); ul.Color=AC; ul.Filled=true; ul.Transparency=1 end
        end
        local tl2=MD("Text"); if tl2 then tl2.Text=tab; tl2.Position=Vector2.new(tx+tabW/2,ty+5); tl2.Size=12; tl2.Center=true; tl2.Color=(isActive and TACT or TIDLE); tl2.Outline=false end
        table.insert(Menu.Rows,{Type="tab",Tab=tab,B={X=tx,Y=ty,W=tabW,H=Menu.TabH}})
    end

    local ry0=p.Y+Menu.HdrH+Menu.TabH+4
    for idx,row in ipairs(rows) do
        local k=row.K; local cfg=row.C
        local ry=ry0+(idx-1)*Menu.RowH
        local alt=idx%2==0
        local rbg=MD("Square"); if rbg then rbg.Position=Vector2.new(p.X+4,ry); rbg.Size=Vector2.new(W-8,Menu.RowH-2); rbg.Color=(alt and BG4 or BG3); rbg.Filled=true; rbg.Transparency=0.82 end
        local lbl=MD("Text"); if lbl then lbl.Text=k; lbl.Position=Vector2.new(p.X+Menu.Pad+4,ry+6); lbl.Size=13; lbl.Color=TPRI; lbl.Outline=true; lbl.OutlineColor=Color3.fromRGB(0,0,0) end

        if cfg.Type=="toggle" then
            local bx2=p.X+W-26; local by2=ry+5; local bs=16
            local tbg2=MD("Square"); if tbg2 then tbg2.Position=Vector2.new(bx2,by2); tbg2.Size=Vector2.new(bs,bs); tbg2.Color=(cfg.Value and AC or Color3.fromRGB(50,50,62)); tbg2.Filled=true; tbg2.Transparency=1 end
            if cfg.Value then
                local chk=MD("Text"); if chk then chk.Text="✓"; chk.Position=Vector2.new(bx2+2,by2+1); chk.Size=13; chk.Color=Color3.fromRGB(0,0,0); chk.Outline=false end
            end
            table.insert(Menu.Rows,{Type="toggle",Key=k,B={X=p.X+4,Y=ry,W=W-8,H=Menu.RowH-2}})

        elseif cfg.Type=="slider" then
            local sx=p.X+W/2; local sw=W/2-16; local sy=ry+Menu.RowH/2
            local min=cfg.Min or 0; local max=cfg.Max or 100
            local ratio=(cfg.Value-min)/(max-min)
            local tr=MD("Line"); if tr then tr.From=Vector2.new(sx,sy); tr.To=Vector2.new(sx+sw,sy); tr.Thickness=3; tr.Color=Color3.fromRGB(50,50,62); tr.Transparency=1 end
            local fl=MD("Line"); if fl then fl.From=Vector2.new(sx,sy); fl.To=Vector2.new(sx+sw*ratio,sy); fl.Thickness=3; fl.Color=AC; fl.Transparency=1 end
            local hnd=MD("Square"); if hnd then hnd.Position=Vector2.new(sx+sw*ratio-4,sy-4); hnd.Size=Vector2.new(8,8); hnd.Color=Color3.fromRGB(255,255,255); hnd.Filled=true; hnd.Transparency=1 end
            local vl=MD("Text"); if vl then vl.Text=tostring(math.floor(cfg.Value*100)/100); vl.Position=Vector2.new(sx-5,ry+6); vl.Size=11; vl.Color=TSEC; vl.Outline=false end
            table.insert(Menu.Rows,{Type="slider",Key=k,SX=sx,SW=sw,B={X=sx,Y=ry,W=sw,H=Menu.RowH-2}})

        elseif cfg.Type=="dropdown" then
            local vt=MD("Text"); if vt then vt.Text=tostring(cfg.Value); vt.Position=Vector2.new(p.X+W-80,ry+6); vt.Size=12; vt.Color=AC; vt.Outline=true; vt.OutlineColor=Color3.fromRGB(0,0,0) end
            local ar=MD("Text"); if ar then ar.Text="▾"; ar.Position=Vector2.new(p.X+W-20,ry+5); ar.Size=13; ar.Color=TSEC; ar.Outline=false end
            table.insert(Menu.Rows,{Type="dropdown",Key=k,B={X=p.X+W-90,Y=ry,W=80,H=Menu.RowH-2}})
        end
    end
end

local function InB(b,m)
    return m.X>=b.X and m.X<=b.X+b.W and m.Y>=b.Y and m.Y<=b.Y+b.H
end

local SDrag={Act=false,Key=nil,Row=nil}

function Menu.Tick()
    if not Menu.Vis then return end
    local ok,mp=pcall(function() return UserInputService:GetMouseLocation() end)
    if not ok then return end
    local ok2,mb=pcall(function() return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) end)
    if not ok2 then return end
    local now=os.clock()

    -- drag header
    local hB={X=Menu.Pos.X,Y=Menu.Pos.Y,W=Menu.W,H=Menu.HdrH}
    if mb then
        if not Menu.Drag and not SDrag.Act and InB(hB,mp) then
            Menu.Drag=true; Menu.DragOff=Menu.Pos-mp
        end
        if Menu.Drag then
            local np=mp+Menu.DragOff
            local cam=GetCamera()
            if cam then
                local ok3,vp=pcall(function() return cam.ViewportSize end)
                if ok3 and vp then
                    np=Vector2.new(math.clamp(np.X,0,vp.X-Menu.W), math.clamp(np.Y,0,vp.Y-60))
                end
            end
            if (np-Menu.Pos).Magnitude>0.5 then Menu.Pos=np; Menu.Build() end
        end
    else Menu.Drag=false end

    -- slider drag
    if SDrag.Act then
        if mb then
            local cfg=Settings[SDrag.Key]; local row=SDrag.Row
            if cfg and row then
                local ratio=math.clamp((mp.X-row.SX)/row.SW,0,1)
                local nv=(cfg.Min or 0)+((cfg.Max or 100)-(cfg.Min or 0))*ratio
                nv=math.floor(nv*100+0.5)/100
                if math.abs(nv-cfg.Value)>0.005 then cfg.Value=nv; Menu.Build() end
            end
        else SDrag.Act=false; SDrag.Key=nil; SDrag.Row=nil end
        return
    end

    -- clicks
    if mb and (now-Menu.ClickCD)>0.15 and not Menu.Drag then
        for _,row in ipairs(Menu.Rows) do
            if InB(row.B,mp) then
                Menu.ClickCD=now
                if row.Type=="tab" then
                    Menu.ActiveTab=row.Tab; Menu.Build()
                elseif row.Type=="toggle" then
                    local cfg=Settings[row.Key]
                    if cfg then
                        cfg.Value=not cfg.Value
                        if row.Key=="Chams" then
                            if cfg.Value then for _,p in ipairs(Players:GetPlayers()) do if p~=LocalPlayer then Chams.Apply(p) end end
                            else for _,p in ipairs(Players:GetPlayers()) do Chams.Remove(p) end end
                        elseif row.Key=="FullBright" then
                            if cfg.Value then FB.On() else FB.Off() end
                        end
                        Menu.Build()
                    end
                elseif row.Type=="slider" then
                    SDrag.Act=true; SDrag.Key=row.Key; SDrag.Row=row
                elseif row.Type=="dropdown" then
                    local cfg=Settings[row.Key]
                    if cfg and cfg.Options then
                        local idx=1
                        for i,o in ipairs(cfg.Options) do if o==cfg.Value then idx=i; break end end
                        cfg.Value=cfg.Options[(idx%#cfg.Options)+1]
                        Menu.Build()
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
Track(UserInputService.InputBegan:Connect(function(input,gp)
    if gp then return end
    if input.KeyCode==Enum.KeyCode.Delete then Panic.Toggle()
    elseif input.KeyCode==Enum.KeyCode.Insert then
        Menu.Vis=not Menu.Vis
        if Menu.Vis then Menu.Build()
        else for _,d in ipairs(Menu.Drw) do pcall(function() d:Remove() end) end; Menu.Drw={} end
    end
end))

Track(Players.PlayerAdded:Connect(function(p)
    task.wait(1)
    if S("Chams") then Chams.Apply(p) end
end))

Track(Players.PlayerRemoving:Connect(function(p)
    ESPSys.Remove(p.UserId)
    Chams.Remove(p)
end))

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    Move.Speed()
end)

-- ========================================================
-- // RENDER LOOP
-- ========================================================
Track(RunService.RenderStepped:Connect(function()
    if Runtime.Dead then return end
    SafeCall(UpdateFOV)
    SafeCall(Aimbot.Update)
    SafeCall(TrigBot.Update)
    SafeCall(ESPSys.Update)
    SafeCall(Notif.Tick)
    if Menu.Vis then SafeCall(Menu.Tick) end
end))

-- ========================================================
-- // HEARTBEAT LOOP
-- ========================================================
Track(RunService.Heartbeat:Connect(function()
    if Runtime.Dead then return end
    SafeCall(Move.Fly)
    SafeCall(Move.Noclip)
    SafeCall(Move.Speed)
    SafeCall(Chams.Tick)
end))

-- ========================================================
-- // INIT
-- ========================================================
SafeCall(function()
    Hooks.Install()
    Menu.Build()
    Runtime.Loaded=true
    Notif.Push("BIBILABU HUB","v6.1 loaded — nil-free, we're live boss man.",4,AC)
end)

print("[BIBILABU HUB v6.1] nil-hardened. live.")
