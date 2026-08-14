-- ========================================================
-- BIBILABU HUB v6.0 - RIVALS FPS EDITION
-- FULL REWRITE | ADVANCED DRAWING UI | TABBED MENU
-- SMART ESP | HOOK SYSTEM | ANTI-CRASH | ANTI-BAN
-- ========================================================

-- // SERVICES
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local Workspace        = workspace
local Camera           = Workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ========================================================
-- // RUNTIME GUARD
-- ========================================================
local Runtime = {
    Version       = "6.0.0",
    Loaded        = false,
    Errors        = 0,
    MaxErrors     = 25,
    Connections   = {},
    Destroyed     = false,
}

local function SafeCall(fn, ...)
    if Runtime.Destroyed then return end
    local ok, err = pcall(fn, ...)
    if not ok then
        Runtime.Errors = Runtime.Errors + 1
        warn("[BIBILABU v6] Runtime error #" .. Runtime.Errors .. ": " .. tostring(err))
        if Runtime.Errors >= Runtime.MaxErrors then
            warn("[BIBILABU v6] Error threshold hit — shutting down. Go fix your shit.")
            Runtime.Destroyed = true
        end
    end
end

local function TrackConnection(conn)
    table.insert(Runtime.Connections, conn)
    return conn
end

local function CleanupAll()
    Runtime.Destroyed = true
    for _, c in ipairs(Runtime.Connections) do
        if c and c.Connected then c:Disconnect() end
    end
    Runtime.Connections = {}
end

-- ========================================================
-- // SETTINGS (full config table with metadata)
-- ========================================================
local Settings = {
    -- Aimbot
    Aimbot              = { Value = false,  Type = "toggle",  Tab = "Aimbot" },
    SilentAim           = { Value = false,  Type = "toggle",  Tab = "Aimbot" },
    AimbotFOV           = { Value = 150,    Type = "slider",  Tab = "Aimbot",  Min = 20,  Max = 500 },
    ShowFOV             = { Value = true,   Type = "toggle",  Tab = "Aimbot" },
    TargetPart          = { Value = "Head", Type = "dropdown",Tab = "Aimbot",  Options = {"Head","UpperTorso","HumanoidRootPart"} },
    Prediction          = { Value = false,  Type = "toggle",  Tab = "Aimbot" },
    TargetLock          = { Value = false,  Type = "toggle",  Tab = "Aimbot" },
    AutoTargetSwitch    = { Value = true,   Type = "toggle",  Tab = "Aimbot" },
    AimbotSmoothness    = { Value = 5,      Type = "slider",  Tab = "Aimbot",  Min = 1,   Max = 50 },
    TriggerBot          = { Value = false,  Type = "toggle",  Tab = "Aimbot" },
    AutoFire            = { Value = false,  Type = "toggle",  Tab = "Aimbot" },
    AutoFireRate        = { Value = 0.08,   Type = "slider",  Tab = "Aimbot",  Min = 0.01,Max = 0.5 },
    -- ESP
    ESP                 = { Value = false,  Type = "toggle",  Tab = "ESP" },
    ESPBoxes            = { Value = true,   Type = "toggle",  Tab = "ESP" },
    ESPNames            = { Value = true,   Type = "toggle",  Tab = "ESP" },
    ESPDistance         = { Value = true,   Type = "toggle",  Tab = "ESP" },
    ESPHealth           = { Value = true,   Type = "toggle",  Tab = "ESP" },
    ESPSkeleton         = { Value = false,  Type = "toggle",  Tab = "ESP" },
    ESPTracers          = { Value = false,  Type = "toggle",  Tab = "ESP" },
    ESPTracerOrigin     = { Value = "Bottom",Type="dropdown", Tab = "ESP",     Options = {"Bottom","Center","Top"} },
    ESPMaxDistance      = { Value = 500,    Type = "slider",  Tab = "ESP",     Min = 50,  Max = 2000 },
    Chams               = { Value = false,  Type = "toggle",  Tab = "ESP" },
    ChamsColor          = { Value = Color3.fromRGB(255,0,80), Type = "color", Tab = "ESP" },
    -- Visuals
    FullBright          = { Value = false,  Type = "toggle",  Tab = "Visuals" },
    -- Movement
    Fly                 = { Value = false,  Type = "toggle",  Tab = "Movement" },
    FlySpeed            = { Value = 50,     Type = "slider",  Tab = "Movement",Min = 10,  Max = 300 },
    Noclip              = { Value = false,  Type = "toggle",  Tab = "Movement" },
    SpeedHack           = { Value = false,  Type = "toggle",  Tab = "Movement" },
    SpeedMultiplier     = { Value = 1.5,    Type = "slider",  Tab = "Movement",Min = 1,   Max = 10 },
    InfiniteJump        = { Value = false,  Type = "toggle",  Tab = "Movement" },
    -- Misc
    AntiBan             = { Value = true,   Type = "toggle",  Tab = "Misc" },
    AntiCrash           = { Value = true,   Type = "toggle",  Tab = "Misc" },
    Notifications       = { Value = true,   Type = "toggle",  Tab = "Misc" },
    PerformanceMode     = { Value = false,  Type = "toggle",  Tab = "Misc" },
    PanicKey            = { Value = Enum.KeyCode.Delete, Type = "keybind", Tab = "Misc" },
}

local function S(key) return Settings[key] and Settings[key].Value end
local function Set(key, val) if Settings[key] then Settings[key].Value = val end end

-- ========================================================
-- // UTILITY
-- ========================================================
local Util = {}

function Util.GetCharacter(p) return p and p.Character or nil end
function Util.GetHumanoid(p)
    local c = Util.GetCharacter(p)
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end
function Util.GetRoot(p)
    local c = Util.GetCharacter(p)
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end
function Util.GetPart(p, name)
    local c = Util.GetCharacter(p)
    if not c then return nil end
    return c:FindFirstChild(name) or c:FindFirstChild("HumanoidRootPart")
