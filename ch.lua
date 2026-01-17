-- Simple Arsenal Features 2026 (Fluent UI)
-- Aimbot, ESP, Hitbox Expander, Fly, etc.

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Arsenal | Simple Features",
    SubTitle = "by community",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
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

-- Settings
local Settings = {
    Aimbot = false,
    AimbotPart = "Head",
    AimbotSmooth = 0.12,
    FOV = 180,
    TeamCheck = true,
    VisibleCheck = true,
    
    ESP = false,
    Tracers = false,
    Boxes = false,
    
    HitboxExpander = false,
    HitboxSize = 8,
    
    Fly = false,
    FlySpeed = 60,
    
    NoClip = false,
    InfiniteJump = false
}

local ESP_Objects = {}
local FlyBodyVelocity = nil
local FlyConnection = nil

-- ──────────────────────────────────────────────────────────────
--    BASIC UTILITY FUNCTIONS
-- ──────────────────────────────────────────────────────────────

local function GetNearest()
    local closest, dist = nil, Settings.FOV
    
    for _, player in Players:GetPlayers() do
        if player == LocalPlayer then continue end
        if Settings.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local char = player.Character
        if not char then continue end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        local root = char:FindFirstChild("HumanoidRootPart")
        if not (humanoid and root and humanoid.Health > 0) then continue end
        
        local screen, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then continue end
        
        local screenDist = (Vector2.new(screen.X, screen.Y) - Camera.ViewportSize/2).Magnitude
        if screenDist < dist then
            dist = screenDist
            closest = player
        end
    end
    
    return closest
end

local function IsVisible(target)
    if not target then return false end
    local part = target.Character and target.Character:FindFirstChild(Settings.AimbotPart)
    if not part then return false end
    
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(origin, dir * 2, rayParams)
    return result and result.Instance and result.Instance:IsDescendantOf(target.Character)
end

-- ──────────────────────────────────────────────────────────────
--    AIMBOT
-- ──────────────────────────────────────────────────────────────

local aimConnection

local function ToggleAimbot(state)
    if aimConnection then aimConnection:Disconnect() aimConnection = nil end
    
    if state then
        aimConnection = RunService.RenderStepped:Connect(function()
            if not Settings.Aimbot then return end
            
            local target = GetNearest()
            if not target then return end
            
            local part = target.Character and target.Character:FindFirstChild(Settings.AimbotPart)
            if not part then return end
            
            if Settings.VisibleCheck and not IsVisible(target) then return end
            
            local goal = CFrame.new(Camera.CFrame.Position, part.Position)
            Camera.CFrame = Camera.CFrame:Lerp(goal, Settings.AimbotSmooth)
        end)
    end
end

-- ──────────────────────────────────────────────────────────────
--    ESP
-- ──────────────────────────────────────────────────────────────

local function UpdateESP()
    for player, drawings in pairs(ESP_Objects) do
        local box, tracer = drawings.box, drawings.tracer
        
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Head") then
            box.Visible = false
            tracer.Visible = false
            continue
        end
        
        local root = char.HumanoidRootPart
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum.Health <= 0 then
            box.Visible = false
            tracer.Visible = false
            continue
        end
        
        local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
        if not onScreen then
            box.Visible = false
            tracer.Visible = false
            continue
        end
        
        local headPos = Camera:WorldToViewportPoint(char.Head.Position + Vector3.new(0,0.6,0))
        local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,3.5,0))
        
        local height = math.abs(headPos.Y - legPos.Y)
        local width = height * 0.55
        
        box.Size = Vector2.new(width, height)
        box.Position = Vector2.new(rootPos.X - width/2, headPos.Y)
        box.Visible = Settings.Boxes
        
        tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        tracer.To = Vector2.new(rootPos.X, rootPos.Y)
        tracer.Visible = Settings.Tracers
    end
end

local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local box = Drawing.new("Square")
    box.Thickness = 1.4
    box.Color = Color3.fromRGB(255, 80, 80)
    box.Filled = false
    box.Transparency = 0.95
    
    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.3
    tracer.Color = Color3.fromRGB(255, 80, 80)
    tracer.Transparency = 0.9
    
    ESP_Objects[player] = {box = box, tracer = tracer}
end

local function ToggleESP(state)
    if state then
        for _, p in Players:GetPlayers() do CreateESP(p) end
        
        Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function() CreateESP(p) end)
        end)
        
        RunService.RenderStepped:Connect(UpdateESP)
    else
        for _, drawings in pairs(ESP_Objects) do
            drawings.box:Remove()
            drawings.tracer:Remove()
        end
        ESP_Objects = {}
    end
end

-- ──────────────────────────────────────────────────────────────
--    HITBOX EXPANDER
-- ──────────────────────────────────────────────────────────────

local function UpdateHitboxes()
    for _, player in Players:GetPlayers() do
        if player == LocalPlayer then continue end
        if Settings.TeamCheck and player.Team == LocalPlayer.Team then continue end
        
        local char = player.Character
        if not char then continue end
        
        local head = char:FindFirstChild("Head")
        if head then
            if Settings.HitboxExpander then
                head.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                head.Transparency = 0.65
                head.CanCollide = false
            else
                head.Size = Vector3.new(1.2, 1.2, 1.2) -- Arsenal default-ish
                head.Transparency = 0
                head.CanCollide = true
            end
        end
    end
end

