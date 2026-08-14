-- ========================================================
-- BIBILABU HUB - RIVALS FPS EDITION v4.1
-- FIXED SELF-REFERENCE BUG | ANTI-CRASH | ANTI-BAN
-- ========================================================

-- // SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local Workspace = workspace
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- // SCRIPT ENVIRONMENT
local ScriptEnv = {
    Version = "4.1.0",
    Loaded = false,
    RuntimeErrors = 0,
    LastError = nil,
    MaxErrors = 15
}

-- // ERROR HANDLER
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        ScriptEnv.RuntimeErrors = ScriptEnv.RuntimeErrors + 1
        ScriptEnv.LastError = tostring(result)
        warn("[BIBILABU HUB] Error: ", result)
        if ScriptEnv.RuntimeErrors > ScriptEnv.MaxErrors then
            warn("[BIBILABU HUB] Too many errors, halting...")
            return nil
        end
        return nil
    end
    return result
end

-- // SETTINGS
local Settings = {
    -- Aimbot
    Aimbot = false,
    SilentAim = false,
    RageBot = false,
    AimbotFOV = 150,
    ShowFOV = true,
    TargetPart = "Head",
    Prediction = false,
    TargetLock = false,
    AutoTargetSwitch = true,
    TargetSwitchDelay = 0.3,
    AimbotSmoothness = 5,
    
    -- Triggerbot
    TriggerBot = false,
    TriggerDelay = 0.1,
    AutoFire = false,
    AutoFireRate = 0.08,
    
    -- Visuals
    ESP = false,
    ESPBoxes = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPTracers = false,
    ESPColor = Color3.fromRGB(255, 0, 0),
    ESPFriendColor = Color3.fromRGB(0, 255, 0),
    Chams = false,
    ChamColor = Color3.fromRGB(255, 0, 0),
    ChamTransparency = 0.5,
    FullBright = false,
    
    -- Movement
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
    SpeedHack = false,
    SpeedMultiplier = 1.5,
    InfiniteJump = false,
    JumpPowerMultiplier = 1.2,
    
    -- Security
    AntiBan = true,
    AntiCrash = true,
    ProtectGUI = true,
    PanicMode = false,
    
    -- Performance
    PerformanceMode = false,
    FPSLimit = 60,
    RenderDistance = 1000,
    
    -- Keybinds
    PanicKey = Enum.KeyCode.Delete,
    MinimizeKey = Enum.KeyCode.RightShift,
    
    -- System
    Notifications = true,
    Theme = "Dark",
    FirstLoad = true
}

-- // UTILITY FUNCTIONS
local function GetPlayerCharacter(player)
    return player and player.Character or nil
end

local function GetHumanoid(player)
    local char = GetPlayerCharacter(player)
    if char then
        return char:FindFirstChildOfClass("Humanoid")
    end
    return nil
end

local function GetCharacterPart(player, partName)
    local char = GetPlayerCharacter(player)
    if char then
        if partName == "Head" then
            return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        end
        return char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

local function IsAlive(player)
    local hum = GetHumanoid(player)
    return hum and hum.Health > 0
end

-- // TARGET ACQUISITION - FIXED with forward declaration
local TargetSystem
TargetSystem = {
    CurrentTarget = nil,
    LastSwitchTime = 0,
    
    GetClosestToMouse = function()
        local closest = nil
        local shortestDist = Settings.AimbotFOV
        local mousePos = UserInputService:GetMouseLocation()
        local localChar = LocalPlayer.Character
        if not localChar or not Camera then return nil end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and IsAlive(player) then
                local part = GetCharacterPart(player, Settings.TargetPart)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < shortestDist then
                            shortestDist = dist
                            closest = player
                        end
                    end
                end
            end
        end
        return closest
    end,
    
    GetClosest3D = function()
        local closest = nil
        local shortestDist = math.huge
        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not localRoot then return nil end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and IsAlive(player) then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - localRoot.Position).Magnitude
                    if dist < shortestDist then
                        shortestDist = dist
                        closest = player
                    end
                end
            end
        end
        return closest
    end,
    
    GetBestTarget = function()
        local currentTime = os.clock()
        if Settings.TargetLock and TargetSystem.CurrentTarget and IsAlive(TargetSystem.CurrentTarget) then
            return TargetSystem.CurrentTarget
        end
        
        if Settings.AutoTargetSwitch and (currentTime - TargetSystem.LastSwitchTime < Settings.TargetSwitchDelay) and TargetSystem.CurrentTarget then
            return TargetSystem.CurrentTarget
        end
        
        local target = TargetSystem.GetClosestToMouse() or TargetSystem.GetClosest3D()
        if target ~= TargetSystem.CurrentTarget then
            TargetSystem.CurrentTarget = target
            TargetSystem.LastSwitchTime = currentTime
        end
        return target
    end,
    
    Clear = function()
        TargetSystem.CurrentTarget = nil
        TargetSystem.LastSwitchTime = 0
    end
}