end
function Util.IsAlive(p)
    local h = Util.GetHumanoid(p)
    return h ~= nil and h.Health > 0
end
function Util.Distance(a, b)
    return a and b and (a - b).Magnitude or math.huge
end
function Util.WorldToScreen(pos)
    if not Camera then return Vector2.zero, false, 0 end
    local p, vis = Camera:WorldToViewportPoint(pos)
    return Vector2.new(p.X, p.Y), vis, p.Z
end
function Util.LerpColor(c1, c2, t)
    return Color3.new(
        c1.R + (c2.R - c1.R) * t,
        c1.G + (c2.G - c1.G) * t,
        c1.B + (c2.B - c1.B) * t
    )
end
function Util.HealthColor(hp, maxHp)
    local t = math.clamp(hp / maxHp, 0, 1)
    return Util.LerpColor(Color3.fromRGB(220,30,30), Color3.fromRGB(30,220,80), t)
end

-- ========================================================
-- // DRAWING CACHE — avoids creating/destroying constantly
-- ========================================================
local DrawCache = {}
local DrawPool  = { Free = {} }

local function NewDraw(class)
    if not Drawing then return nil end
    local key = class
    if DrawPool.Free[key] and #DrawPool.Free[key] > 0 then
        local obj = table.remove(DrawPool.Free[key])
        obj.Visible = false
        return obj
    end
    return Drawing.new(class)
end

local function FreeDraw(obj, class)
    if not obj then return end
    obj.Visible = false
    DrawPool.Free[class] = DrawPool.Free[class] or {}
    table.insert(DrawPool.Free[class], obj)
end

-- ========================================================
-- // TARGET SYSTEM
-- ========================================================
local TargetSys = {
    Current         = nil,
    LastSwitch      = 0,
    SwitchCooldown  = 0.25,
}

function TargetSys.ClosestToMouse()
    local best, bestDist = nil, S("AimbotFOV")
    local mouse = UserInputService:GetMouseLocation()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Util.IsAlive(p) then
            local part = Util.GetPart(p, S("TargetPart"))
            if part then
                local sp, vis = Util.WorldToScreen(part.Position)
                if vis then
                    local d = (sp - mouse).Magnitude
                    if d < bestDist then bestDist = d; best = p end
                end
            end
        end
    end
    return best
end

function TargetSys.Closest3D()
    local best, bestDist = nil, math.huge
    local root = Util.GetRoot(LocalPlayer)
    if not root then return nil end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Util.IsAlive(p) then
            local r = Util.GetRoot(p)
            if r then
                local d = Util.Distance(r.Position, root.Position)
                if d < bestDist then bestDist = d; best = p end
            end
        end
    end
    return best
end

function TargetSys.Get()
    if S("TargetLock") and TargetSys.Current and Util.IsAlive(TargetSys.Current) then
        return TargetSys.Current
    end
    local now = os.clock()
    if S("AutoTargetSwitch") and TargetSys.Current
       and Util.IsAlive(TargetSys.Current)
       and (now - TargetSys.LastSwitch) < TargetSys.SwitchCooldown then
        return TargetSys.Current
    end
    local t = TargetSys.ClosestToMouse() or TargetSys.Closest3D()
    if t ~= TargetSys.Current then
        TargetSys.Current   = t
        TargetSys.LastSwitch= now
    end
    return t
end

function TargetSys.Clear()
    TargetSys.Current    = nil
    TargetSys.LastSwitch = 0
end

-- ========================================================
-- // PREDICTION ENGINE
-- ========================================================
local Prediction = {}

function Prediction.Get(target)
    if not S("Prediction") then return nil end
    local hum  = Util.GetHumanoid(target)
    local part = Util.GetPart(target, S("TargetPart"))
    local root = Util.GetRoot(LocalPlayer)
    if not hum or not part or not root then return nil end
    local velocity  = hum.MoveDirection * hum.WalkSpeed
    local dist      = Util.Distance(part.Position, root.Position)
    local travelTime= dist / 1500  -- approx bullet speed
    return part.Position + velocity * travelTime
end

-- ========================================================
-- // FOV INDICATOR
-- ========================================================
local FOVCircle = NewDraw("Circle")
if FOVCircle then
    FOVCircle.Thickness    = 1.5
    FOVCircle.Color        = Color3.fromRGB(0, 220, 160)
    FOVCircle.Filled       = false
    FOVCircle.Transparency = 0.85
    FOVCircle.Visible      = false
end

local function UpdateFOV()
    if not FOVCircle then return end
    local active = S("ShowFOV") and (S("Aimbot") or S("SilentAim"))
    if active then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius   = S("AimbotFOV")
        FOVCircle.Visible  = true
    else
        FOVCircle.Visible  = false
    end
end

-- ========================================================
-- // HOOK SYSTEM (Anti-Ban + Silent Aim)
-- ========================================================
local Hooks = { Installed = false }

function Hooks.Install()
    if Hooks.Installed then return end
    -- Anti-ban remote filter
    pcall(function()
        if not getrawmetatable or not hookmetamethod then return end
        local mt         = getrawmetatable(game)
        local oldNC      = mt.__namecall
        local banPatterns= {"ban","kick","detect","cheat","verify","admin","anticheat","report","flag"}
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() then
                if S("AntiBan") and (method == "FireServer" or method == "InvokeServer") then
                    local name = tostring(self.Name or ""):lower()
                    for _, pat in ipairs(banPatterns) do
                        if name:find(pat) then return nil end
                    end
                end
            end
            return oldNC(self, ...)
        end)
        setreadonly(mt, true)
    end)
    -- Silent Aim index hook
    pcall(function()
        if not hookmetamethod then return end
        local oldIndex = hookmetamethod(game, "__index", function(obj, key)
            if not checkcaller() and S("SilentAim") then
                if key == "Hit" or key == "CFrame" then
                    local t = TargetSys.Get()
                    if t then
                        local part = Util.GetPart(t, S("TargetPart"))
                        if part then
                            local pos = Prediction.Get(t) or part.Position
                            return CFrame.new(pos)
                        end
                    end
                end
            end
            return oldIndex(obj, key)
        end)
    end)
    Hooks.Installed = true
