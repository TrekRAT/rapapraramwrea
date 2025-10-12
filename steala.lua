-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

-- Settings
local AIM_FOV = 50
local AIM_SPEED = 0.3        -- Faster since no anti-cheat
local MAX_DISTANCE = 500
local ESP_FILL_TRANSPARENCY = 0.5
local TOGGLE_KEY = Enum.KeyCode.F
local WALL_KEY = Enum.KeyCode.J  -- New keybind for wall

-- State
local ESPEnabled = true
local TargetLock = nil
local RightMouseDown = false
local WallVisible = false
local OriginalM4A1Properties = nil

-- Team colors
local TeamColors = {
    Police = Color3.fromRGB(0, 0, 255),
    Criminals = Color3.fromRGB(255, 0, 0),
    Inmates = Color3.fromRGB(0, 255, 0)
}

-- Table to store ESP data
local PlayerESP = {}

-- Save original M4A1 properties
local function saveOriginalProperties()
    local m4a1 = Workspace:FindFirstChild("M4A1")
    if m4a1 and m4a1:IsA("Part") then
        OriginalM4A1Properties = {
            Size = m4a1.Size,
            Transparency = m4a1.Transparency,
            CanCollide = m4a1.CanCollide,
            Anchored = m4a1.Anchored,
            Material = m4a1.Material,
            Color = m4a1.Color,
            CFrame = m4a1.CFrame
        }
    end
end

-- Create M4A1 Wall function (modify the original)
local function createM4A1Wall()
    local m4a1 = Workspace:FindFirstChild("M4A1")
    if not m4a1 then
        warn("M4A1 not found in workspace")
        return
    end
    
    -- Save original properties if not already saved
    if not OriginalM4A1Properties then
        saveOriginalProperties()
    end
    
    -- Apply wall properties to the original M4A1
    m4a1.Transparency = 1  -- Fully transparent
    m4a1.CanCollide = false  -- No collision
    m4a1.Size = Vector3.new(400, 0.3, 2048)  -- Your specified size
    m4a1.Anchored = true  -- Keep it in place
    m4a1.Material = Enum.Material.Neon  -- Make it glow
    m4a1.Color = Color3.fromRGB(0, 255, 255)  -- Cyan color
    
    -- Position the wall in front of the player
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local rootPart = character.HumanoidRootPart
        local lookVector = rootPart.CFrame.LookVector
        
        -- Position wall 20 studs in front of player
        m4a1.CFrame = CFrame.new(
            rootPart.Position + (lookVector * 20),
            rootPart.Position + (lookVector * 100)
        )
    end
    
    WallVisible = true
    print("M4A1 transformed into Wall")
end

-- Remove M4A1 Wall function (restore original)
local function removeM4A1Wall()
    local m4a1 = Workspace:FindFirstChild("M4A1")
    if m4a1 and OriginalM4A1Properties then
        -- Restore original properties
        m4a1.Size = OriginalM4A1Properties.Size
        m4a1.Transparency = OriginalM4A1Properties.Transparency
        m4a1.CanCollide = OriginalM4A1Properties.CanCollide
        m4a1.Anchored = OriginalM4A1Properties.Anchored
        m4a1.Material = OriginalM4A1Properties.Material
        m4a1.Color = OriginalM4A1Properties.Color
        m4a1.CFrame = OriginalM4A1Properties.CFrame
    end
    
    WallVisible = false
    print("M4A1 restored to original")
end

-- Toggle M4A1 Wall function
local function toggleM4A1Wall()
    if WallVisible then
        removeM4A1Wall()
    else
        createM4A1Wall()
    end
end

-- Check if a player is an enemy
local function isEnemy(player)
    if not LocalPlayer.Team then return true end
    return player.Team ~= LocalPlayer.Team
end

