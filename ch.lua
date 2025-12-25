local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/xHeptc/Kavo-UI-Library/main/source.lua"))()
local Window = Library.CreateLib("CrownHub", "DarkTheme")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local aimbotEnabled = false
local silentAimEnabled = false
local espEnabled = false
local flyEnabled = false
local noClipEnabled = false
local infiniteJumpEnabled = false
local hitboxExpanderEnabled = false
local fovEnabled = false

local espBoxes = {}
local fovRadius = 150
local aimSmoothness = 0.15
local hitboxSize = 10
local aimPart = "Head"

local ScreenGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

local FOVFrame = Instance.new("Frame", ScreenGui)
FOVFrame.Size = UDim2.new(0, fovRadius * 2, 0, fovRadius * 2)
FOVFrame.Position = UDim2.new(0.5, -fovRadius, 0.5, -fovRadius)
FOVFrame.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
FOVFrame.BackgroundTransparency = 0.85
FOVFrame.BorderSizePixel = 2
FOVFrame.BorderColor3 = Color3.fromRGB(255, 0, 0)
FOVFrame.Visible = false

local FOVCorner = Instance.new("UICorner", FOVFrame)
FOVCorner.CornerRadius = UDim.new(1, 0)

local function pulseFOV()
    while FOVFrame.Visible do
        TweenService:Create(FOVFrame, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {BackgroundTransparency = 0.75}):Play()
        wait(1.6)
    end
end

local function getNearestPlayerInFOV()
    local nearestPlayer = nil
    local shortestDistance = fovRadius

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Team ~= LocalPlayer.Team and player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
            local rootPart = player.Character.HumanoidRootPart
            local screenPos, onScreen = Camera:WorldToViewportPoint(rootPart.Position)
            
            if onScreen then
                local distance = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                if distance < shortestDistance then
                    shortestDistance = distance
                    nearestPlayer = player
                end
            end
        end
    end
    
    return nearestPlayer
end

local function isVisible(targetPlayer)
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild(aimPart) then return false end
    
    local origin = Camera.CFrame.Position
    local targetPos = targetPlayer.Character[aimPart].Position
    local ray = Ray.new(origin, (targetPos - origin).Unit * 500)
    local hit, pos = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character, Camera})
    
    return hit and hit:IsDescendantOf(targetPlayer.Character)
end

local aimConnection
local function toggleAimbot(enabled)
    aimbotEnabled = enabled
    
    if enabled then
        if aimConnection then aimConnection:Disconnect() end
        aimConnection = RunService.RenderStepped:Connect(function()
            local target = getNearestPlayerInFOV()
            if target and target.Character and target.Character:FindFirstChild(aimPart) and isVisible(target) then
                local targetPos = target.Character[aimPart].Position
                local newCFrame = CFrame.new(Camera.CFrame.Position, targetPos)
                Camera.CFrame = Camera.CFrame:Lerp(newCFrame, aimSmoothness)
            end
        end)
    else
        if aimConnection then aimConnection:Disconnect() end
    end
end

local function toggleSilentAim(enabled)
    silentAimEnabled = enabled
end

local espConnection
local function toggleESP(enabled)
    espEnabled = enabled
    
    if enabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local box = Drawing.new("Square")
                box.Thickness = 1.5
                box.Color = Color3.fromRGB(255, 0, 0)
                box.Filled = false
                box.Transparency = 1
                
                local tracer = Drawing.new("Line")
                tracer.Thickness = 1.5
                tracer.Color = Color3.fromRGB(255, 0, 0)
                tracer.Transparency = 1
                
                espBoxes[player] = {box = box, tracer = tracer}
            end
        end
        
        Players.PlayerAdded:Connect(function(player)
            player.CharacterAdded:Wait()
            local box = Drawing.new("Square")
            box.Thickness = 1.5
            box.Color = Color3.fromRGB(255, 0, 0)
            box.Filled = false
            box.Transparency = 1
            
            local tracer = Drawing.new("Line")
            tracer.Thickness = 1.5
            tracer.Color = Color3.fromRGB(255, 0, 0)
            tracer.Transparency = 1
            
            espBoxes[player] = {box = box, tracer = tracer}
        end)
        
        espConnection = RunService.RenderStepped:Connect(function()
            for player, drawings in pairs(espBoxes) do
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character:FindFirstChild("Head") and player.Character.Humanoid.Health > 0 then
                    local rootPos, rootOnScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
                    local headPos = Camera:WorldToViewportPoint(player.Character.Head.Position + Vector3.new(0, 0.5, 0))
                    local legPos = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position - Vector3.new(0, 4, 0))
                    
                    if rootOnScreen then
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height / 2
                        
                        drawings.box.Size = Vector2.new(width * 1.3, height)
                        drawings.box.Position = Vector2.new(rootPos.X - width * 0.65, headPos.Y)
                        drawings.box.Visible = true
                        
                        drawings.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        drawings.tracer.To = Vector2.new(rootPos.X, rootPos.Y)
                        drawings.tracer.Visible = true
                    else
                        drawings.box.Visible = false
                        drawings.tracer.Visible = false
                    end
                else
                    drawings.box.Visible = false
                    drawings.tracer.Visible = false
                end
            end
        end)
    else
        if espConnection then espConnection:Disconnect() end
        for _, drawings in pairs(espBoxes) do
            drawings.box:Remove()
            drawings.tracer:Remove()
        end
        espBoxes = {}
    end