end

-- ========================================================
-- // AIMBOT
-- ========================================================
local Aimbot = {}

function Aimbot.Update()
    if not S("Aimbot") or not Camera then return end
    local t = TargetSys.Get()
    if not t then return end
    local part = Util.GetPart(t, S("TargetPart"))
    if not part then return end
    local pos = Prediction.Get(t) or part.Position
    local alpha = math.clamp(S("AimbotSmoothness") / 100, 0.01, 1)
    Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, pos), alpha)
end

-- ========================================================
-- // TRIGGERBOT / AUTOFIRE
-- ========================================================
local TriggerBot = { LastFire = 0, LastAuto = 0 }

function TriggerBot.Update()
    local now = os.clock()
    if S("TriggerBot") then
        local t = TargetSys.ClosestToMouse()
        if t and (now - TriggerBot.LastFire) >= 0.1 then
            local part = Util.GetPart(t, S("TargetPart"))
            if part then
                local sp, vis = Util.WorldToScreen(part.Position)
                if vis then
                    local mouse = UserInputService:GetMouseLocation()
                    if (sp - mouse).Magnitude < S("AimbotFOV") * 0.18 then
                        TriggerBot.LastFire = now
                        TriggerBot.Fire()
                    end
                end
            end
        end
    end
    if S("AutoFire") and (now - TriggerBot.LastAuto) >= S("AutoFireRate") then
        TriggerBot.LastAuto = now
        TriggerBot.Fire()
    end
end

function TriggerBot.Fire()
    pcall(function()
        local vim = getgenv and getgenv().VirtualInputManager
        if vim then
            vim:SendMouseButtonEvent(0,0,0,true,nil,0)
            task.wait(0.04)
            vim:SendMouseButtonEvent(0,0,0,false,nil,0)
        end
    end)
end

-- ========================================================
-- // ESP SYSTEM — per-player drawing tables, full cleanup
-- ========================================================
local ESPSys = {}
ESPSys.Cache = {}  -- [userId] = { Box, NameText, DistText, HealthBar, HealthBG, Tracer, Skeleton[] }

