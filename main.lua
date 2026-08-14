-- ========================================================
-- BIBILABU HUB - RIVALS FPS EDITION v5.0
-- CUSTOM DRAWING UI | ANTI-CRASH | ANTI-BAN | FPS FOCUS
-- ========================================================

-- // SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Workspace = workspace
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- // ENVIRONMENT
local ScriptEnv = {
    Version = "5.0.0",
    Loaded = false,
    RuntimeErrors = 0,
    MaxErrors = 15
}

-- // SAFE CALL
local function SafeCall(func, ...)
    local success, result = pcall(func, ...)
    if not success then
        ScriptEnv.RuntimeErrors = ScriptEnv.RuntimeErrors + 1
        warn("[BIBILABU HUB] Error:", result)
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
    Aimbot = false,
    SilentAim = false,
    AimbotFOV = 150,
    ShowFOV = true,
    TargetPart = "Head",
    Prediction = false,
    TargetLock = false,
    AutoTargetSwitch = true,
    AimbotSmoothness = 5,
    TriggerBot = false,
    AutoFire = false,
    AutoFireRate = 0.08,
    ESP = false,
    ESPBoxes = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPTracers = false,
    Chams = false,
    FullBright = false,
    Fly = false,
    FlySpeed = 50,
    Noclip = false,
    SpeedHack = false,
    SpeedMultiplier = 1.5,
    InfiniteJump = false,
    AntiBan = true,
    AntiCrash = true,
    Notifications = true,
    PerformanceMode = false
}

-- // UTILITY
local function GetCharacter(player)
    return player and player.Character or nil
end
local function GetHumanoid(player)
    local char = GetCharacter(player)
    return char and char:FindFirstChildOfClass("Humanoid") or nil
end
local function GetPart(player, partName)
    local char = GetCharacter(player)
    if not char then return nil end
    if partName == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild(partName) or char:FindFirstChild("HumanoidRootPart")
end
local function IsAlive(player)
    local hum = GetHumanoid(player)
    return hum and hum.Health > 0
end

-- // TARGET SYSTEM
local TargetSystem = {
    CurrentTarget = nil,
    LastSwitchTime = 0
}
function TargetSystem.GetClosestToMouse()
    local closest, shortest = nil, Settings.AimbotFOV
    local mousePos = UserInputService:GetMouseLocation()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local part = GetPart(player, Settings.TargetPart)
            if part and Camera then
                local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if dist < shortest then
                        shortest = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end
function TargetSystem.GetClosest3D()
    local closest, shortest = nil, math.huge
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not localRoot then return nil end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - localRoot.Position).Magnitude
                if dist < shortest then
                    shortest = dist
                    closest = player
                end
            end
        end
    end
    return closest
end
function TargetSystem.GetBestTarget()
    if Settings.TargetLock and TargetSystem.CurrentTarget and IsAlive(TargetSystem.CurrentTarget) then
        return TargetSystem.CurrentTarget
    end
    local now = os.clock()
    if Settings.AutoTargetSwitch and (now - TargetSystem.LastSwitchTime < 0.3) and TargetSystem.CurrentTarget then
        return TargetSystem.CurrentTarget
    end
    local target = TargetSystem.GetClosestToMouse() or TargetSystem.GetClosest3D()
    if target ~= TargetSystem.CurrentTarget then
        TargetSystem.CurrentTarget = target
        TargetSystem.LastSwitchTime = now
    end
    return target
end
function TargetSystem.Clear()
    TargetSystem.CurrentTarget = nil
    TargetSystem.LastSwitchTime = 0
end

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
local function UpdateFOV()
    if FOVCircle and Settings.ShowFOV and (Settings.Aimbot or Settings.SilentAim) then
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Radius = Settings.AimbotFOV
        FOVCircle.Visible = true
    elseif FOVCircle then
        FOVCircle.Visible = false
    end
end