-- // FOV CIRCLE
local FOVCircle
if Drawing then
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1.5
    FOVCircle.Color = Color3.fromRGB(0, 255, 170)
    FOVCircle.Filled = false
    FOVCircle.Transparency = 0.8
    FOVCircle.Visible = false
end

local function UpdateFOVCircle()
    if FOVCircle and Settings.ShowFOV and (Settings.Aimbot or Settings.SilentAim) then
        local mousePos = UserInputService:GetMouseLocation()
        FOVCircle.Position = mousePos
        FOVCircle.Radius = Settings.AimbotFOV
        FOVCircle.Visible = true
    elseif FOVCircle then
        FOVCircle.Visible = false
    end
end

-- // PREDICTION
local function CalculatePrediction(target)
    if not Settings.Prediction then return nil end
    local hum = GetHumanoid(target)
    local part = GetCharacterPart(target, Settings.TargetPart)
    if not hum or not part then return nil end
    
    local velocity = hum.MoveDirection * hum.WalkSpeed
    local distance = (part.Position - (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or part.Position)).Magnitude
    local timeToTarget = distance / 1000 -- typical bullet speed
    return part.Position + velocity * timeToTarget
end

-- // ANTI-CRASH SYSTEM - FIXED forward declaration
local AntiCrash
AntiCrash = {
    Active = Settings.AntiCrash,
    LastCleanup = 0,
    
    SafeWait = function(seconds)
        if seconds > 30 then seconds = 30 end
        task.wait(seconds)
    end,
    
    Cleanup = function()
        local currentTime = os.clock()
        if currentTime - AntiCrash.LastCleanup > 60 then
            AntiCrash.LastCleanup = currentTime
            if collectgarbage then
                collectgarbage("collect")
            end
        end
    end,
    
    Protect = function()
        if not AntiCrash.Active then return end
        game:GetService("RunService").Heartbeat:Connect(function()
            AntiCrash.Cleanup()
        end)
    end
}

-- // ANTI-BAN / HOOKS - FIXED forward declaration
local HookSystem
HookSystem = {
    HooksInstalled = false,
    Install = function()
        if HookSystem.HooksInstalled then return end
        if not getrawmetatable or not hookmetamethod then return end
        
        -- __namecall hook
        pcall(function()
            local mt = getrawmetatable(game)
            local oldNamecall = mt.__namecall
            setreadonly(mt, false)
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if not checkcaller() then
                    if Settings.AntiBan then
                        if method == "FireServer" or method == "InvokeServer" then
                            local remoteName = tostring(self):lower()
                            if remoteName:find("ban") or remoteName:find("kick") or remoteName:find("detect") or remoteName:find("cheat") or remoteName:find("verify") or remoteName:find("admin") then
                                return nil
                            end
                        end
                    end
                end
                return oldNamecall(self, ...)
            end)
            setreadonly(mt, true)
        end)
        
        -- __index hook for silent aim
        pcall(function()
            local oldIndex = hookmetamethod(game, "__index", function(obj, key)
                if not checkcaller() and Settings.SilentAim then
                    if key == "Hit" or key == "CFrame" then
                        local target = TargetSystem.GetBestTarget()
                        if target then
                            local part = GetCharacterPart(target, Settings.TargetPart)
                            if part then
                                if Settings.Prediction then
                                    local predPos = CalculatePrediction(target)
                                    if predPos then
                                        return CFrame.new(predPos)
                                    end
                                end
                                return part.CFrame
                            end
                        end
                    end
                end
                return oldIndex(obj, key)
            end)
        end)
        
        HookSystem.HooksInstalled = true
    end
}

