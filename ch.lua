
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()
local Window = Fluent:CreateWindow({
    Title = "hinge",
    SubTitle = "arsenal cheat",
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
    SilentAim = false,
    AimPart = "Head",
    FOV = 150,
    TeamCheck = true,
    VisibleCheck = false, -- Less strict for silent
   
    ESP = false,
    Boxes = true,
    Tracers = true,
   
    HitboxExpander = false,
    HitboxSize = 25, -- 25-30 good for Arsenal
   
    Fly = false,
    FlySpeed = 60,
   
    NoClip = false,
    InfiniteJump = false
}
-- Globals for hook
local oldNamecall
local ESP_Objects = {}
local FlyBodyVelocity, FlyConnection
local HitboxConnection
local ESPConnection
-- FOV Circle (optional visual)
local ScreenGui = Instance.new("ScreenGui", LocalPlayer.PlayerGui)
ScreenGui.Name = "FOVGui"
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
-- Get nearest to center screen (for silent aim FOV)
local function GetNearestInFOV()
    local closest, shortestDist = nil, Settings.FOV
   
    local mousePos = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2) -- Center for FOV aim
   
    for _, player in Players:GetPlayers() do
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
                    -- Quick raycast visible check
                    local origin = Camera.CFrame.Position
                    local direction = (char.HumanoidRootPart.Position - origin).Unit * 1000
                    local rayParams = RaycastParams.new()
                    rayParams.FilterType = Enum.RaycastFilterType.Blacklist
                    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
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
-- SILENT AIM HOOK (Arsenal HitPart method from open-source)
local function InitSilentAim()
    local mt = getrawmetatable(game)
    oldNamecall = mt.__namecall
    setreadonly(mt, false)
   
    mt.__namecall = newcclosure(function(self, ...)
        local args = {...}
        local method = getnamecallmethod()
       
        if Settings.SilentAim and method == "FireServer" and tostring(self) == "HitPart" then
            local target = GetNearestInFOV()
            if target and target.Character then
                local aimPartObj = target.Character:FindFirstChild(Settings.AimPart)
                if aimPartObj then
                    args[1] = aimPartObj -- Part
                    args[2] = aimPartObj.Position -- Position
                end
            end
        end
       
        return oldNamecall(self, unpack(args))
    end)
   
    setreadonly(mt, true)
end
local function ToggleSilentAim(state)
    Settings.SilentAim = state
    if state then
        InitSilentAim()
    end
    -- Note: Hook stays, but only activates if enabled
end
-- HITBOX EXPANDER (Fixed for Arsenal: LowerTorso + HRP)
local function UpdateHitboxes()
    for _, player in Players:GetPlayers() do
        if player == LocalPlayer or not player.Character then continue end
        if Settings.TeamCheck and player.Team == LocalPlayer.Team then
            -- Revert teammates
            local lower = player.Character:FindFirstChild("LowerTorso")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if lower then
                lower.Size = Vector3.new(2, 0.4, 1)
                lower.CanCollide = true
                lower.Transparency = 0
            end
            if hrp then
                hrp.Size = Vector3.new(2, 2, 1)
                hrp.CanCollide = false
                hrp.Transparency = 1
            end
        else
            -- Expand enemies
            local lower = player.Character:FindFirstChild("LowerTorso")
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            if lower then
                lower.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                lower.CanCollide = false
                lower.Transparency = 0.8 -- Semi-visible
            end
            if hrp then
                hrp.Size = Vector3.new(Settings.HitboxSize, Settings.HitboxSize, Settings.HitboxSize)
                hrp.CanCollide = false
                hrp.Transparency = 1 -- Invisible
            end
        end
    end
end
local function ToggleHitbox(state)
    Settings.HitboxExpander = state
    if HitboxConnection then HitboxConnection:Disconnect() end
   
    if state then
        UpdateHitboxes() -- Initial
        HitboxConnection = RunService.Heartbeat:Connect(function()
            UpdateHitboxes()
        end)
       
        -- New players
        Players.PlayerAdded:Connect(function(p)
            p.CharacterAdded:Connect(function()
                task.wait(1) -- Wait load
                UpdateHitboxes()
            end)
        end)
    end
end
-- ESP (same as before, improved)
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
   
    ESP_Objects[player] = {box = box, tracer = tracer}
end
local function UpdateESP()
    for player, drawings in pairs(ESP_Objects) do
        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Head") then
            drawings.box.Visible = false
            drawings.tracer.Visible = false
            return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then
            drawings.box.Visible = false
            drawings.tracer.Visible = false
            return
        end
       
        local rootPos, onScreen = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position)
        if not onScreen then
            drawings.box.Visible = false
            drawings.tracer.Visible = false
            return
        end
       
        local headPos = Camera:WorldToViewportPoint(char.Head.Position + Vector3.new(0, 0.5, 0))
        local legPos = Camera:WorldToViewportPoint(char.HumanoidRootPart.Position - Vector3.new(0, 4, 0))
        local height = math.abs(legPos.Y - headPos.Y)
        local width = height / 2.2
       
        drawings.box.Size = Vector2.new(width, height)
        drawings.box.Position = Vector2.new(rootPos.X - width / 2, headPos.Y)
        drawings.box.Visible = Settings.ESP and Settings.Boxes
       
        drawings.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y * 0.9)
        drawings.tracer.To = Vector2.new(rootPos.X, rootPos.Y)
        drawings.tracer.Visible = Settings.ESP and Settings.Tracers
    end