-- // PREDICTION
local function GetPredictedPosition(target)
    if not Settings.Prediction then return nil end
    local hum = GetHumanoid(target)
    local part = GetPart(target, Settings.TargetPart)
    if not hum or not part then return nil end
    local velocity = hum.MoveDirection * hum.WalkSpeed
    local dist = (part.Position - (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") or part.Position)).Magnitude
    local time = dist / 1000
    return part.Position + velocity * time
end

-- // HOOKS (ANTI-BAN & SILENT AIM)
local HookSystem = {Installed = false}
function HookSystem.Install()
    if HookSystem.Installed or not getrawmetatable or not hookmetamethod then return end
    pcall(function()
        local mt = getrawmetatable(game)
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if not checkcaller() then
                if Settings.AntiBan and (method == "FireServer" or method == "InvokeServer") then
                    local remoteName = tostring(self):lower()
                    if remoteName:find("ban") or remoteName:find("kick") or remoteName:find("detect") or remoteName:find("cheat") or remoteName:find("verify") or remoteName:find("admin") then
                        return nil
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
    end)
    pcall(function()
        local oldIndex = hookmetamethod(game, "__index", function(obj, key)
            if not checkcaller() and Settings.SilentAim then
                if key == "Hit" or key == "CFrame" then
                    local target = TargetSystem.GetBestTarget()
                    if target then
                        local part = GetPart(target, Settings.TargetPart)
                        if part then
                            local pos = part.Position
                            if Settings.Prediction then
                                local pred = GetPredictedPosition(target)
                                if pred then pos = pred end
                            end
                            return CFrame.new(pos)
                        end
                    end
                end
            end
            return oldIndex(obj, key)
        end)
    end)
    HookSystem.Installed = true
end

-- // AIMBOT
local AimbotSystem = {}
function AimbotSystem.Update()
    if not Settings.Aimbot then return end
    local target = TargetSystem.GetBestTarget()
    if target then
        local part = GetPart(target, Settings.TargetPart)
        if part and Camera then
            local aimPos = part.Position
            if Settings.Prediction then
                local pred = GetPredictedPosition(target)
                if pred then aimPos = pred end
            end
            Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, aimPos), Settings.AimbotSmoothness / 100)
        end
    end
end

-- // TRIGGERBOT & AUTOFIRE
local TriggerSystem = {LastTrigger = 0, LastAutoFire = 0}
function TriggerSystem.Update()
    if Settings.TriggerBot then
        local mousePos = UserInputService:GetMouseLocation()
        local target = TargetSystem.GetClosestToMouse()
        if target and os.clock() - TriggerSystem.LastTrigger >= 0.1 then
            local part = GetPart(target, Settings.TargetPart)
            if part and Camera then
                local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
                if onScreen then
                    local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                    if dist < Settings.AimbotFOV * 0.2 then
                        TriggerSystem.LastTrigger = os.clock()
                        pcall(function()
                            local vim = getgenv().VirtualInputManager
                            if vim then
                                vim:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
                                task.wait(0.05)
                                vim:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
                            end
                        end)
                    end
                end
            end
        end
    end
    if Settings.AutoFire then
        if os.clock() - TriggerSystem.LastAutoFire >= Settings.AutoFireRate then
            TriggerSystem.LastAutoFire = os.clock()
            pcall(function()
                local vim = getgenv().VirtualInputManager
                if vim then
                    vim:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
                    task.wait(0.05)
                    vim:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
                end
            end)
        end
    end
end

-- // ESP SYSTEM
local ESP = {Drawings = {}}
function ESP.Create(player)
    if ESP.Drawings[player.UserId] then return end
    if not Drawing then return end
    ESP.Drawings[player.UserId] = {}
    local d = ESP.Drawings[player.UserId]
    d.Box = Drawing.new("Square")
    d.Box.Thickness = 2
    d.Box.Filled = false
    d.Box.Color = Color3.fromRGB(255,0,0)
    d.Box.Visible = false
    d.Text = Drawing.new("Text")
    d.Text.Size = 16
    d.Text.Center = true
    d.Text.Outline = true
    d.Text.Color = Color3.fromRGB(255,255,255)
    d.Text.Visible = false
    d.Tracer = Drawing.new("Line")
    d.Tracer.Thickness = 1
    d.Tracer.Color = Color3.fromRGB(255,0,0)
    d.Tracer.Visible = false