-- // AIMBOT
local AimbotSystem = {
    Update = function()
        if not Settings.Aimbot then return end
        local target = TargetSystem.GetBestTarget()
        if target then
            local part = GetCharacterPart(target, Settings.TargetPart)
            if part and Camera then
                local aimPos = part.Position
                if Settings.Prediction then
                    local predPos = CalculatePrediction(target)
                    if predPos then aimPos = predPos end
                end
                local lookAt = CFrame.lookAt(Camera.CFrame.Position, aimPos)
                Camera.CFrame = Camera.CFrame:Lerp(lookAt, Settings.AimbotSmoothness / 100)
            end
        end
    end
}

-- // TRIGGERBOT & AUTOFIRE - FIXED forward declaration
local TriggerSystem
TriggerSystem = {
    LastTrigger = 0,
    LastAutoFire = 0,
    Update = function()
        if Settings.TriggerBot then
            local mousePos = UserInputService:GetMouseLocation()
            local target = TargetSystem.GetClosestToMouse()
            if target and os.clock() - TriggerSystem.LastTrigger >= Settings.TriggerDelay then
                local part = GetCharacterPart(target, Settings.TargetPart)
                if part and Camera then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < Settings.AimbotFOV * 0.2 then
                            TriggerSystem.LastTrigger = os.clock()
                            if getgenv then
                                local vim = getgenv().VirtualInputManager
                                if vim then
                                    vim:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
                                    task.wait(0.05)
                                    vim:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
                                end
                            end
                        end
                    end
                end
            end
        end
        
        if Settings.AutoFire then
            if os.clock() - TriggerSystem.LastAutoFire >= Settings.AutoFireRate then
                TriggerSystem.LastAutoFire = os.clock()
                if getgenv and getgenv().VirtualInputManager then
                    getgenv().VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
                    task.wait(0.05)
                    getgenv().VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
                end
            end
        end
    end
}