-- ──────────────────────────────────────────────────────────────
--    FLY + NOCLIP + INF JUMP
-- ──────────────────────────────────────────────────────────────

local function ToggleFly(state)
    Settings.Fly = state
    
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy() FlyBodyVelocity = nil end
    
    if state and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        
        FlyBodyVelocity = Instance.new("BodyVelocity")
        FlyBodyVelocity.MaxForce = Vector3.new(1e6, 1e6, 1e6)
        FlyBodyVelocity.Velocity = Vector3.zero
        FlyBodyVelocity.Parent = hrp
        
        FlyConnection = RunService.Heartbeat:Connect(function()
            if not Settings.Fly then return end
            
            local move = Vector3.zero
            local cam = workspace.CurrentCamera.CFrame
            
            if UserInputService:IsKeyDown(Enum.KeyCode.W)    then move += cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S)    then move -= cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A)    then move -= cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D)    then move += cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move += Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move -= Vector3.new(0,1,0) end
            
            FlyBodyVelocity.Velocity = move.Magnitude > 0 and move.Unit * Settings.FlySpeed or Vector3.zero
        end)
    end
end

local noclipConn
local function ToggleNoClip(state)
    Settings.NoClip = state
    
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in LocalPlayer.Character:GetDescendants() do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

local infJumpConn
local function ToggleInfiniteJump(state)
    Settings.InfiniteJump = state
    
    if state and not infJumpConn then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            if Settings.InfiniteJump and LocalPlayer.Character then
                LocalPlayer.Character.Humanoid:ChangeState("Jumping")
            end
        end)
    end
end

-- ──────────────────────────────────────────────────────────────
--    UI ELEMENTS
-- ──────────────────────────────────────────────────────────────

do -- Combat Tab
    local Section = Tabs.Combat:AddSection("Aimbot")
    
    Section:AddToggle("AimbotToggle", {
        Title = "Enable Aimbot",
        Default = false,
        Callback = function(v) Settings.Aimbot = v ToggleAimbot(v) end
    })
    
    Section:AddToggle("TeamCheck", {
        Title = "Team Check",
        Default = true,
        Callback = function(v) Settings.TeamCheck = v end
    })
    
    Section:AddToggle("VisibleCheck", {
        Title = "Visible Check",
        Default = true,
        Callback = function(v) Settings.VisibleCheck = v end
    })
    
    Section:AddSlider("Smoothness", {
        Title = "Smoothness",
        Description = "Lower = faster",
        Default = 12,
        Min = 5,
        Max = 40,
        Rounding = 1,
        Callback = function(v) Settings.AimbotSmooth = v/100 end
    })
    
    Section:AddSlider("FOV", {
        Title = "Field of View",
        Default = 180,
        Min = 50,
        Max = 400,
        Rounding = 0,
        Callback = function(v) Settings.FOV = v end
    })
end

do -- Visual Tab
    local Section = Tabs.Visual:AddSection("ESP")
    
    Section:AddToggle("ESPBoxes", {
        Title = "Boxes",
        Default = false,
        Callback = function(v) Settings.Boxes = v end
    })
    
    Section:AddToggle("ESPTracers", {
        Title = "Tracers",
        Default = false,
        Callback = function(v) Settings.Tracers = v end
    })
    
    local ESPToggle = Section:AddToggle("ESP", {
        Title = "Enable ESP",
        Default = false,
        Callback = ToggleESP
    })
    
    local HitboxSec = Tabs.Visual:AddSection("Hitbox Expander")
    
    HitboxSec:AddToggle("Hitbox", {
        Title = "Enable Hitbox Expander",
        Default = false,
        Callback = function(v)
            Settings.HitboxExpander = v
            if v then UpdateHitboxes() end
        end
    })
    
    HitboxSec:AddSlider("HitboxSize", {
        Title = "Size",
        Default = 8,
        Min = 4,
        Max = 18,
        Rounding = 1,
        Callback = function(v)
            Settings.HitboxSize = v
            if Settings.HitboxExpander then UpdateHitboxes() end
        end
    })
end

do -- Movement Tab
    local Section = Tabs.Movement:AddSection("Movement")
    
    Section:AddToggle("Fly", {
        Title = "Fly",
        Default = false,
        Callback = ToggleFly
    })
    
    Section:AddSlider("FlySpeed", {
        Title = "Fly Speed",
        Default = 60,
        Min = 30,
        Max = 180,
        Rounding = 0,
        Callback = function(v) Settings.FlySpeed = v end
    })
    
    Section:AddToggle("NoClip", {
        Title = "NoClip",
        Default = false,
        Callback = ToggleNoClip
    })
    
    Section:AddToggle("InfJump", {
        Title = "Infinite Jump",
        Default = false,
        Callback = ToggleInfiniteJump
    })
end

-- Auto update hitboxes when new players spawn
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        task.wait(0.4)
        if Settings.HitboxExpander then UpdateHitboxes() end
        if Settings.ESP then CreateESP(p) end
    end)
end)

-- Initial load
task.spawn(function()
    task.wait(1.5)
    if Settings.HitboxExpander then UpdateHitboxes() end
end)

Fluent:Notify({
    Title = "Loaded",
    Content = "Simple Arsenal features loaded\nPress RightShift to open/close",
    Duration = 5
})

print("Simple Arsenal script loaded - RightShift to toggle UI")
