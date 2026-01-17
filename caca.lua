-- Fixed Arsenal Script (2026) | Silent Aim + Proper Hitbox + More
-- Glass / Premium Dark Style using Fluent UI
-- Works with latest Fluent as of 2025-2026

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "hinge",
    SubTitle = "arsenal premium | glass edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(620, 520),
    Acrylic = true, -- Glass effect
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightShift
})

local Tabs = {
    Combat = Window:AddTab({ Title = "Combat", Icon = "crosshair" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Movement = Window:AddTab({ Title = "Movement", Icon = "footprints" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "wrench" })
}

local Options = Fluent.Options

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- Settings table
local Settings = {
    SilentAim = false,
    AimPart = "Head",
    FOV = 150,
    TeamCheck = true,
    VisibleCheck = false,

    ESP = false,
    Boxes = true,
    Tracers = true,

    HitboxExpander = false,
    HitboxSize = 25,

    Fly = false,
    FlySpeed = 60,

    NoClip = false,
    InfiniteJump = false
}

-- Globals
local oldNamecall
local ESP_Objects = {}
local FlyBodyVelocity, FlyConnection
local HitboxConnection
local ESPConnection
local noclipConn
local infJumpConn

-- FOV Circle
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FOVGui"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

local FOVCircle = Drawing.new("Circle")
FOVCircle.Radius = Settings.FOV
FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
FOVCircle.Color = Color3.fromRGB(255, 0, 0)
FOVCircle.Thickness = 2
FOVCircle.NumSides = 64
FOVCircle.Filled = false
FOVCircle.Transparency = 0.7
FOVCircle.Visible = false

-- Update FOV position every frame
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end)

-- Get nearest target in FOV
local function GetNearestInFOV()
    local closest, shortestDist = nil, Settings.FOV
    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if Settings.TeamCheck and player.Team == LocalPlayer.Team then continue end

        local char = player.Character
        if not (char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid")) then continue end
        if char.Humanoid.Health <= 0 then continue end

        local rootPos, onScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
        if onScreen then
            local screenDist = (Vector2.new(rootPos.X, rootPos.Y) - mousePos).Magnitude
            if screenDist < shortestDist then
                if Settings.VisibleCheck then
                    local origin = Camera.CFrame.Position
                    local direction = (char.HumanoidRootPart.Position - origin).Unit * 5000
                    local rayParams = RaycastParams.new()
                    rayParams.FilterDescendantsInstances = {LocalPlayer.Character or game}
                    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                    local result = workspace:Raycast(origin, direction, rayParams)
                    if result and result.Instance:IsDescendantOf(char) then
                        shortestDist = screenDist
                        closest = player
                    end
                else
                    shortestDist = screenDist
                    closest = player
                end
            end
        end
    end
    return closest
end

-- Silent Aim Hook (HitPart method)
local function InitSilentAim()
    if oldNamecall then return end -- Prevent double hook

    local mt = getrawmetatable(game)
    oldNamecall = mt.__namecall
    setreadonly(mt, false)

    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()

        if Settings.SilentAim and method == "FireServer" and tostring(self.Name) == "HitPart" then
            local target = GetNearestInFOV()
            if target and target.Character then
                local aimPart = target.Character:FindFirstChild(Settings.AimPart)
                if aimPart then
                    args[1] = aimPart
                    args[2] = aimPart.Position
                end
            end
        end

        return oldNamecall(self, unpack(args))
    end)

    setreadonly(mt, true)
end

-- Hitbox Expander
local function UpdateHitboxes()
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer or not player.Character then continue end

        local lower = player.Character:FindFirstChild("LowerTorso")
        local hrp = player.Character:FindFirstChild("HumanoidRootPart")

        if Settings.TeamCheck and player.Team == LocalPlayer.Team then
            -- Reset teammates
            if lower then
                lower.Size = Vector3.new(2, 0.4, 1)
                lower.Transparency = 0
                lower.CanCollide = true
            end
            if hrp then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.Transparency = 1
                hrp.CanCollide = false
            end
        else
            -- Expand enemies
            if lower then
                lower.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                lower.Transparency = 0.7
                lower.CanCollide = false
            end
            if hrp then
                hrp.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                hrp.Transparency = 1
                hrp.CanCollide = false
            end
        end
    end
end

-- ESP Functions
local function CreateESP(player)
    if player == LocalPlayer then return end

    local box = Drawing.new("Square")
    box.Thickness = 2
    box.Color = Color3.fromRGB(255, 0, 0)
    box.Filled = false
    box.Transparency = 1
    box.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 2
    tracer.Color = Color3.fromRGB(255, 0, 0)
    tracer.Transparency = 1
    tracer.Visible = false

    ESP_Objects[player] = {Box = box, Tracer = tracer}
end

local function UpdateESP()
    for player, drawings in pairs(ESP_Objects) do
        if not player or not player.Character then
            drawings.Box.Visible = false
            drawings.Tracer.Visible = false
            continue
        end

        local char = player.Character
        local root = char:FindFirstChild("HumanoidRootPart")
        local head = char:FindFirstChild("Head")
        local hum = char:FindFirstChildOfClass("Humanoid")

        if not (root and head and hum and hum.Health > 0) then
            drawings.Box.Visible = false
            drawings.Tracer.Visible = false
            continue
        end

        local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then
            drawings.Box.Visible = false
            drawings.Tracer.Visible = false
            continue
        end

        local headPos = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
        local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3.5, 0))
        local height = math.abs(headPos.Y - legPos.Y)
        local width = height / 2.2

        drawings.Box.Size = Vector2.new(width, height)
        drawings.Box.Position = Vector2.new(rootPos.X - width / 2, headPos.Y)
        drawings.Box.Visible = Settings.ESP and Settings.Boxes

        drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        drawings.Tracer.To = Vector2.new(rootPos.X, rootPos.Y)
        drawings.Tracer.Visible = Settings.ESP and Settings.Tracers
    end