local SKELETON_JOINTS = {
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

function ESPSys.GetOrCreate(player)
    local uid = player.UserId
    if ESPSys.Cache[uid] then return ESPSys.Cache[uid] end
    if not Drawing then return nil end
    local d = {}

    -- Box (outline + fill)
    d.BoxOutline = Drawing.new("Square")
    d.BoxOutline.Thickness  = 3
    d.BoxOutline.Filled     = false
    d.BoxOutline.Color      = Color3.fromRGB(0,0,0)
    d.BoxOutline.Transparency = 1
    d.BoxOutline.Visible    = false

    d.Box = Drawing.new("Square")
    d.Box.Thickness  = 1.5
    d.Box.Filled     = false
    d.Box.Color      = Color3.fromRGB(255, 60, 60)
    d.Box.Transparency = 1
    d.Box.Visible    = false

    -- Corner brackets overlay
    d.Corners = {}
    for i = 1, 8 do
        local line = Drawing.new("Line")
        line.Thickness = 2
        line.Color     = Color3.fromRGB(255,255,255)
        line.Transparency = 1
        line.Visible   = false
        d.Corners[i]   = line
    end

    -- Name
    d.Name = Drawing.new("Text")
    d.Name.Size   = 14
    d.Name.Center = true
    d.Name.Outline= true
    d.Name.OutlineColor = Color3.fromRGB(0,0,0)
    d.Name.Color  = Color3.fromRGB(255,255,255)
    d.Name.Visible= false
    d.Name.Font   = Drawing.Fonts and Drawing.Fonts.UI or 0

    -- Distance
    d.Dist = Drawing.new("Text")
    d.Dist.Size   = 13
    d.Dist.Center = true
    d.Dist.Outline= true
    d.Dist.OutlineColor = Color3.fromRGB(0,0,0)
    d.Dist.Color  = Color3.fromRGB(200,200,200)
    d.Dist.Visible= false
    d.Dist.Font   = Drawing.Fonts and Drawing.Fonts.UI or 0

    -- Health bar background
    d.HPBg = Drawing.new("Square")
    d.HPBg.Filled  = true
    d.HPBg.Color   = Color3.fromRGB(0,0,0)
    d.HPBg.Transparency = 0.7
    d.HPBg.Visible = false

    -- Health bar fill
    d.HP = Drawing.new("Square")
    d.HP.Filled    = true
    d.HP.Color     = Color3.fromRGB(80,220,80)
    d.HP.Transparency = 1
    d.HP.Visible   = false

    -- Tracer
    d.Tracer = Drawing.new("Line")
    d.Tracer.Thickness   = 1.2
    d.Tracer.Color       = Color3.fromRGB(255,60,60)
    d.Tracer.Transparency= 0.9
    d.Tracer.Visible     = false

    -- Skeleton lines
    d.Skeleton = {}
    for i = 1, #SKELETON_JOINTS do
        local line = Drawing.new("Line")
        line.Thickness   = 1
        line.Color       = Color3.fromRGB(255,255,255)
        line.Transparency= 0.8
        line.Visible     = false
        d.Skeleton[i]    = line
    end

    ESPSys.Cache[uid] = d
    return d
end

function ESPSys.Hide(d)
    if not d then return end
    if d.BoxOutline  then d.BoxOutline.Visible  = false end
    if d.Box         then d.Box.Visible         = false end
    if d.Name        then d.Name.Visible        = false end
    if d.Dist        then d.Dist.Visible        = false end
    if d.HP          then d.HP.Visible          = false end
    if d.HPBg        then d.HPBg.Visible        = false end
    if d.Tracer      then d.Tracer.Visible      = false end
    for _, c in ipairs(d.Corners or {}) do c.Visible = false end
    for _, s in ipairs(d.Skeleton or {}) do s.Visible = false end
end

function ESPSys.Remove(uid)
    local d = ESPSys.Cache[uid]
    if not d then return end
    ESPSys.Hide(d)
    -- Remove all objects properly
    for k, v in pairs(d) do
        if typeof(v) == "userdata" and v.Remove then
            pcall(function() v:Remove() end)
        elseif type(v) == "table" then
            for _, obj in ipairs(v) do
                if typeof(obj) == "userdata" and obj.Remove then
                    pcall(function() obj:Remove() end)
                end
            end
        end
    end
    ESPSys.Cache[uid] = nil
end

function ESPSys.DrawCorners(d, pos, size)
    local x, y = pos.X, pos.Y
    local w, h = size.X, size.Y
    local cl   = math.min(w, h) * 0.25  -- corner length
    local cs = d.Corners
    -- TL horizontal, TL vertical, TR horizontal, TR vertical
    -- BL horizontal, BL vertical, BR horizontal, BR vertical
    local defs = {
        { Vector2.new(x,       y),       Vector2.new(x+cl,   y)       }, -- TL H
        { Vector2.new(x,       y),       Vector2.new(x,      y+cl)    }, -- TL V
        { Vector2.new(x+w,     y),       Vector2.new(x+w-cl, y)       }, -- TR H
        { Vector2.new(x+w,     y),       Vector2.new(x+w,    y+cl)    }, -- TR V
        { Vector2.new(x,       y+h),     Vector2.new(x+cl,   y+h)     }, -- BL H
        { Vector2.new(x,       y+h),     Vector2.new(x,      y+h-cl)  }, -- BL V
        { Vector2.new(x+w,     y+h),     Vector2.new(x+w-cl, y+h)     }, -- BR H
        { Vector2.new(x+w,     y+h),     Vector2.new(x+w,    y+h-cl)  }, -- BR V
    }
    for i, def in ipairs(defs) do
        cs[i].From    = def[1]
        cs[i].To      = def[2]
        cs[i].Visible = true
    end
end

function ESPSys.Update()
    local localRoot = Util.GetRoot(LocalPlayer)
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            ESPSys.Hide(ESPSys.Cache[player.UserId])
        else
            local d = ESPSys.GetOrCreate(player)
            if not d then continue end
            if not S("ESP") or not Util.IsAlive(player) then
                ESPSys.Hide(d)
                continue
            end
            local root = Util.GetRoot(player)
            local head = Util.GetPart(player, "Head")
            if not root or not head then ESPSys.Hide(d) continue end
            local distVal = localRoot and Util.Distance(root.Position, localRoot.Position) or 0
            if distVal > S("ESPMaxDistance") then ESPSys.Hide(d) continue end

            local screenRoot, visRoot, zRoot = Util.WorldToScreen(root.Position)
            local screenHead, visHead       = Util.WorldToScreen(head.Position)
            if not visRoot or zRoot <= 0 then ESPSys.Hide(d) continue end

            -- Box dimensions derived from head-to-root projection
            local height  = math.abs(screenRoot.Y - screenHead.Y) * 2.2
            local width   = height * 0.55
            local bx      = screenRoot.X - width  / 2
            local by      = screenRoot.Y - height * 0.85

            if S("ESPBoxes") then
                d.BoxOutline.Position    = Vector2.new(bx - 1, by - 1)
                d.BoxOutline.Size        = Vector2.new(width + 2, height + 2)
                d.BoxOutline.Visible     = true
                d.Box.Position           = Vector2.new(bx, by)
                d.Box.Size               = Vector2.new(width, height)
                d.Box.Visible            = true
                ESPSys.DrawCorners(d, Vector2.new(bx, by), Vector2.new(width, height))
            else
                d.Box.Visible         = false
                d.BoxOutline.Visible  = false
                for _, c in ipairs(d.Corners) do c.Visible = false end
            end

            -- Name
            if S("ESPNames") then
                d.Name.Text     = player.DisplayName
                d.Name.Position = Vector2.new(bx + width/2, by - 18)
                d.Name.Visible  = true
            else
                d.Name.Visible  = false
            end

            -- Distance
            if S("ESPDistance") then
                d.Dist.Text     = math.floor(distVal) .. "m"
                d.Dist.Position = Vector2.new(bx + width/2, by + height + 3)
                d.Dist.Visible  = true
            else
                d.Dist.Visible  = false
            end

            -- Health bar (left side)
            if S("ESPHealth") then
                local hum    = Util.GetHumanoid(player)
                local hp     = hum and hum.Health    or 0
                local maxHp  = hum and hum.MaxHealth or 100
                local ratio  = math.clamp(hp / maxHp, 0, 1)
                local barH   = height
                local barW   = 4
                local barX   = bx - barW - 3
                local barY   = by
                d.HPBg.Position  = Vector2.new(barX, barY)
                d.HPBg.Size      = Vector2.new(barW, barH)
                d.HPBg.Visible   = true
                d.HP.Position    = Vector2.new(barX, barY + barH * (1 - ratio))
                d.HP.Size        = Vector2.new(barW, barH * ratio)
                d.HP.Color       = Util.HealthColor(hp, maxHp)
                d.HP.Visible     = true
            else
                d.HP.Visible     = false
                d.HPBg.Visible   = false
            end

            -- Tracer
            if S("ESPTracers") then
                local vp     = Camera.ViewportSize
                local origin = S("ESPTracerOrigin")
                local fromY  = origin == "Top" and 0
                           or (origin == "Center" and vp.Y / 2)
                           or vp.Y
                d.Tracer.From    = Vector2.new(vp.X / 2, fromY)
                d.Tracer.To      = Vector2.new(screenRoot.X, screenRoot.Y)
                d.Tracer.Visible = true
            else
                d.Tracer.Visible = false
            end

            -- Skeleton
            if S("ESPSkeleton") then
                local char = player.Character
                for i, pair in ipairs(SKELETON_JOINTS) do
                    local p1 = char and char:FindFirstChild(pair[1])
                    local p2 = char and char:FindFirstChild(pair[2])
                    local line = d.Skeleton[i]
                    if p1 and p2 and line then
                        local s1, v1 = Util.WorldToScreen(p1.Position)
                        local s2, v2 = Util.WorldToScreen(p2.Position)
                        if v1 and v2 then
                            line.From    = s1
                            line.To      = s2
                            line.Visible = true
                        else
                            line.Visible = false
                        end
                    elseif line then
                        line.Visible = false
                    end
                end
            else
                for _, s in ipairs(d.Skeleton) do s.Visible = false end
            end
        end
    end

    -- Clean up drawings for players who left
    for uid, d in pairs(ESPSys.Cache) do
        if not Players:GetPlayerByUserId(uid) then
            ESPSys.Remove(uid)
        end
    end
end

-- ========================================================
-- // CHAMS
-- ========================================================
local Chams = { Applied = {} }

function Chams.Apply(player)
    if not player.Character then return end
    Chams.Applied[player.UserId] = {}
    for _, part in ipairs(player.Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            Chams.Applied[player.UserId][part] = {
                Mat   = part.Material,
                Color = part.Color,
                Trans = part.Transparency,
            }
            part.Material    = Enum.Material.Neon
            part.Color       = S("ChamsColor")
            part.Transparency= 0.3
        end
    end
end

function Chams.Remove(player)
    local saved = Chams.Applied[player and player.UserId]
    if not saved then return end
    for part, orig in pairs(saved) do
        if part and part.Parent then
            part.Material    = orig.Mat
            part.Color       = orig.Color
            part.Transparency= orig.Trans
        end
    end
    Chams.Applied[player.UserId] = nil
end

function Chams.Update()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            if S("Chams") then
                Chams.Apply(p)
            elseif Chams.Applied[p.UserId] then
                Chams.Remove(p)
            end
        end
    end
end

-- ========================================================
-- // FULLBRIGHT
-- ========================================================
local FullBright = { OriginalAtm = nil }

function FullBright.Apply()
    if not FullBright.OriginalAtm then
        FullBright.OriginalAtm = {
            Brightness    = Lighting.Brightness,
            GlobalShadows = Lighting.GlobalShadows,
            FogEnd        = Lighting.FogEnd,
            FogStart      = Lighting.FogStart,
        }
    end
    Lighting.Brightness    = 5
    Lighting.GlobalShadows = false
    Lighting.FogEnd        = 1e6
    Lighting.FogStart      = 1e6
    -- kill atmosphere effects
    for _, v in ipairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") or v:IsA("BlurEffect") or v:IsA("ColorCorrectionEffect") then
            v.Parent = nil
        end
    end
end

function FullBright.Remove()
    local o = FullBright.OriginalAtm
    if o then
        Lighting.Brightness    = o.Brightness
        Lighting.GlobalShadows = o.GlobalShadows
        Lighting.FogEnd        = o.FogEnd
        Lighting.FogStart      = o.FogStart
    end
    FullBright.OriginalAtm = nil
end

-- ========================================================
-- // MOVEMENT
-- ========================================================
local Movement = {}

function Movement.Fly()
    if not S("Fly") or not LocalPlayer.Character then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum:ChangeState(Enum.HumanoidStateType.Swimming)
    local dir = Vector3.zero
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space)      then dir += Vector3.yAxis end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)  then dir -= Vector3.yAxis end
    hrp.AssemblyLinearVelocity = (dir.Magnitude > 0 and dir.Unit or Vector3.zero) * S("FlySpeed")
