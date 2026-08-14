-- ============================================================
-- AXIOM PATCH — FAST START / UI-FIRST / NO BLOCKING INIT
-- ============================================================

-- Replace the existing Menu.Build() with this version.
-- Main changes:
--   * prevents recursive/re-entrant builds
--   * avoids building when Drawing is unavailable
--   * clamps invalid slider ratios
--   * yields between expensive batches
--   * keeps the UI alive independently of other systems

local MenuBuildState = {
    Busy = false,
    Pending = false,
    Version = 0,
}

local function RequestMenuBuild()
    if MenuBuildState.Busy then
        MenuBuildState.Pending = true
        return
    end

    MenuBuildState.Version += 1
    local buildVersion = MenuBuildState.Version

    task.spawn(function()
        if MenuBuildState.Busy then
            MenuBuildState.Pending = true
            return
        end

        MenuBuildState.Busy = true

        local ok, err = xpcall(function()
            if not Drawing or not Menu.Vis then
                return
            end

            Menu.ClearDraw()

            local p = Menu.Pos
            local W = Menu.W
            local tabW = math.floor(W / math.max(#Menu.Tabs, 1))

            local rows = {}

            for k, v in pairs(Settings) do
                if v.Tab == Menu.ActiveTab then
                    rows[#rows + 1] = {
                        K = k,
                        C = v
                    }
                end
            end

            table.sort(rows, function(a, b)
                return a.K < b.K
            end)

            local totalH =
                Menu.HdrH +
                Menu.TabH +
                (#rows * Menu.RowH) +
                8

            -- Background
            MD("Square", {
                Position = Vector2.new(p.X - 3, p.Y - 3),
                Size = Vector2.new(W + 6, totalH + 6),
                Color = Color3.fromRGB(0, 0, 0),
                Filled = true,
                Transparency = 0.3
            })

            MD("Square", {
                Position = p,
                Size = Vector2.new(W, totalH),
                Color = BG1,
                Filled = true,
                Transparency = 0.96
            })

            -- Header
            MD("Square", {
                Position = p,
                Size = Vector2.new(W, Menu.HdrH),
                Color = BG2,
                Filled = true,
                Transparency = 1
            })

            MD("Square", {
                Position = p,
                Size = Vector2.new(3, Menu.HdrH),
                Color = AC,
                Filled = true,
                Transparency = 1
            })

            MD("Text", {
                Text = "BIBILABU HUB  v7.1",
                Position = Vector2.new(p.X + 12, p.Y + 8),
                Size = 15,
                Color = TPRI,
                Outline = true,
                OutlineColor = Color3.fromRGB(0, 0, 0)
            })

            MD("Text", {
                Text = "[INS]",
                Position = Vector2.new(p.X + W - 38, p.Y + 9),
                Size = 12,
                Color = TSEC,
                Outline = false
            })

            -- Tabs
            MD("Square", {
                Position = Vector2.new(p.X, p.Y + Menu.HdrH),
                Size = Vector2.new(W, Menu.TabH),
                Color = BG2,
                Filled = true,
                Transparency = 1
            })

            for i, tab in ipairs(Menu.Tabs) do
                local tx = p.X + (i - 1) * tabW
                local ty = p.Y + Menu.HdrH
                local isActive = tab == Menu.ActiveTab

                MD("Square", {
                    Position = Vector2.new(tx, ty),
                    Size = Vector2.new(tabW, Menu.TabH),
                    Color = isActive and BG3 or BG2,
                    Filled = true,
                    Transparency = 1
                })

                if isActive then
                    MD("Square", {
                        Position = Vector2.new(
                            tx + 2,
                            ty + Menu.TabH - 2
                        ),
                        Size = Vector2.new(tabW - 4, 2),
                        Color = AC,
                        Filled = true,
                        Transparency = 1
                    })
                end

                MD("Text", {
                    Text = tab,
                    Position = Vector2.new(
                        tx + tabW / 2,
                        ty + 6
                    ),
                    Size = 11,
                    Center = true,
                    Color = isActive and TACT or TIDLE,
                    Outline = false
                })

                Menu.Rows[#Menu.Rows + 1] = {
                    Type = "tab",
                    Tab = tab,
                    B = {
                        X = tx,
                        Y = ty,
                        W = tabW,
                        H = Menu.TabH
                    }
                }
            end

            -- Rows
            local ry0 =
                p.Y +
                Menu.HdrH +
                Menu.TabH +
                4

            for idx, row in ipairs(rows) do
                local k = row.K
                local cfg = row.C
                local ry = ry0 + ((idx - 1) * Menu.RowH)
                local alt = idx % 2 == 0

                MD("Square", {
                    Position = Vector2.new(p.X + 3, ry),
                    Size = Vector2.new(W - 6, Menu.RowH - 2),
                    Color = alt and BG4 or BG3,
                    Filled = true,
                    Transparency = 0.85
                })

                MD("Text", {
                    Text = k,
                    Position = Vector2.new(
                        p.X + Menu.Pad + 3,
                        ry + 7
                    ),
                    Size = 12,
                    Color = TPRI,
                    Outline = true,
                    OutlineColor = Color3.fromRGB(0, 0, 0)
                })

                if cfg.Type == "toggle" then
                    local bx = p.X + W - 26
                    local by = ry + 6
                    local bs = 15

                    MD("Square", {
                        Position = Vector2.new(bx, by),
                        Size = Vector2.new(bs, bs),
                        Color = cfg.Value
                            and AC
                            or Color3.fromRGB(44, 44, 56),
                        Filled = true,
                        Transparency = 1
                    })

                    if cfg.Value then
                        MD("Text", {
                            Text = "✓",
                            Position = Vector2.new(bx + 1, by + 1),
                            Size = 13,
                            Color = Color3.fromRGB(0, 0, 0),
                            Outline = false
                        })
                    end

                    Menu.Rows[#Menu.Rows + 1] = {
                        Type = "toggle",
                        Key = k,
                        B = {
                            X = p.X + 3,
                            Y = ry,
                            W = W - 6,
                            H = Menu.RowH - 2
                        }
                    }

                elseif cfg.Type == "slider" then
                    local sx = p.X + W / 2 + 4
                    local sw = W / 2 - 22
                    local sy = ry + Menu.RowH / 2

                    local mn = tonumber(cfg.Min) or 0
                    local mx = tonumber(cfg.Max) or 100

                    if mx <= mn then
                        mx = mn + 1
                    end

                    local value = tonumber(cfg.Value) or mn
                    local ratio = math.clamp(
                        (value - mn) / (mx - mn),
                        0,
                        1
                    )

                    MD("Square", {
                        Position = Vector2.new(sx, sy - 2),
                        Size = Vector2.new(sw, 4),
                        Color = Color3.fromRGB(40, 40, 52),
                        Filled = true,
                        Transparency = 1
                    })

                    MD("Square", {
                        Position = Vector2.new(sx, sy - 2),
                        Size = Vector2.new(sw * ratio, 4),
                        Color = AC,
                        Filled = true,
                        Transparency = 1
                    })

                    MD("Circle", {
                        Position = Vector2.new(
                            sx + sw * ratio,
                            sy
                        ),
                        Radius = 5,
                        Color = Color3.fromRGB(255, 255, 255),
                        Filled = true,
                        Transparency = 1
                    })

                    MD("Text", {
                        Text = tostring(
                            math.floor(value * 100 + 0.5) / 100
                        ),
                        Position = Vector2.new(sx - 4, ry + 7),
                        Size = 10,
                        Color = TSEC,
                        Outline = false
                    })

                    Menu.Rows[#Menu.Rows + 1] = {
                        Type = "slider",
                        Key = k,
                        SX = sx,
                        SW = sw,
                        B = {
                            X = sx,
                            Y = ry,
                            W = sw,
                            H = Menu.RowH - 2
                        }
                    }

                elseif cfg.Type == "dropdown" then
                    local dx = p.X + W - 95

                    MD("Square", {
                        Position = Vector2.new(dx, ry + 5),
                        Size = Vector2.new(86, 17),
                        Color = Color3.fromRGB(30, 30, 40),
                        Filled = true,
                        Transparency = 1
                    })

                    MD("Text", {
                        Text = tostring(cfg.Value),
                        Position = Vector2.new(dx + 5, ry + 7),
                        Size = 11,
                        Color = TACT,
                        Outline = false
                    })

                    MD("Text", {
                        Text = "▾",
                        Position = Vector2.new(dx + 72, ry + 6),
                        Size = 12,
                        Color = TSEC,
                        Outline = false
                    })

                    Menu.Rows[#Menu.Rows + 1] = {
                        Type = "dropdown",
                        Key = k,
                        B = {
                            X = dx,
                            Y = ry + 5,
                            W = 86,
                            H = 17
                        }
                    }
                end
            end

            -- If another build was requested while this one was running,
            -- the next pass will replace it instead of recursively rebuilding.
        end, function(e)
            return tostring(e) .. "\n" ..
                (debug and debug.traceback
                    and debug.traceback("", 2)
                    or "")
        end)

        MenuBuildState.Busy = false

        if not ok then
            warn("[BIB UI] Build failed: " .. tostring(err))
        end

        if MenuBuildState.Pending then
            MenuBuildState.Pending = false
            task.defer(RequestMenuBuild)
        end
    end)
end

Menu.Build = RequestMenuBuild


-- ============================================================
-- DRAG FIX
-- ============================================================
-- IMPORTANT:
-- Do NOT call Menu.Build() every RenderStepped while dragging.
-- Drawing creation/destruction is the expensive part.

local function UpdateMenuPosition(mp)
    local cam = GetCamera()
    local np = mp + Menu.DragOff

    if cam then
        local ok, vp = pcall(function()
            return cam.ViewportSize
        end)

        if ok and vp then
            np = Vector2.new(
                math.clamp(np.X, 0, math.max(0, vp.X - Menu.W)),
                math.clamp(np.Y, 0, math.max(0, vp.Y - 60))
            )
        end
    end

    if (np - Menu.Pos).Magnitude > 0.5 then
        Menu.Pos = np

        -- Queue ONE rebuild rather than destroying/recreating
        -- the entire Drawing tree repeatedly.
        RequestMenuBuild()
    end
end


-- ============================================================
-- REPLACE MENU.TICK
-- ============================================================

function Menu.Tick()
    if not Menu.Vis then
        return
    end

    local ok, mp = pcall(function()
        return UserInputService:GetMouseLocation()
    end)

    if not ok or not mp then
        return
    end

    local ok2, mb = pcall(function()
        return UserInputService:IsMouseButtonPressed(
            Enum.UserInputType.MouseButton1
        )
    end)

    if not ok2 then
        return
    end

    local now = os.clock()

    local header = {
        X = Menu.Pos.X,
        Y = Menu.Pos.Y,
        W = Menu.W,
        H = Menu.HdrH
    }

    -- Dragging
    if mb then
        if not Menu.Drag
            and not SDrag.Act
            and InB(header, mp)
        then
            Menu.Drag = true
            Menu.DragOff = Menu.Pos - mp
        end

        if Menu.Drag then
            UpdateMenuPosition(mp)
        end
    else
        Menu.Drag = false
    end

    -- Slider
    if SDrag.Act then
        if mb then
            local cfg = Settings[SDrag.Key]
            local row = SDrag.Row

            if cfg and row and row.SW > 0 then
                local ratio = math.clamp(
                    (mp.X - row.SX) / row.SW,
                    0,
                    1
                )

                local mn = tonumber(cfg.Min) or 0
                local mx = tonumber(cfg.Max) or 100

                if mx <= mn then
                    mx = mn + 1
                end

                local nv = mn + ((mx - mn) * ratio)
                nv = math.floor(nv * 100 + 0.5) / 100

                if math.abs(nv - cfg.Value) > 0.005 then
                    cfg.Value = nv

                    -- Queue, don't synchronously rebuild.
                    RequestMenuBuild()
                end
            end
        else
            SDrag.Act = false
            SDrag.Key = nil
            SDrag.Row = nil
        end

        return
    end

    -- Click
    if mb
        and (now - Menu.ClickCD) > 0.15
        and not Menu.Drag
    then
        for _, row in ipairs(Menu.Rows) do
            if InB(row.B, mp) then
                Menu.ClickCD = now

                if row.Type == "tab" then
                    Menu.ActiveTab = row.Tab
                    RequestMenuBuild()

                elseif row.Type == "toggle" then
                    local cfg = Settings[row.Key]

                    if cfg then
                        cfg.Value = not cfg.Value

                        -- Keep existing feature behavior.
                        if row.Key == "Chams" then
                            if cfg.Value then
                                for _, p in ipairs(GetPlayers()) do
                                    pcall(function()
                                        Chams.Apply(p)
                                    end)
                                end
                            else
                                for _, p in ipairs(GetPlayers()) do
                                    pcall(function()
                                        Chams.Remove(p)
                                    end)
                                end
                            end

                        elseif row.Key == "FullBright" then
                            if cfg.Value then
                                FB.On()
                            else
                                FB.Off()
                            end

                        elseif row.Key == "FOVChanger" then
                            local cam = GetCamera()

                            if cam then
                                pcall(function()
                                    cam.FieldOfView =
                                        cfg.Value
                                        and (S("CustomFOV") or 90)
                                        or 70
                                end)
                            end
                        end

                        RequestMenuBuild()
                    end

                elseif row.Type == "slider" then
                    SDrag.Act = true
                    SDrag.Key = row.Key
                    SDrag.Row = row

                elseif row.Type == "dropdown" then
                    local cfg = Settings[row.Key]

                    if cfg and cfg.Options and #cfg.Options > 0 then
                        local idx = 1

                        for i, option in ipairs(cfg.Options) do
                            if option == cfg.Value then
                                idx = i
                                break
                            end
                        end

                        cfg.Value =
                            cfg.Options[(idx % #cfg.Options) + 1]

                        if row.Key == "ChamStyle" then
                            for _, p in ipairs(GetPlayers()) do
                                if S("Chams") then
                                    pcall(function()
                                        Chams.Apply(p)
                                    end)
                                end
                            end
                        end

                        RequestMenuBuild()
                    end
                end

                break
            end
        end
    end
end


-- ============================================================
-- KEYBIND FIX
-- ============================================================

Track(UserInputService.InputBegan:Connect(function(input, gp)
    if gp then
        return
    end

    local panicKey = KeyMap[S("PanicKey") or "Delete"]
    local menuKey  = KeyMap[S("MenuKey") or "Insert"]

    if input.KeyCode == panicKey then
        Panic.Toggle()
        return
    end

    if input.KeyCode == menuKey then
        Menu.Vis = not Menu.Vis

        if Menu.Vis then
            RequestMenuBuild()
        else
            Menu.ClearDraw()
        end
    end
end))


-- ============================================================
-- UI-FIRST INITIALIZATION
-- ============================================================
-- This is the big timeout fix.
--
-- OLD:
--   RebuildPlayerCache()
--   Hooks.Install()
--   Menu.Build()
--
-- If Hooks.Install() or anything it touches stalls, the UI never
-- gets created.
--
-- NEW:
--   UI appears immediately.
--   Heavy initialization is deferred.
-- ============================================================

local InitState = {
    Started = false,
    HooksStarted = false,
    CacheStarted = false,
}

local function StartUI()
    if InitState.Started then
        return
    end

    InitState.Started = true

    -- Build immediately, independently of hooks.
    RequestMenuBuild()

    -- Give the renderer one opportunity to display the menu
    -- before anything expensive begins.
    task.defer(function()
        Runtime.Loaded = true

        pcall(function()
            Notif.Push(
                "BIBILABU HUB",
                "UI READY — " ..
                "that's what the hell is going on, boss man.",
                4,
                AC
            )
        end)
    end)
end

local function StartBackgroundSystems()
    task.spawn(function()

        -- Cache is not allowed to block UI startup.
        pcall(function()
            RebuildPlayerCache()
            InitState.CacheStarted = true
        end)

        -- Hooks are isolated from the UI.
        task.defer(function()
            if InitState.HooksStarted then
                return
            end

            InitState.HooksStarted = true

            local ok, err = xpcall(
                function()
                    Hooks.Install()
                end,
                function(e)
                    return tostring(e) .. "\n" ..
                        (debug and debug.traceback
                            and debug.traceback("", 2)
                            or "")
                end
            )

            if not ok then
                warn("[BIB INIT] Hooks.Install failed: " .. tostring(err))
            end
        end)
    end)
end


-- ============================================================
-- FINAL START
-- ============================================================

task.defer(StartUI)
task.defer(StartBackgroundSystems)

print("[BIBILABU HUB] UI-first startup complete.")