-- Remove ESP safely
local function removeESP(player)
    if PlayerESP[player] then
        if PlayerESP[player].highlight then 
            PlayerESP[player].highlight:Destroy() 
        end
        if PlayerESP[player].billboard then 
            PlayerESP[player].billboard:Destroy() 
        end
        PlayerESP[player] = nil
    end
end

-- Create ESP for a player's character
local function createESP(player)
    if player == LocalPlayer then return end
    
    local function setupCharacter(character)
        removeESP(player)

        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end

        if isEnemy(player) then
            -- Highlight
            local highlight = Instance.new("Highlight")
            highlight.Name = "TeamHighlight"
            highlight.Adornee = character
            highlight.FillColor = (player.Team and TeamColors[player.Team.Name]) or Color3.new(1,1,1)
            highlight.FillTransparency = ESP_FILL_TRANSPARENCY
            highlight.OutlineColor = Color3.new(0,0,0)
            highlight.OutlineTransparency = 0.3
            highlight.Enabled = ESPEnabled
            highlight.Parent = character

            -- Billboard for HP/Distance
            local billboard = Instance.new("BillboardGui")
            billboard.Adornee = character:WaitForChild("HumanoidRootPart")
            billboard.Size = UDim2.new(0, 120, 0, 50)
            billboard.StudsOffset = Vector3.new(0, 3, 0)
            billboard.AlwaysOnTop = true
            billboard.Enabled = ESPEnabled

            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(1,0,1,0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextScaled = true
            textLabel.TextColor3 = (player.Team and TeamColors[player.Team.Name]) or Color3.new(1,1,1)
            textLabel.TextStrokeTransparency = 0
            textLabel.TextStrokeColor3 = Color3.new(0,0,0)
            textLabel.Parent = billboard
            billboard.Parent = CoreGui

            PlayerESP[player] = {
                highlight = highlight, 
                billboard = billboard, 
                humanoid = humanoid,
                character = character
            }

            humanoid.Died:Connect(function()
                removeESP(player)
                if TargetLock == player then
                    TargetLock = nil
                end
            end)
        end
    end

    if player.Character then
        setupCharacter(player.Character)
    end

    player.CharacterAdded:Connect(setupCharacter)
end

-- Setup all players
local function setupAllPlayers()
    for player in pairs(PlayerESP) do
        removeESP(player)
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            createESP(player)
        end
    end
end

-- Initialize
setupAllPlayers()

Players.PlayerAdded:Connect(function(player)
    createESP(player)
end)

Players.PlayerRemoving:Connect(function(player)
    removeESP(player)
    if TargetLock == player then
        TargetLock = nil
    end
end)

-- Simple FOV Circle
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "FOVGui"
FOVGui.ResetOnSpawn = false
FOVGui.Parent = CoreGui

local FOVCircle = Instance.new("Frame")
FOVCircle.Size = UDim2.new(0, AIM_FOV*2, 0, AIM_FOV*2)
FOVCircle.Position = UDim2.new(0.5, -AIM_FOV, 0.5, -AIM_FOV)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Visible = ESPEnabled

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(1, 0)
UICorner.Parent = FOVCircle

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(255, 255, 0)
UIStroke.Thickness = 2
UIStroke.Transparency = 0.3
UIStroke.Parent = FOVCircle

FOVCircle.Parent = FOVGui

-- Toggle ESP
local function toggleESP()
    ESPEnabled = not ESPEnabled
    FOVCircle.Visible = ESPEnabled
    
    for _, data in pairs(PlayerESP) do
        if data.highlight then data.highlight.Enabled = ESPEnabled end
        if data.billboard then data.billboard.Enabled = ESPEnabled end
    end
    
    if not ESPEnabled then
        TargetLock = nil
    else
        setupAllPlayers()
    end
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == TOGGLE_KEY then
        toggleESP()
    elseif input.KeyCode == WALL_KEY then  -- J key for wall
        toggleM4A1Wall()
    end
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RightMouseDown = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        RightMouseDown = false
        TargetLock = nil
        FOVCircle.UIStroke.Color = Color3.fromRGB(255, 255, 0)
    end
end)