end

-- Fly
local function ToggleFly(state)
    Settings.Fly = state
    if FlyConnection then FlyConnection:Disconnect() end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy() end

    if state and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            FlyBodyVelocity = Instance.new("BodyVelocity")
            FlyBodyVelocity.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            FlyBodyVelocity.Velocity = Vector3.new()
            FlyBodyVelocity.Parent = hrp

            FlyConnection = RunService.Heartbeat:Connect(function()
                local move = Vector3.new()
                local cam = Camera.CFrame
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += cam.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move -= cam.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move -= cam.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += cam.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end

                FlyBodyVelocity.Velocity = move.Unit * Settings.FlySpeed * 10
            end)
        end
    end
end

-- NoClip
local function ToggleNoClip(state)
    Settings.NoClip = state
    if noclipConn then noclipConn:Disconnect() end
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in ipairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

-- Infinite Jump
local function ToggleInfiniteJump(state)
    Settings.InfiniteJump = state
    if infJumpConn then infJumpConn:Disconnect() end
    if state then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            if LocalPlayer.Character then
                LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState("Jumping")
            end
        end)
    end
end

-- Toggles
local function ToggleSilentAim(state)
    Settings.SilentAim = state
    if state then
        InitSilentAim()
    end
end

local function ToggleHitbox(state)
    Settings.HitboxExpander = state
    if HitboxConnection then HitboxConnection:Disconnect() end

    if state then
        UpdateHitboxes()
        HitboxConnection = RunService.Heartbeat:Connect(UpdateHitboxes)

        Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                UpdateHitboxes()
            end)
        end)
    end
end

local function ToggleESP(state)
    Settings.ESP = state
    if ESPConnection then ESPConnection:Disconnect() end

    if state then
        for _, p in ipairs(Players:GetPlayers()) do
            CreateESP(p)
        end

        Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                CreateESP(p)
            end)
        end)

        ESPConnection = RunService.RenderStepped:Connect(UpdateESP)
    else
        for _, data in pairs(ESP_Objects) do
            if data.Box then data.Box:Remove() end
            if data.Tracer then data.Tracer:Remove() end
        end
        ESP_Objects = {}
    end