end
local function ToggleESP(state)
    Settings.ESP = state
    if ESPConnection then ESPConnection:Disconnect() end
    if state then
        for _, p in Players:GetPlayers() do CreateESP(p) end
        Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function() CreateESP(p) end) end)
        ESPConnection = RunService.RenderStepped:Connect(UpdateESP)
    else
        for _, drawings in ESP_Objects do
            drawings.box:Remove()
            drawings.tracer:Remove()
        end
        ESP_Objects = {}
    end
end
-- Movement (same)
local function ToggleFly(state)
    Settings.Fly = state
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    if FlyBodyVelocity then FlyBodyVelocity:Destroy() end
   
    if state and LocalPlayer.Character then
        local hrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            FlyBodyVelocity = Instance.new("BodyVelocity")
            FlyBodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
            FlyBodyVelocity.Velocity = Vector3.new()
            FlyBodyVelocity.Parent = hrp
           
            FlyConnection = RunService.Heartbeat:Connect(function()
                local move = Vector3.new()
                local camCf = Camera.CFrame
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + camCf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - camCf.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - camCf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + camCf.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.new(0,1,0) end
                FlyBodyVelocity.Velocity = move.Unit * Settings.FlySpeed
            end)
        end
    end
end
local noclipConn
local function ToggleNoClip(state)
    Settings.NoClip = state
    if noclipConn then noclipConn:Disconnect() end
    if state then
        noclipConn = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in LocalPlayer.Character:GetChildren() do
                    if part:IsA("BasePart") then part.CanCollide = false end
                end
            end
        end)
    end
end
local infJumpConn
local function ToggleInfJump(state)
    Settings.InfiniteJump = state
    if infJumpConn then infJumpConn:Disconnect() end
    if state then
        infJumpConn = UserInputService.JumpRequest:Connect(function()
            LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end)
    end
end
-- UI
do -- Combat
    local Sec = Tabs.Combat:AddSection("Silent Aim (Fixed)")
    Sec:AddToggle("SilentAim", {Title = "Silent Aim", Default = false, Callback = ToggleSilentAim})
    Sec:AddToggle("TeamCheck", {Title = "Team Check", Default = true, Callback = function(v) Settings.TeamCheck = v end})
    Sec:AddToggle("VisibleCheck", {Title = "Visible Only", Default = false, Callback = function(v) Settings.VisibleCheck = v end})
    Sec:AddDropdown("AimPart", {
        Title = "Aim Part", Values = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"},
        Default = "Head", Callback = function(v) Settings.AimPart = v end
    })
    Sec:AddSlider("FOV", {Title = "FOV Radius", Default = 150, Min = 50, Max = 300, Callback = function(v)
        Settings.FOV = v
        FOVCircle.Radius = v
    end})
    Sec:AddToggle("ShowFOV", {Title = "Show FOV Circle", Default = false, Callback = function(v)
        FOVCircle.Visible = v
        if ESPConnection then FOVCircle.Visible = v end -- Update in loop if needed
    end})
end
do -- Visual
    local Sec = Tabs.Visual:AddSection("ESP")
    Sec:AddToggle("ESP", {Title = "Enable ESP", Default = false, Callback = ToggleESP})
    Sec:AddToggle("Boxes", {Title = "Boxes", Default = true, Callback = function(v) Settings.Boxes = v end})
    Sec:AddToggle("Tracers", {Title = "Tracers", Default = true, Callback = function(v) Settings.Tracers = v end})
end
do -- Movement
    local Sec = Tabs.Movement:AddSection("Movement")
    Sec:AddToggle("Fly", {Title = "Fly (WASD Space Ctrl)", Default = false, Callback = ToggleFly})
    Sec:AddSlider("FlySpeed", {Title = "Speed", Default = 60, Min = 16, Max = 200, Callback = function(v) Settings.FlySpeed = v end})
    Sec:AddToggle("NoClip", {Title = "NoClip", Default = false, Callback = ToggleNoClip})
    Sec:AddToggle("InfJump", {Title = "Infinite Jump", Default = false, Callback = ToggleInfJump})
end
do -- Misc (Hitbox Fixed!)
    local Sec = Tabs.Misc:AddSection("Hitbox Expander (Fixed)")
    Sec:AddToggle("Hitbox", {Title = "Enable (LowerTorso + HRP)", Default = false, Callback = ToggleHitbox})
    Sec:AddSlider("Size", {Title = "Size (20-30)", Default = 25, Min = 10, Max = 40, Rounding = 1, Callback = function(v)
        Settings.HitboxSize = v
    end})
end
-- Init ESP objs for existing
for _, p in Players:GetPlayers() do CreateESP(p) end
-- FOV Update
RunService.RenderStepped:Connect(function()
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end)
-- Auto-update hitbox on respawn
LocalPlayer.CharacterAdded:Connect(function() task.wait(1) if Settings.HitboxExpander then UpdateHitboxes() end end)
Fluent:Notify({
    Title = "Fixed!",
    Content = "Silent Aim (HitPart hook) + Arsenal Hitbox (Torso/HRP)\nBased on GitHub open-source (TestForCry, Exunys)",
    Duration = 6
})
print("loaded / rightshift toggle")