-- Check if target is valid
local function isValidTarget(player)
    if not player or not PlayerESP[player] then return false end
    local data = PlayerESP[player]
    
    if not data.character or not data.character.Parent then return false end
    if not data.character:FindFirstChild("HumanoidRootPart") then return false end
    if not data.character:FindFirstChild("Head") then return false end
    if not data.humanoid or data.humanoid.Health <= 0 then return false end
    
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local distance = (data.character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
        if distance > MAX_DISTANCE then return false end
    end
    
    return true
end

-- Get closest target
local function getClosestTarget()
    local camera = Workspace.CurrentCamera
    local closest = nil
    local shortestDistance = AIM_FOV

    for player, data in pairs(PlayerESP) do
        if isEnemy(player) and isValidTarget(player) then
            local headPos, onScreen = camera:WorldToViewportPoint(data.character.Head.Position)
            
            if onScreen then
                local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
                local distanceFromCenter = (Vector2.new(headPos.X, headPos.Y) - screenCenter).Magnitude
                
                if distanceFromCenter <= AIM_FOV and distanceFromCenter < shortestDistance then
                    shortestDistance = distanceFromCenter
                    closest = player
                end
            end
        end
    end
    return closest
end

-- Direct aimbot (no anti-cheat precautions needed)
local function aimAtTarget()
    local camera = Workspace.CurrentCamera
    
    if not ESPEnabled or not LocalPlayer.Character then return end
    
    if RightMouseDown then
        if not isValidTarget(TargetLock) then
            TargetLock = getClosestTarget()
        end
        
        if TargetLock and isValidTarget(TargetLock) then
            local targetPos = PlayerESP[TargetLock].character.Head.Position
            camera.CFrame = CFrame.new(camera.CFrame.Position, targetPos) -- Direct snap
            FOVCircle.UIStroke.Color = Color3.fromRGB(255, 0, 0)
        else
            FOVCircle.UIStroke.Color = Color3.fromRGB(255, 165, 0)
        end
    else
        FOVCircle.UIStroke.Color = Color3.fromRGB(255, 255, 0)
        TargetLock = nil
    end
end

-- Update M4A1 Wall position to follow player
local function updateWallPosition()
    if WallVisible then
        local m4a1 = Workspace:FindFirstChild("M4A1")
        if m4a1 and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local rootPart = LocalPlayer.Character.HumanoidRootPart
            local lookVector = rootPart.CFrame.LookVector
            
            -- Update wall position to always be in front of player
            m4a1.CFrame = CFrame.new(
                rootPart.Position + (lookVector * 20),
                rootPart.Position + (lookVector * 100)
            )
        end
    end
end

-- Main loop
RunService.RenderStepped:Connect(function()
    -- Update ESP labels
    if ESPEnabled then
        for player, data in pairs(PlayerESP) do
            if isEnemy(player) and isValidTarget(player) and LocalPlayer.Character then
                local distance = (data.character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                if data.billboard then
                    data.billboard.Enabled = true
                    data.billboard.TextLabel.Text = string.format("%s\nHP: %d\nDist: %dm", player.Name, math.floor(data.humanoid.Health), math.floor(distance))
                end
            elseif data.billboard then
                data.billboard.Enabled = false
            end
        end
    end

    -- Aimbot
    if ESPEnabled then
        aimAtTarget()
    else
        FOVCircle.UIStroke.Color = Color3.fromRGB(255, 255, 0)
    end
    
    -- Update wall position if it exists
    if WallVisible then
        updateWallPosition()
    end
end)

-- Auto-refresh
while true do
    wait(3)
    if ESPEnabled then
        setupAllPlayers()
    end
end

print("Script loaded successfully!")
print("F - Toggle ESP")
print("J - Toggle M4A1 Wall")
print("Right Click - Activate Aimbot")