-- // ESP SYSTEM - FIXED forward declaration
local ESPSystem
ESPSystem = {
    Drawings = {},
    Toggle = function()
        for _, drawingList in pairs(ESPSystem.Drawings) do
            for _, drawing in pairs(drawingList) do
                if drawing then drawing.Visible = Settings.ESP end
            end
        end
    end,
    Create = function(player)
        if ESPSystem.Drawings[player.UserId] then return end
        if not Drawing then return end
        ESPSystem.Drawings[player.UserId] = {}
        local drawings = ESPSystem.Drawings[player.UserId]
        if Settings.ESPBoxes then
            drawings.Box = Drawing.new("Square")
            drawings.Box.Thickness = 2
            drawings.Box.Filled = false
            drawings.Box.Color = Settings.ESPColor
            drawings.Box.Visible = false
        end
        if Settings.ESPNames or Settings.ESPDistance or Settings.ESPHealth then
            drawings.Text = Drawing.new("Text")
            drawings.Text.Size = 16
            drawings.Text.Center = true
            drawings.Text.Outline = true
            drawings.Text.Color = Settings.ESPColor
            drawings.Text.Visible = false
        end
        if Settings.ESPTracers then
            drawings.Tracer = Drawing.new("Line")
            drawings.Tracer.Thickness = 1
            drawings.Tracer.Color = Settings.ESPColor
            drawings.Tracer.Visible = false
        end
    end,
    Update = function()
        if not Settings.ESP then
            ESPSystem.Toggle()
            return
        end
        local localPlayer = LocalPlayer
        if not localPlayer or not Camera then return end
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= localPlayer and IsAlive(player) then
                ESPSystem.Create(player)
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local head = player.Character and player.Character:FindFirstChild("Head")
                if root and head and Camera then
                    local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    if onScreen and pos.Z < Settings.RenderDistance then
                        local drawings = ESPSystem.Drawings[player.UserId]
                        if drawings then
                            local boxSize = Vector2.new(2000 / pos.Z, 3000 / pos.Z)
                            if drawings.Box then
                                drawings.Box.Position = Vector2.new(pos.X - boxSize.X/2, pos.Y - boxSize.Y)
                                drawings.Box.Size = boxSize
                                drawings.Box.Visible = true
                            end
                            if drawings.Text then
                                local text = ""
                                if Settings.ESPNames then text = text .. player.Name end
                                if Settings.ESPDistance and localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                    local dist = (root.Position - localPlayer.Character.HumanoidRootPart.Position).Magnitude
                                    text = text .. " [" .. math.floor(dist) .. "m]"
                                end
                                if Settings.ESPHealth then
                                    local hum = GetHumanoid(player)
                                    if hum then text = text .. " [" .. math.floor(hum.Health) .. "%]" end
                                end
                                drawings.Text.Text = text
                                drawings.Text.Position = Vector2.new(pos.X, pos.Y - boxSize.Y - 20)
                                drawings.Text.Visible = true
                            end
                            if drawings.Tracer then
                                local mousePos = UserInputService:GetMouseLocation()
                                drawings.Tracer.From = Vector2.new(mousePos.X, mousePos.Y + 100)
                                drawings.Tracer.To = Vector2.new(pos.X, pos.Y)
                                drawings.Tracer.Visible = true
                            end
                        end
                    else
                        local drawings = ESPSystem.Drawings[player.UserId]
                        if drawings then
                            for _, drawing in pairs(drawings) do
                                if drawing then drawing.Visible = false end
                            end
                        end
                    end
                end
            else
                local drawings = ESPSystem.Drawings[player.UserId]
                if drawings then
                    for _, drawing in pairs(drawings) do
                        if drawing then drawing.Visible = false end
                    end
                end
            end
        end
    end
}