end

-- UI - Combat Tab
do
    local Sec = Tabs.Combat:AddSection("Silent Aim")

    Sec:AddToggle("SilentAim", {
        Title = "Silent Aim",
        Default = false,
        Callback = ToggleSilentAim
    })

    Sec:AddToggle("TeamCheck", {
        Title = "Team Check",
        Default = true,
        Callback = function(v) Settings.TeamCheck = v end
    })

    Sec:AddToggle("VisibleCheck", {
        Title = "Visible Check",
        Default = false,
        Callback = function(v) Settings.VisibleCheck = v end
    })

    Sec:AddDropdown("AimPart", {
        Title = "Aim Part",
        Values = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
        Default = "Head",
        Callback = function(v) Settings.AimPart = v end
    })

    Sec:AddSlider("FOV", {
        Title = "FOV Radius",
        Min = 50,
        Max = 400,
        Default = 150,
        Rounding = 1,
        Callback = function(v)
            Settings.FOV = v
            FOVCircle.Radius = v
        end
    })

    Sec:AddToggle("ShowFOV", {
        Title = "Show FOV Circle",
        Default = false,
        Callback = function(v) FOVCircle.Visible = v end
    })
end

-- Visual Tab
do
    local Sec = Tabs.Visual:AddSection("ESP")

    Sec:AddToggle("ESP", {
        Title = "Enable ESP",
        Default = false,
        Callback = ToggleESP
    })

    Sec:AddToggle("Boxes", {
        Title = "Boxes",
        Default = true,
        Callback = function(v) Settings.Boxes = v end
    })

    Sec:AddToggle("Tracers", {
        Title = "Tracers",
        Default = true,
        Callback = function(v) Settings.Tracers = v end
    })
end

-- Movement Tab
do
    local Sec = Tabs.Movement:AddSection("Movement Cheats")

    Sec:AddToggle("Fly", {
        Title = "Fly",
        Default = false,
        Callback = ToggleFly
    })

    Sec:AddSlider("FlySpeed", {
        Title = "Fly Speed",
        Min = 20,
        Max = 300,
        Default = 60,
        Rounding = 1,
        Callback = function(v) Settings.FlySpeed = v end
    })

    Sec:AddToggle("NoClip", {
        Title = "NoClip",
        Default = false,
        Callback = ToggleNoClip
    })

    Sec:AddToggle("InfiniteJump", {
        Title = "Infinite Jump",
        Default = false,
        Callback = ToggleInfiniteJump
    })
end

-- Misc Tab (Hitbox + Config)
do
    local Sec = Tabs.Misc:AddSection("Hitbox Expander")

    Sec:AddToggle("HitboxExpander", {
        Title = "Enable Hitbox Expander",
        Default = false,
        Callback = ToggleHitbox
    })

    Sec:AddSlider("HitboxSize", {
        Title = "Hitbox Size",
        Min = 10,
        Max = 40,
        Default = 25,
        Rounding = 1,
        Callback = function(v) Settings.HitboxSize = v end
    })

    Sec:AddParagraph({
        Title = "Note",
        Content = "Best size for Arsenal is usually 22-28"
    })
end

-- Initialize Managers
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)

InterfaceManager:SetFolder("HingeScripts")
SaveManager:SetFolder("HingeScripts/Arsenal")

InterfaceManager:BuildInterfaceSection(Tabs.Misc)
SaveManager:BuildConfigSection(Tabs.Misc)

SaveManager:LoadAutoloadConfig()

-- Initial ESP creation
for _, player in ipairs(Players:GetPlayers()) do
    CreateESP(player)
end

-- Notify
Fluent:Notify({
    Title = "hinge loaded",
    Content = "Full Arsenal cheat loaded • RightShift to toggle GUI\nEnjoy responsibly!",
    Duration = 6
})

print("hinge | Arsenal premium loaded | Glass edition")