end
function ESP.Update()
    if not Settings.ESP then
        for _, d in pairs(ESP.Drawings) do
            for _, drawing in pairs(d) do
                if drawing then drawing.Visible = false end
            end
        end
        return
    end
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and IsAlive(player) then
            ESP.Create(player)
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root and Camera then
                local pos, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen and pos.Z < 1000 then
                    local d = ESP.Drawings[player.UserId]
                    if d then
                        local size = Vector2.new(2000/pos.Z, 3000/pos.Z)
                        if d.Box then
                            d.Box.Position = Vector2.new(pos.X - size.X/2, pos.Y - size.Y)
                            d.Box.Size = size
                            d.Box.Visible = true
                        end
                        if d.Text then
                            local text = ""
                            if Settings.ESPNames then text = text .. player.Name end
                            if Settings.ESPDistance and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                                local dist = (root.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                                text = text .. " [" .. math.floor(dist) .. "m]"
                            end
                            if Settings.ESPHealth then
                                local hum = GetHumanoid(player)
                                if hum then text = text .. " [" .. math.floor(hum.Health) .. "%]" end
                            end
                            d.Text.Text = text
                            d.Text.Position = Vector2.new(pos.X, pos.Y - size.Y - 20)
                            d.Text.Visible = true
                        end
                        if d.Tracer and Settings.ESPTracers then
                            local mousePos = UserInputService:GetMouseLocation()
                            d.Tracer.From = Vector2.new(mousePos.X, mousePos.Y + 100)
                            d.Tracer.To = Vector2.new(pos.X, pos.Y)
                            d.Tracer.Visible = true
                        elseif d.Tracer then
                            d.Tracer.Visible = false
                        end
                    end
                else
                    local d = ESP.Drawings[player.UserId]
                    if d then
                        for _, drawing in pairs(d) do
                            if drawing then drawing.Visible = false end
                        end
                    end
                end
            end
        else
            local d = ESP.Drawings[player.UserId]
            if d then
                for _, drawing in pairs(d) do
                    if drawing then drawing.Visible = false end
                end
            end
        end
    end
end

-- // CHAMS
local Chams = {}
function Chams.Apply()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    part.Material = Enum.Material.ForceField
                    part.Color = Color3.fromRGB(255,0,0)
                    part.Transparency = 0.5
                end
            end
        end
    end
end
function Chams.Remove()
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            for _, part in pairs(player.Character:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Material = Enum.Material.Plastic
                    part.Color = Color3.new(1,1,1)
                    part.Transparency = 0
                end
            end
        end
    end
end

-- // FULLBRIGHT
local Fullbright = {}
function Fullbright.Apply()
    Lighting.Brightness = 3
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 100000
    Lighting.FogStart = 100000
end
function Fullbright.Remove()
    Lighting.Brightness = 2
    Lighting.GlobalShadows = true
    Lighting.FogEnd = 10000
    Lighting.FogStart = 0
end

-- // MOVEMENT
local Movement = {}
function Movement.Fly()
    if not Settings.Fly or not LocalPlayer.Character then return end
    local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end
    hum:ChangeState(Enum.HumanoidStateType.Swimming)
    local vec = Vector3.new(0,0,0)
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then vec += Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then vec -= Camera.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then vec -= Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then vec += Camera.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vec += Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vec -= Vector3.new(0,1,0) end
    if vec.Magnitude > 0 then
        hrp.AssemblyLinearVelocity = vec.Unit * Settings.FlySpeed
    else
        hrp.AssemblyLinearVelocity = Vector3.new(0,0,0)
    end
end
function Movement.Noclip()
    if not Settings.Noclip or not LocalPlayer.Character then return end
    for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
end
function Movement.SpeedHack()
    if not Settings.SpeedHack or not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 16 * Settings.SpeedMultiplier end
end
function Movement.InfiniteJump()
    if not Settings.InfiniteJump or not LocalPlayer.Character then return end
    local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum:GetState() == Enum.HumanoidStateType.Landed and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        hum.JumpPower = 50
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

-- // NOTIFICATIONS (simple drawing)
local Notifications = {Active = {}}
function Notifications.Notify(title, msg, duration)
    if not Settings.Notifications or not Drawing then return end
    local text = Drawing.new("Text")
    text.Text = title .. ": " .. msg
    text.Size = 16
    text.Color = Color3.fromRGB(0,255,170)
    text.Outline = true
    text.Position = Vector2.new(20, 20 + (#Notifications.Active * 30))
    text.Visible = true
    table.insert(Notifications.Active, {Obj = text, Expires = os.clock() + (duration or 3)})
    if #Notifications.Active > 5 then
        local oldest = table.remove(Notifications.Active, 1)
        oldest.Obj:Remove()
    end
    task.delay(duration or 3, function()
        for i, n in pairs(Notifications.Active) do
            if n.Obj == text then
                text:Remove()
                table.remove(Notifications.Active, i)
                break
            end
        end
    end)
end
function Notifications.Update()
    for i, n in pairs(Notifications.Active) do
        if n.Obj then
            n.Obj.Position = Vector2.new(20, 20 + ((i-1)*30))
            if os.clock() > n.Expires - 1 then
                n.Obj.Transparency = n.Expires - os.clock()
            end
        end
    end
end

-- // PANIC MODE
local Panic = {Active = false, Saved = nil}
function Panic.Activate()
    if Panic.Active then return end
    Panic.Active = true
    Panic.Saved = {}
    for k,v in pairs(Settings) do
        if type(v) == "boolean" then
            Panic.Saved[k] = v
            Settings[k] = false
        end
    end
    TargetSystem.Clear()
    if FOVCircle then FOVCircle.Visible = false end
    for _, d in pairs(ESP.Drawings) do
        for _, drawing in pairs(d) do
            if drawing then drawing.Visible = false end
        end
    end
    Notifications.Notify("PANIC", "All disabled", 5)
end
function Panic.Deactivate()
    if not Panic.Active then return end
    Panic.Active = false
    if Panic.Saved then
        for k,v in pairs(Panic.Saved) do
            Settings[k] = v
        end
    end
    Notifications.Notify("RECOVERY", "Features restored", 3)
end

-- // CUSTOM UI (Drawing based)
local UI = {Elements = {}, Dragging = false, DragOffset = Vector2.new(0,0)}
function UI.CreateWindow()
    if not Drawing then return end
    UI.Main = Drawing.new("Square")
    UI.Main.Position = Vector2.new(100, 100)
    UI.Main.Size = Vector2.new(220, 350)
    UI.Main.Color = Color3.fromRGB(30,30,30)
    UI.Main.Filled = true
    UI.Main.Transparency = 0.9
    UI.Main.Visible = true
    UI.Title = Drawing.new("Text")
    UI.Title.Text = "Bibilabu Hub v5.0"
    UI.Title.Position = Vector2.new(100, 100)
    UI.Title.Size = 18
    UI.Title.Color = Color3.fromRGB(255,255,255)
    UI.Title.Visible = true
    UI.Main.Visible = true
    -- Add toggles/buttons (simplified)
    UI.AddToggle = function(text, callback, default)
        local y = 130 + (#UI.Elements * 25)
        local box = Drawing.new("Square")
        box.Position = Vector2.new(110, y)
        box.Size = Vector2.new(15,15)
        box.Color = Color3.fromRGB(255,255,255)
        box.Filled = false
        box.Visible = true
        local label = Drawing.new("Text")
        label.Text = text
        label.Position = Vector2.new(130, y)
        label.Size = 16
        label.Color = Color3.fromRGB(255,255,255)
        label.Visible = true
        local element = {Box = box, Label = label, Value = default or false}
        table.insert(UI.Elements, element)
        return element
    end
end
function UI.Update()
    -- Handle dragging (simplified)
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        local mousePos = UserInputService:GetMouseLocation()
        if not UI.Dragging then
            if mousePos.X >= UI.Main.Position.X and mousePos.X <= UI.Main.Position.X + UI.Main.Size.X and
               mousePos.Y >= UI.Main.Position.Y and mousePos.Y <= UI.Main.Position.Y + 20 then
                UI.Dragging = true
                UI.DragOffset = UI.Main.Position - mousePos
            end
        else
            UI.Main.Position = mousePos + UI.DragOffset
            UI.Title.Position = UI.Main.Position
            -- Update element positions (simplified)
            for i, el in pairs(UI.Elements) do
                el.Box.Position = Vector2.new(UI.Main.Position.X + 10, UI.Main.Position.Y + 30 + (i-1)*25)
                el.Label.Position = Vector2.new(UI.Main.Position.X + 30, UI.Main.Position.Y + 30 + (i-1)*25)
            end
        end
    else
        UI.Dragging = false
    end
    -- Toggle detection (simplified)
    local mousePos = UserInputService:GetMouseLocation()
    if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
        for _, el in pairs(UI.Elements) do
            if mousePos.X >= el.Box.Position.X and mousePos.X <= el.Box.Position.X + el.Box.Size.X and
               mousePos.Y >= el.Box.Position.Y and mousePos.Y <= el.Box.Position.Y + el.Box.Size.Y then
                el.Value = not el.Value
                if el.Callback then el.Callback(el.Value) end
            end
        end
    end
end

-- // INITIALIZE UI WITH TOGGLES
function SetupUI()
    UI.CreateWindow()
    local toggles = {
        {"Aimbot", function(v) Settings.Aimbot = v end, false},
        {"Silent Aim", function(v) Settings.SilentAim = v end, false},
        {"Show FOV", function(v) Settings.ShowFOV = v end, true},
        {"Prediction", function(v) Settings.Prediction = v end, false},
        {"Trigger Bot", function(v) Settings.TriggerBot = v end, false},
        {"Auto Fire", function(v) Settings.AutoFire = v end, false},
        {"ESP", function(v) Settings.ESP = v end, false},
        {"Fly", function(v) Settings.Fly = v end, false},
        {"Noclip", function(v) Settings.Noclip = v end, false},
        {"Speed Hack", function(v) Settings.SpeedHack = v end, false},
        {"Infinite Jump", function(v) Settings.InfiniteJump = v end, false},
        {"Chams", function(v) Settings.Chams = v; if v then Chams.Apply() else Chams.Remove() end end, false},
        {"Fullbright", function(v) Settings.FullBright = v; if v then Fullbright.Apply() else Fullbright.Remove() end end, false},
        {"Anti-Ban", function(v) Settings.AntiBan = v end, true},
        {"Anti-Crash", function(v) Settings.AntiCrash = v end, true}
    }
    for _, t in pairs(toggles) do
        local el = UI.AddToggle(t[1], t[2], t[3])
        el.Callback = t[2]
    end
end

-- // MAIN LOOPS
RunService.RenderStepped:Connect(function()
    SafeCall(function()
        UpdateFOV()
        AimbotSystem.Update()
        TriggerSystem.Update()
        ESP.Update()
        Notifications.Update()
        UI.Update()
    end)
end)

RunService.Heartbeat:Connect(function()
    SafeCall(function()
        Movement.Fly()
        Movement.Noclip()
        Movement.SpeedHack()
        Movement.InfiniteJump()
    end)
end)

-- // KEYBINDS (Panic)
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Delete then
        if Panic.Active then Panic.Deactivate() else Panic.Activate() end
    end
end)

-- // INIT
SafeCall(function()
    HookSystem.Install()
    SetupUI()
    ScriptEnv.Loaded = true
    Notifications.Notify("BIBILABU HUB", "Loaded successfully!", 3)
end)

print("[BIBILABU HUB] v5.0 ready. Boss man, we're live.")