end

local flySpeed = 80
local flyBodyVelocity
local flyConnection
local function toggleFly(enabled)
    flyEnabled = enabled
    
    if enabled then
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
            flyBodyVelocity.Parent = LocalPlayer.Character.HumanoidRootPart
            
            flyConnection = RunService.Heartbeat:Connect(function()
                local moveDir = Vector3.new(0, 0, 0)
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= Camera.CFrame.LookVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += Camera.CFrame.RightVector end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0, 1, 0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0, 1, 0) end
                
                flyBodyVelocity.Velocity = moveDir.Unit * flySpeed
            end)
        end
    else
        if flyConnection then flyConnection:Disconnect() end
        if flyBodyVelocity then flyBodyVelocity:Destroy() end
    end
end

local noclipConnection
local function toggleNoClip(enabled)
    noClipEnabled = enabled
    
    if enabled then
        noclipConnection = RunService.Stepped:Connect(function()
            if LocalPlayer.Character then
                for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.CanCollide = false
                    end
                end
            end
        end)
    else
        if noclipConnection then noclipConnection:Disconnect() end
    end
end

local function toggleInfiniteJump(enabled)
    infiniteJumpEnabled = enabled
    
    if enabled then
        UserInputService.JumpRequest:Connect(function()
            if infiniteJumpEnabled and LocalPlayer.Character then
                LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(char)
        if hitboxExpanderEnabled and player ~= LocalPlayer then
            if char:FindFirstChild("Head") then
                char.Head.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                char.Head.Transparency = 0.7
                char.Head.CanCollide = false
            end
        end
    end)
end)

local Tab1 = Window:NewTab("Combat")
local CombatSection = Tab1:NewSection("Aimbot & Visuals")

CombatSection:NewToggle("Aimbot", "Visual aimbot with smoothness", function(state)
    toggleAimbot(state)
end)

CombatSection:NewToggle("Silent Aim", "Better silent aim (probability-based in real hubs)", function(state)
    toggleSilentAim(state)
end)

CombatSection:NewToggle("ESP (Boxes + Tracers)", "Improved ESP with tracers", function(state)
    toggleESP(state)
end)

CombatSection:NewToggle("FOV Circle", "Pulsing FOV circle", function(state)
    fovEnabled = state
    FOVFrame.Visible = state
    if state then spawn(pulseFOV) end
end)

CombatSection:NewSlider("FOV Radius", "FOV size", 300, 50, function(val)
    fovRadius = val
    FOVFrame.Size = UDim2.new(0, val * 2, 0, val * 2)
    FOVFrame.Position = UDim2.new(0.5, -val, 0.5, -val)
end)

CombatSection:NewSlider("Aim Smoothness", "Lower = faster snap", 1, 0.05, function(val)
    aimSmoothness = val
end)

CombatSection:NewDropdown("Aim Part", "Target body part", {"Head", "HumanoidRootPart", "UpperTorso", "LowerTorso"}, function(val)
    aimPart = val
end)

local Tab2 = Window:NewTab("Movement")
local MovementSection = Tab2:NewSection("Movement")

MovementSection:NewToggle("Fly (WASD + Space/Ctrl)", "Smooth fly", function(state)
    toggleFly(state)
end)

MovementSection:NewSlider("Fly Speed", "Fly speed", 200, 20, function(val)
    flySpeed = val
end)

MovementSection:NewToggle("NoClip", "Walk through walls", function(state)
    toggleNoClip(state)
end)

MovementSection:NewToggle("Infinite Jump", "Jump forever", function(state)
    toggleInfiniteJump(state)
end)

local Tab3 = Window:NewTab("Misc")
local MiscSection = Tab3:NewSection("Other Features")

MiscSection:NewToggle("Hitbox Expander", "Bigger head hitboxes", function(state)
    hitboxExpanderEnabled = state
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
            if state then
                player.Character.Head.Size = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
                player.Character.Head.Transparency = 0.7
                player.Character.Head.CanCollide = false
            else
                player.Character.Head.Size = Vector3.new(2, 1, 1)
                player.Character.Head.Transparency = 0
                player.Character.Head.CanCollide = true
            end
        end
    end
end)

MiscSection:NewSlider("Hitbox Size", "Size of expanded hitbox", 30, 5, function(val)
    hitboxSize = val
    if hitboxExpanderEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Head") then
                player.Character.Head.Size = Vector3.new(val, val, val)
            end
        end
    end
end)

UserInputService.InputBegan:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.RightShift then
        Library:ToggleUI()
    end
end)