-- // CHAMS SYSTEM
local ChamsSystem = {
    Apply = function()
        if not Settings.Chams then return end
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Material = Enum.Material.ForceField
                        part.Color = Settings.ChamColor
                        part.Transparency = Settings.ChamTransparency
                    end
                end
            end
        end
    end,
    Remove = function()
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                for _, part in pairs(player.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Material = Enum.Material.Plastic
                        part.Color = Color3.new(1, 1, 1)
                        part.Transparency = 0
                    end
                end
            end
        end
    end
}

-- // FULLBRIGHT
local FullbrightSystem = {
    Apply = function()
        Lighting.Brightness = 3
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    end,
    Remove = function()
        Lighting.Brightness = 2
        Lighting.GlobalShadows = true
        Lighting.FogEnd = 10000
        Lighting.FogStart = 0
    end
}

-- // MOVEMENT SYSTEMS
local MovementSystem = {
    FlyUpdate = function()
        if not Settings.Fly or not LocalPlayer.Character then return end
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if not hrp or not hum then return end
        hum:ChangeState(Enum.HumanoidStateType.Swimming)
        local moveVec = Vector3.new(0,0,0)
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveVec += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveVec -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveVec -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveVec += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveVec += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveVec -= Vector3.new(0,1,0) end
        if moveVec.Magnitude > 0 then
            hrp.AssemblyLinearVelocity = moveVec.Unit * Settings.FlySpeed
        else
            hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
        end
    end,
    NoclipUpdate = function()
        if not Settings.Noclip or not LocalPlayer.Character then return end
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end,
    SpeedHackUpdate = function()
        if not Settings.SpeedHack or not LocalPlayer.Character then return end
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = 16 * Settings.SpeedMultiplier
        end
    end,
    InfiniteJumpUpdate = function()
        if not Settings.InfiniteJump or not LocalPlayer.Character then return end
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Landed and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            hum.JumpPower = 50 * Settings.JumpPowerMultiplier
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
}

-- // PANIC SYSTEM - FIXED forward declaration
local PanicSystem
PanicSystem = {
    Active = false,
    SavedSettings = nil,
    Activate = function()
        if PanicSystem.Active then return end
        PanicSystem.Active = true
        PanicSystem.SavedSettings = {}
        for k,v in pairs(Settings) do
            if type(v) == "boolean" then
                PanicSystem.SavedSettings[k] = v
                Settings[k] = false
            end
        end
        TargetSystem.Clear()
        if FOVCircle then FOVCircle.Visible = false end
        for _, drawings in pairs(ESPSystem.Drawings) do
            for _, drawing in pairs(drawings) do
                if drawing then drawing.Visible = false end
            end
        end
        NotificationSystem.Notify("PANIC MODE", "All features disabled!", 5)
    end,
    Deactivate = function()
        if not PanicSystem.Active then return end
        PanicSystem.Active = false
        if PanicSystem.SavedSettings then
            for k,v in pairs(PanicSystem.SavedSettings) do
                Settings[k] = v
            end
        end
        NotificationSystem.Notify("RECOVERY", "Features restored!", 3)
    end
}

-- // NOTIFICATION SYSTEM - FIXED forward declaration
local NotificationSystem
NotificationSystem = {
    Active = {},
    Max = 5,
    Notify = function(title, message, duration)
        if not Settings.Notifications then return end
        if Drawing then
            local notif = Drawing.new("Text")
            notif.Text = title .. ": " .. message
            notif.Size = 16
            notif.Color = Color3.fromRGB(0, 255, 170)
            notif.Outline = true
            notif.Center = false
            notif.Position = Vector2.new(20, 20 + (#NotificationSystem.Active * 30))
            notif.Visible = true
            table.insert(NotificationSystem.Active, {Drawing = notif, Expires = os.clock() + duration})
            
            while #NotificationSystem.Active > NotificationSystem.Max do
                local oldest = table.remove(NotificationSystem.Active, 1)
                if oldest.Drawing then oldest.Drawing:Remove() end
            end
            
            task.delay(duration, function()
                for i, notifObj in pairs(NotificationSystem.Active) do
                    if notifObj.Drawing == notif then
                        notif:Remove()
                        table.remove(NotificationSystem.Active, i)
                        break
                    end
                end
            end)
        end
    end,
    Update = function()
        for i, notif in pairs(NotificationSystem.Active) do
            if notif.Drawing then
                notif.Drawing.Position = Vector2.new(20, 20 + ((i-1) * 30))
                if os.clock() > notif.Expires - 1 then
                    notif.Drawing.Transparency = notif.Expires - os.clock()
                end
            end
        end
    end
}

-- // PERFORMANCE
local PerformanceSystem = {
    Apply = function()
        if Settings.PerformanceMode then
            settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            settings().Rendering.TextureQuality = Enum.TextureQuality.Level01
            settings().Rendering.ShadowQuality = Enum.ShadowQuality.Level01
            settings().Rendering.RenderDistance = Settings.RenderDistance
        end
    end
}

-- // UI CREATION
local function CreateUI()
    local success, Fluent = pcall(function()
        return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    end)
    if not success or not Fluent then
        warn("[BIBILABU HUB] UI failed to load.")
        return
    end
    
    local Window = Fluent:CreateWindow({
        Title = "Bibilabu Hub | Rivals FPS",
        SubTitle = "v" .. ScriptEnv.Version,
        TabWidth = 180,
        Size = UDim2.fromOffset(650, 500),
        Acrylic = true,
        Theme = Settings.Theme,
        MinimizeKey = Settings.MinimizeKey
    })
    
    local Tabs = {
        Combat = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
        Aimbot = Window:AddTab({ Title = "Aimbot", Icon = "target" }),
        Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" }),
        Movement = Window:AddTab({ Title = "Movement", Icon = "move" }),
        Security = Window:AddTab({ Title = "Security", Icon = "shield" }),
        SettingsTab = Window:AddTab({ Title = "Settings", Icon = "settings" })
    }
    
    -- Combat Tab
    Tabs.Combat:AddToggle("TriggerBotToggle", {
        Title = "Trigger Bot",
        Description = "Auto fire when crosshair on enemy",
        Default = false,
        Callback = function(v) Settings.TriggerBot = v end
    })
    Tabs.Combat:AddToggle("AutoFireToggle", {
        Title = "Auto Fire",
        Description = "Continuous fire",
        Default = false,
        Callback = function(v) Settings.AutoFire = v end
    })
    Tabs.Combat:AddSlider("AutoFireRateSlider", {
        Title = "Auto Fire Rate",
        Default = 0.08,
        Min = 0.01,
        Max = 0.5,
        Rounding = 2,
        Callback = function(v) Settings.AutoFireRate = v end
    })
    Tabs.Combat:AddToggle("PredictionToggle", {
        Title = "Prediction",
        Description = "Predict enemy movement",
        Default = false,
        Callback = function(v) Settings.Prediction = v end
    })
    
    -- Aimbot Tab
    Tabs.Aimbot:AddToggle("AimbotToggle", {
        Title = "Enable Aimbot",
        Default = false,
        Callback = function(v) Settings.Aimbot = v end
    })
    Tabs.Aimbot:AddToggle("SilentAimToggle", {
        Title = "Silent Aim",
        Default = false,
        Callback = function(v) Settings.SilentAim = v end
    })
    Tabs.Aimbot:AddToggle("ShowFOVToggle", {
        Title = "Show FOV",
        Default = true,
        Callback = function(v) Settings.ShowFOV = v end
    })
    Tabs.Aimbot:AddSlider("FOVSlider", {
        Title = "Aimbot FOV",
        Default = 150,
        Min = 30,
        Max = 800,
        Rounding = 0,
        Callback = function(v) Settings.AimbotFOV = v end
    })
    Tabs.Aimbot:AddDropdown("TargetPartDropdown", {
        Title = "Target Part",
        Values = {"Head", "Torso", "HumanoidRootPart", "Left Arm", "Right Arm", "Left Leg", "Right Leg"},
        Default = "Head",
        Callback = function(v) Settings.TargetPart = v end
    })
    Tabs.Aimbot:AddToggle("TargetLockToggle", {
        Title = "Target Lock",
        Default = false,
        Callback = function(v) Settings.TargetLock = v end
    })
    Tabs.Aimbot:AddToggle("AutoTargetSwitchToggle", {
        Title = "Auto Target Switch",
        Default = true,
        Callback = function(v) Settings.AutoTargetSwitch = v end
    })
    Tabs.Aimbot:AddSlider("AimbotSmoothness", {
        Title = "Aimbot Smoothness",
        Default = 5,
        Min = 1,
        Max = 50,
        Rounding = 0,
        Callback = function(v) Settings.AimbotSmoothness = v end
    })
    
    -- Visuals Tab
    Tabs.Visuals:AddToggle("ESPToggle", {
        Title = "Enable ESP",
        Default = false,
        Callback = function(v) Settings.ESP = v end
    })
    Tabs.Visuals:AddToggle("ESPBoxesToggle", {
        Title = "ESP Boxes",
        Default = true,
        Callback = function(v) Settings.ESPBoxes = v end
    })
    Tabs.Visuals:AddToggle("ESPNamesToggle", {
        Title = "ESP Names",
        Default = true,
        Callback = function(v) Settings.ESPNames = v end
    })
    Tabs.Visuals:AddToggle("ESPDistanceToggle", {
        Title = "ESP Distance",
        Default = true,
        Callback = function(v) Settings.ESPDistance = v end
    })
    Tabs.Visuals:AddToggle("ESPHealthToggle", {
        Title = "ESP Health",
        Default = true,
        Callback = function(v) Settings.ESPHealth = v end
    })
    Tabs.Visuals:AddToggle("ESPTracersToggle", {
        Title = "ESP Tracers",
        Default = false,
        Callback = function(v) Settings.ESPTracers = v end
    })
    Tabs.Visuals:AddToggle("ChamsToggle", {
        Title = "Chams",
        Default = false,
        Callback = function(v) 
            Settings.Chams = v
            if v then ChamsSystem.Apply() else ChamsSystem.Remove() end
        end
    })
    Tabs.Visuals:AddToggle("FullbrightToggle", {
        Title = "Fullbright",
        Default = false,
        Callback = function(v)
            Settings.FullBright = v
            if v then FullbrightSystem.Apply() else FullbrightSystem.Remove() end
        end
    })
    
    -- Movement Tab
    Tabs.Movement:AddToggle("FlyToggle", {
        Title = "Fly",
        Default = false,
        Callback = function(v) Settings.Fly = v end
    })
    Tabs.Movement:AddSlider("FlySpeedSlider", {
        Title = "Fly Speed",
        Default = 50,
        Min = 10,
        Max = 300,
        Rounding = 0,
        Callback = function(v) Settings.FlySpeed = v end
    })
    Tabs.Movement:AddToggle("NoclipToggle", {
        Title = "Noclip",
        Default = false,
        Callback = function(v) Settings.Noclip = v end
    })
    Tabs.Movement:AddToggle("SpeedHackToggle", {
        Title = "Speed Hack",
        Default = false,
        Callback = function(v) Settings.SpeedHack = v end
    })
    Tabs.Movement:AddSlider("SpeedMultiplierSlider", {
        Title = "Speed Multiplier",
        Default = 1.5,
        Min = 1,
        Max = 5,
        Rounding = 1,
        Callback = function(v) Settings.SpeedMultiplier = v end
    })
    Tabs.Movement:AddToggle("InfiniteJumpToggle", {
        Title = "Infinite Jump",
        Default = false,
        Callback = function(v) Settings.InfiniteJump = v end
    })
    Tabs.Movement:AddSlider("JumpPowerSlider", {
        Title = "Jump Power Multiplier",
        Default = 1.2,
        Min = 0.5,
        Max = 3,
        Rounding = 1,
        Callback = function(v) Settings.JumpPowerMultiplier = v end
    })
    
    -- Security Tab
    Tabs.Security:AddToggle("AntiBanToggle", {
        Title = "Anti-Ban",
        Default = true,
        Callback = function(v) Settings.AntiBan = v end
    })
    Tabs.Security:AddToggle("AntiCrashToggle", {
        Title = "Anti-Crash",
        Default = true,
        Callback = function(v) Settings.AntiCrash = v end
    })
    Tabs.Security:AddButton("PanicButton", {
        Title = "PANIC MODE",
        Description = "Disable all features instantly",
        Callback = function()
            if PanicSystem.Active then PanicSystem.Deactivate() else PanicSystem.Activate() end
        end
    })
    
    -- Settings Tab
    Tabs.SettingsTab:AddToggle("NotificationsToggle", {
        Title = "Notifications",
        Default = true,
        Callback = function(v) Settings.Notifications = v end
    })
    Tabs.SettingsTab:AddToggle("PerformanceModeToggle", {
        Title = "Performance Mode",
        Default = false,
        Callback = function(v) 
            Settings.PerformanceMode = v
            PerformanceSystem.Apply()
        end
    })
    
    NotificationSystem.Notify("Bibilabu Hub", "Loaded successfully!", 3)
end

-- // MAIN LOOPS
RunService.RenderStepped:Connect(function()
    SafeCall(function()
        UpdateFOVCircle()
        AimbotSystem.Update()
        TriggerSystem.Update()
        ESPSystem.Update()
        NotificationSystem.Update()
    end)
end)

RunService.Heartbeat:Connect(function()
    SafeCall(function()
        MovementSystem.FlyUpdate()
        MovementSystem.NoclipUpdate()
        MovementSystem.SpeedHackUpdate()
        MovementSystem.InfiniteJumpUpdate()
    end)
end)

-- // CHARACTER ADDED CLEANUP (removed undefined TaskSystem)
LocalPlayer.CharacterAdded:Connect(function(char)
    if Settings.Noclip then
        task.wait(0.5)
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

-- // KEYBINDS
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Settings.PanicKey then
        if PanicSystem.Active then PanicSystem.Deactivate() else PanicSystem.Activate() end
    end
end)

-- // INITIALIZATION
SafeCall(function()
    AntiCrash.Protect()
    HookSystem.Install()
    CreateUI()
    ScriptEnv.Loaded = true
end)

print("[BIBILABU HUB] Script loaded. Boss man, we're live.")