end

function Movement.Noclip()
    if not S("Noclip") or not LocalPlayer.Character then return end
    for _, p in ipairs(LocalPlayer.Character:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end

function Movement.SpeedHack()
    if not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = S("SpeedHack") and (16 * S("SpeedMultiplier")) or 16
end

-- Infinite jump via state change detection
TrackConnection(UserInputService.JumpRequest:Connect(function()
    if not S("InfiniteJump") or not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

-- ========================================================
-- // NOTIFICATIONS
-- ========================================================
local Notify = { Queue = {}, MaxVisible = 6 }

local NOTIFY_X = 16
local NOTIFY_Y_START = 16
local NOTIFY_H = 28

function Notify.Push(title, msg, duration, color)
    if not S("Notifications") or not Drawing then return end
    local now = os.clock()
    duration  = duration or 3.5

    local obj = {
        BG      = Drawing.new("Square"),
        Accent  = Drawing.new("Square"),
        Text    = Drawing.new("Text"),
        Born    = now,
        Expires = now + duration,
        Alpha   = 0,
    }

    obj.BG.Filled       = true
    obj.BG.Color        = Color3.fromRGB(20, 20, 24)
    obj.BG.Transparency = 0

    obj.Accent.Filled   = true
    obj.Accent.Color    = color or Color3.fromRGB(0, 200, 150)
    obj.Accent.Transparency = 0

    obj.Text.Size       = 14
    obj.Text.Color      = Color3.fromRGB(240,240,240)
    obj.Text.Outline    = true
    obj.Text.OutlineColor = Color3.fromRGB(0,0,0)
    obj.Text.Text       = "[" .. title .. "] " .. msg

    table.insert(Notify.Queue, obj)
    if #Notify.Queue > Notify.MaxVisible then
        local old = table.remove(Notify.Queue, 1)
        old.BG:Remove(); old.Accent:Remove(); old.Text:Remove()
    end

    task.delay(duration, function()
        for i, n in ipairs(Notify.Queue) do
            if n == obj then
                table.remove(Notify.Queue, i)
                task.wait(0.35)
                pcall(function() n.BG:Remove(); n.Accent:Remove(); n.Text:Remove() end)
                break
            end
        end
    end)
end

function Notify.Update()
    local now = os.clock()
    for i, n in ipairs(Notify.Queue) do
        local life    = n.Expires - n.Born
        local elapsed = now - n.Born
        local t       = elapsed / life
        -- fade in first 15%, fade out last 20%
        local alpha = t < 0.15 and (t / 0.15)
                   or t > 0.80 and ((1 - t) / 0.20)
                   or 1
        alpha = math.clamp(alpha, 0, 1)

        local y   = NOTIFY_Y_START + (i - 1) * (NOTIFY_H + 4)
        local w   = 260
        local h   = NOTIFY_H

        n.BG.Position      = Vector2.new(NOTIFY_X, y)
        n.BG.Size          = Vector2.new(w, h)
        n.BG.Transparency  = alpha * 0.92

        n.Accent.Position  = Vector2.new(NOTIFY_X, y)
        n.Accent.Size      = Vector2.new(3, h)
        n.Accent.Transparency = alpha

        n.Text.Position    = Vector2.new(NOTIFY_X + 10, y + 7)
        n.Text.Transparency= alpha
    end
end

-- ========================================================
-- // PANIC SYSTEM
-- ========================================================
local PanicSys = { Active = false, Saved = {} }

function PanicSys.Toggle()
    if not PanicSys.Active then
        PanicSys.Active = true
        for k, v in pairs(Settings) do
            if v.Type == "toggle" then
                PanicSys.Saved[k] = v.Value
                v.Value = false
            end
        end
        TargetSys.Clear()
        if FOVCircle then FOVCircle.Visible = false end
        for _, d in pairs(ESPSys.Cache) do ESPSys.Hide(d) end
        Notify.Push("PANIC", "All features killed", 5, Color3.fromRGB(220,50,50))
    else
        PanicSys.Active = false
        for k, v in pairs(PanicSys.Saved) do
            if Settings[k] then Settings[k].Value = v end
        end
        Notify.Push("RESTORED", "Features back online", 3, Color3.fromRGB(0,200,150))
    end
end

-- ========================================================
-- // DRAWING-BASED UI MENU
-- ========================================================
local Menu = {
    Visible     = true,
    Pos         = Vector2.new(80, 80),
    Width       = 240,
    HeaderH     = 30,
    TabBarH     = 24,
    RowH        = 26,
    PadX        = 10,
    Tabs        = {"Aimbot","ESP","Visuals","Movement","Misc"},
    ActiveTab   = "Aimbot",
    Drawings    = {},
    Dragging    = false,
    DragOff     = Vector2.zero,
    ClickCooldown = 0,
    Rows        = {},
}

local ACCENT    = Color3.fromRGB(0, 215, 155)
local BG_DARK   = Color3.fromRGB(16, 16, 20)
local BG_PANEL  = Color3.fromRGB(24, 24, 30)
local BG_ROW    = Color3.fromRGB(30, 30, 38)
local BG_ROWALT = Color3.fromRGB(26, 26, 34)
local TEXT_PRI  = Color3.fromRGB(240,240,240)
local TEXT_SEC  = Color3.fromRGB(150,150,165)
local TAB_ACTIVE= Color3.fromRGB(0,200,145)
local TAB_IDLE  = Color3.fromRGB(80,80,95)

function Menu.D(class)
    local obj = Drawing.new(class)
    table.insert(Menu.Drawings, obj)
    return obj
end

function Menu.Build()
    -- Clear old
    for _, d in ipairs(Menu.Drawings) do pcall(function() d:Remove() end) end
    Menu.Drawings = {}
    Menu.Rows     = {}
    if not Drawing then return end

    local p      = Menu.Pos
    local W      = Menu.Width
    local tabW   = W / #Menu.Tabs
    local rows   = {}

    -- Count rows in active tab
    for k, v in pairs(Settings) do
        if v.Tab == Menu.ActiveTab then
            table.insert(rows, {Key = k, Cfg = v})
        end
    end
    table.sort(rows, function(a,b) return a.Key < b.Key end)

    local contentH = #rows * Menu.RowH + 8
    local totalH   = Menu.HeaderH + Menu.TabBarH + contentH

    -- Outer shadow
    local shadow = Menu.D("Square")
    shadow.Position    = Vector2.new(p.X - 2, p.Y - 2)
    shadow.Size        = Vector2.new(W + 4, totalH + 4)
    shadow.Color       = Color3.fromRGB(0,0,0)
    shadow.Filled      = true
    shadow.Transparency= 0.4

    -- Main background
    local bg = Menu.D("Square")
    bg.Position    = p
    bg.Size        = Vector2.new(W, totalH)
    bg.Color       = BG_DARK
    bg.Filled      = true
    bg.Transparency= 0.95

    -- Header bar
    local header = Menu.D("Square")
    header.Position    = p
    header.Size        = Vector2.new(W, Menu.HeaderH)
    header.Color       = BG_PANEL
    header.Filled      = true
    header.Transparency= 1

    -- Accent left strip
    local strip = Menu.D("Square")
    strip.Position    = p
    strip.Size        = Vector2.new(3, Menu.HeaderH)
    strip.Color       = ACCENT
    strip.Filled      = true
    strip.Transparency= 1

    -- Title text
    local title = Menu.D("Text")
    title.Text      = "BIBILABU HUB  v6.0"
    title.Position  = Vector2.new(p.X + 12, p.Y + 7)
    title.Size      = 15
    title.Color     = TEXT_PRI
    title.Outline   = true
    title.OutlineColor = Color3.fromRGB(0,0,0)

    -- Close button hint
    local closeHint = Menu.D("Text")
    closeHint.Text     = "[INS]"
    closeHint.Position = Vector2.new(p.X + W - 38, p.Y + 8)
    closeHint.Size     = 12
    closeHint.Color    = TEXT_SEC
    closeHint.Outline  = true
    closeHint.OutlineColor = Color3.fromRGB(0,0,0)

    -- Tab bar background
    local tabBg = Menu.D("Square")
    tabBg.Position    = Vector2.new(p.X, p.Y + Menu.HeaderH)
    tabBg.Size        = Vector2.new(W, Menu.TabBarH)
    tabBg.Color       = BG_PANEL
    tabBg.Filled      = true
    tabBg.Transparency= 1

    -- Tab buttons
    for i, tab in ipairs(Menu.Tabs) do
        local tx   = p.X + (i - 1) * tabW
        local ty   = p.Y + Menu.HeaderH
        local isActive = tab == Menu.ActiveTab

        local tabBtn = Menu.D("Square")
        tabBtn.Position    = Vector2.new(tx, ty)
        tabBtn.Size        = Vector2.new(tabW, Menu.TabBarH)
        tabBtn.Color       = isActive and Color3.fromRGB(22,22,28) or BG_PANEL
        tabBtn.Filled      = true
        tabBtn.Transparency= 1

        if isActive then
            local underline = Menu.D("Square")
            underline.Position    = Vector2.new(tx + 2, ty + Menu.TabBarH - 3)
            underline.Size        = Vector2.new(tabW - 4, 2)
            underline.Color       = ACCENT
            underline.Filled      = true
            underline.Transparency= 1
        end

        local tabLabel = Menu.D("Text")
        tabLabel.Text      = tab
        tabLabel.Position  = Vector2.new(tx + tabW/2, ty + 5)
        tabLabel.Size      = 12
        tabLabel.Center    = true
        tabLabel.Color     = isActive and TAB_ACTIVE or TAB_IDLE
        tabLabel.Outline   = false

        -- Store for click detection
        table.insert(Menu.Rows, {
            Type     = "tab",
            Tab      = tab,
            Bounds   = {X = tx, Y = ty, W = tabW, H = Menu.TabBarH},
        })
    end

    -- Content rows
    local rowY = p.Y + Menu.HeaderH + Menu.TabBarH + 4

    for idx, row in ipairs(rows) do
        local k   = row.Key
        local cfg = row.Cfg
        local ry  = rowY + (idx - 1) * Menu.RowH
        local alt = idx % 2 == 0

        local rowBg = Menu.D("Square")
        rowBg.Position    = Vector2.new(p.X + 4, ry)
        rowBg.Size        = Vector2.new(W - 8, Menu.RowH - 2)
        rowBg.Color       = alt and BG_ROWALT or BG_ROW
        rowBg.Filled      = true
        rowBg.Transparency= 0.85

        local label = Menu.D("Text")
        label.Text     = k
        label.Position = Vector2.new(p.X + Menu.PadX + 4, ry + 6)
        label.Size     = 13
        label.Color    = TEXT_PRI
        label.Outline  = true
        label.OutlineColor = Color3.fromRGB(0,0,0)

        if cfg.Type == "toggle" then
            local boxX = p.X + W - 26
            local boxY = ry + 5
            local boxS = 16

            local toggleBg = Menu.D("Square")
            toggleBg.Position    = Vector2.new(boxX, boxY)
            toggleBg.Size        = Vector2.new(boxS, boxS)
            toggleBg.Color       = cfg.Value and ACCENT or Color3.fromRGB(55,55,65)
            toggleBg.Filled      = true
            toggleBg.Transparency= 1

            if cfg.Value then
                local check = Menu.D("Text")
                check.Text     = "✓"
                check.Position = Vector2.new(boxX + 2, boxY + 1)
                check.Size     = 13
                check.Color    = Color3.fromRGB(0,0,0)
                check.Outline  = false
            end

            table.insert(Menu.Rows, {
                Type   = "toggle",
                Key    = k,
                Bounds = {X = p.X + 4, Y = ry, W = W - 8, H = Menu.RowH - 2},
            })

        elseif cfg.Type == "slider" then
            local sliderX = p.X + W/2
            local sliderW = W/2 - 16
            local sliderY = ry + Menu.RowH/2
            local ratio   = (cfg.Value - cfg.Min) / (cfg.Max - cfg.Min)

            local trackBg = Menu.D("Line")
            trackBg.From  = Vector2.new(sliderX, sliderY)
            trackBg.To    = Vector2.new(sliderX + sliderW, sliderY)
            trackBg.Thickness = 3
            trackBg.Color = Color3.fromRGB(55,55,65)
            trackBg.Transparency = 1

            local fill = Menu.D("Line")
            fill.From  = Vector2.new(sliderX, sliderY)
            fill.To    = Vector2.new(sliderX + sliderW * ratio, sliderY)
            fill.Thickness = 3
            fill.Color = ACCENT
            fill.Transparency = 1

            local handle = Menu.D("Square")
            handle.Position    = Vector2.new(sliderX + sliderW * ratio - 4, sliderY - 4)
            handle.Size        = Vector2.new(8,8)
            handle.Color       = Color3.fromRGB(255,255,255)
            handle.Filled      = true
            handle.Transparency= 1

            local valLabel = Menu.D("Text")
            valLabel.Text     = tostring(math.floor(cfg.Value * 100) / 100)
            valLabel.Position = Vector2.new(sliderX - 5, ry + 6)
            valLabel.Size     = 11
            valLabel.Color    = TEXT_SEC
            valLabel.Outline  = false

            table.insert(Menu.Rows, {
                Type    = "slider",
                Key     = k,
                SliderX = sliderX,
                SliderW = sliderW,
                Bounds  = {X = sliderX, Y = ry, W = sliderW, H = Menu.RowH - 2},
            })

        elseif cfg.Type == "dropdown" then
            local val = Menu.D("Text")
            val.Text     = tostring(cfg.Value)
            val.Position = Vector2.new(p.X + W - 80, ry + 6)
            val.Size     = 12
            val.Color    = ACCENT
            val.Outline  = true
            val.OutlineColor = Color3.fromRGB(0,0,0)

            local arrow = Menu.D("Text")
            arrow.Text     = "▾"
            arrow.Position = Vector2.new(p.X + W - 20, ry + 5)
            arrow.Size     = 13
            arrow.Color    = TEXT_SEC

            table.insert(Menu.Rows, {
                Type   = "dropdown",
                Key    = k,
                Bounds = {X = p.X + W - 90, Y = ry, W = 80, H = Menu.RowH - 2},
            })
        end
    end
end

function Menu.InBounds(b, mp)
    return mp.X >= b.X and mp.X <= b.X + b.W
       and mp.Y >= b.Y and mp.Y <= b.Y + b.H
end

local SliderDrag = { Active = false, Key = nil }

function Menu.Update()
    if not Menu.Visible then return end
    local mp  = UserInputService:GetMouseLocation()
    local mb1 = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
    local now = os.clock()

    -- Header drag
    local headerBounds = {
        X = Menu.Pos.X, Y = Menu.Pos.Y,
        W = Menu.Width, H = Menu.HeaderH
    }
    if mb1 then
        if not Menu.Dragging and not SliderDrag.Active then
            if Menu.InBounds(headerBounds, mp) then
                Menu.Dragging = true
                Menu.DragOff  = Menu.Pos - mp
            end
        end
        if Menu.Dragging then
            local newPos = mp + Menu.DragOff
            -- clamp to viewport
            local vp = Camera.ViewportSize
            newPos = Vector2.new(
                math.clamp(newPos.X, 0, vp.X - Menu.Width),
                math.clamp(newPos.Y, 0, vp.Y - 60)
            )
            if (newPos - Menu.Pos).Magnitude > 0.5 then
                Menu.Pos = newPos
                Menu.Build()
            end
        end
    else
        Menu.Dragging = false
    end

    -- Slider drag
    if SliderDrag.Active then
        if mb1 then
            local cfg  = Settings[SliderDrag.Key]
            local row  = SliderDrag.Row
            if cfg and row then
                local ratio = math.clamp((mp.X - row.SliderX) / row.SliderW, 0, 1)
                local newVal= cfg.Min + (cfg.Max - cfg.Min) * ratio
                -- round to 2 decimal places
                newVal = math.floor(newVal * 100 + 0.5) / 100
                if math.abs(newVal - cfg.Value) > 0.005 then
                    cfg.Value = newVal
                    Menu.Build()
                end
            end
        else
            SliderDrag.Active = false
            SliderDrag.Key    = nil
            SliderDrag.Row    = nil
        end
        return
    end

    -- Click detection
    if mb1 and (now - Menu.ClickCooldown) > 0.15 and not Menu.Dragging then
        for _, row in ipairs(Menu.Rows) do
            if Menu.InBounds(row.Bounds, mp) then
                Menu.ClickCooldown = now
                if row.Type == "tab" then
                    Menu.ActiveTab = row.Tab
                    Menu.Build()
                elseif row.Type == "toggle" then
                    local cfg = Settings[row.Key]
                    if cfg then
                        cfg.Value = not cfg.Value
                        -- Side effects
                        if row.Key == "Chams" then
                            if cfg.Value then
                                for _, p in ipairs(Players:GetPlayers()) do
                                    if p ~= LocalPlayer then Chams.Apply(p) end
                                end
                            else
                                for _, p in ipairs(Players:GetPlayers()) do Chams.Remove(p) end
                            end
                        elseif row.Key == "FullBright" then
                            if cfg.Value then FullBright.Apply() else FullBright.Remove() end
                        end
                        Menu.Build()
                    end
                elseif row.Type == "slider" then
                    SliderDrag.Active = true
                    SliderDrag.Key    = row.Key
                    SliderDrag.Row    = row
                elseif row.Type == "dropdown" then
                    local cfg = Settings[row.Key]
                    if cfg and cfg.Options then
                        local cur  = cfg.Value
                        local opts = cfg.Options
                        local idx  = 1
                        for i, o in ipairs(opts) do
                            if o == cur then idx = i; break end
                        end
                        cfg.Value = opts[(idx % #opts) + 1]
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
TrackConnection(UserInputService.InputBegan:Connect(function(input, gameProc)
    if gameProc then return end
    if input.KeyCode == Enum.KeyCode.Delete then
        PanicSys.Toggle()
    elseif input.KeyCode == Enum.KeyCode.Insert then
        Menu.Visible = not Menu.Visible
        if Menu.Visible then Menu.Build() else
            for _, d in ipairs(Menu.Drawings) do
                pcall(function() d:Remove() end)
            end
            Menu.Drawings = {}
        end
    end
end))

-- Player join/leave hooks
TrackConnection(Players.PlayerAdded:Connect(function(p)
    -- slight delay so character loads
    task.wait(1)
    if S("Chams") then Chams.Apply(p) end
end))
TrackConnection(Players.PlayerRemoving:Connect(function(p)
    ESPSys.Remove(p.UserId)
    Chams.Remove(p)
end))

-- Character respawn hooks (re-apply movement resets)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    Movement.SpeedHack()
end)

-- ========================================================
-- // MAIN RENDER LOOP
-- ========================================================
TrackConnection(RunService.RenderStepped:Connect(function()
    if Runtime.Destroyed then return end
    SafeCall(function()
        UpdateFOV()
        Aimbot.Update()
        TriggerBot.Update()
        ESPSys.Update()
        Notify.Update()
        if Menu.Visible then Menu.Update() end
    end)
end))

-- ========================================================
-- // HEARTBEAT LOOP (physics-based features)
-- ========================================================
TrackConnection(RunService.Heartbeat:Connect(function()
    if Runtime.Destroyed then return end
    SafeCall(function()
        Movement.Fly()
        Movement.Noclip()
        Movement.SpeedHack()
        Chams.Update()
    end)
end))

-- ========================================================
-- // INIT
-- ========================================================
SafeCall(function()
    Hooks.Install()
    Menu.Build()
    Runtime.Loaded = true
    Notify.Push("BIBILABU HUB", "v6.0 loaded — we're live, boss man.", 4, ACCENT)
end)

print("[BIBILABU HUB v6.0] Loaded. Clean. Locked. Ready.")
