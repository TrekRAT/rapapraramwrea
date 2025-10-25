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
local TOGGLE_KEY = Enum.KeyCode.P
local TELEPORT_KEY = Enum.KeyCode.J  -- J key for teleporting TouchGivers

-- State
local ESPEnabled = true
local TargetLock = nil
local RightMouseDown = false

-- Team colors
local TeamColors = {
    Police = Color3.fromRGB(0, 0, 255),
    Criminals = Color3.fromRGB(255, 0, 0),
    Inmates = Color3.fromRGB(0, 255, 0)
}

-- Table to store ESP data
local PlayerESP = {}

-- TouchGiver teleport function
local function teleportAllTouchGivers()
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Find all TouchGiver objects in workspace
    local touchGivers = {}
    
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj.Name == "TouchGiver" then
            table.insert(touchGivers, {
                object = obj,
                originalCFrame = obj:GetPivot()
            })
        end
    end
    
    if #touchGivers == 0 then
        warn("No TouchGiver objects found in workspace!")
        return
    end
    
    print("Found " .. #touchGivers .. " TouchGiver objects")
    
    -- Enable noclip for player
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    
    -- Teleport each TouchGiver one by one with small delays
    for i, touchGiverData in pairs(touchGivers) do
        -- Teleport to player's position
        touchGiverData.object:PivotTo(CFrame.new(humanoidRootPart.Position))
        
        -- Wait a bit for the touch event to trigger
        wait(0.1)
        
        -- Return to original position immediately
        touchGiverData.object:PivotTo(touchGiverData.originalCFrame)
        
        -- Small delay before next one
        if i < #touchGivers then
            wait(0.1)
        end
    end
    
    -- Re-enable collision for player
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = true
        end
    end
    
    print("TouchGiver teleportation complete!")
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
    elseif input.KeyCode == TELEPORT_KEY then  -- J key for teleporting TouchGivers
        teleportAllTouchGivers()
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
end)

-- Auto-refresh
while true do
    wait(3)
    if ESPEnabled then
        setupAllPlayers()
    end
end
---Spammer

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local originalPosition = nil
local isSpamming = false
local spamConnection = nil

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MeleeGUI"
screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")

-- Create Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 200)
mainFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Selectable = true
mainFrame.Parent = screenGui

-- Add corner rounding
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

-- Close Button (X)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 25, 0, 25)
closeButton.Position = UDim2.new(1, -30, 0, 5)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Text = "X"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeButton

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 40)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Text = "Melee Event Spammer"
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = title

-- Username Input Label
local usernameLabel = Instance.new("TextLabel")
usernameLabel.Size = UDim2.new(0.8, 0, 0, 20)
usernameLabel.Position = UDim2.new(0.1, 0, 0.25, 0)
usernameLabel.BackgroundTransparency = 1
usernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
usernameLabel.Text = "Enter Target Username:"
usernameLabel.Font = Enum.Font.Gotham
usernameLabel.TextSize = 14
usernameLabel.TextXAlignment = Enum.TextXAlignment.Left
usernameLabel.Parent = mainFrame

-- Username TextBox
local usernameBox = Instance.new("TextBox")
usernameBox.Size = UDim2.new(0.8, 0, 0, 35)
usernameBox.Position = UDim2.new(0.1, 0, 0.4, 0)
usernameBox.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
usernameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
usernameBox.PlaceholderColor3 = Color3.fromRGB(180, 180, 180)
usernameBox.PlaceholderText = "Type username here..."
usernameBox.Text = ""
usernameBox.Font = Enum.Font.Gotham
usernameBox.TextSize = 14
usernameBox.Parent = mainFrame

local boxCorner = Instance.new("UICorner")
boxCorner.CornerRadius = UDim.new(0, 6)
boxCorner.Parent = usernameBox

-- Toggle Button
local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.6, 0, 0, 40)
toggleButton.Position = UDim2.new(0.2, 0, 0.7, 0)
toggleButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "START SPAMMING"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.Parent = mainFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = toggleButton

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.8, 0, 0, 20)
statusLabel.Position = UDim2.new(0.1, 0, 0.85, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.Text = "Status: Stopped"
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 12
statusLabel.Parent = mainFrame

-- Function to find player by username
local function findPlayerByName(username)
    if not username or username == "" then return nil end
    
    local allPlayers = Players:GetPlayers()
    for _, player in pairs(allPlayers) do
        if player.Name:lower() == username:lower() or player.DisplayName:lower() == username:lower() then
            return player
        end
    end
    return nil
end

-- Function to position directly under target (8 studs below)
local function positionUnderTarget(targetPlayer)
    if not targetPlayer or not targetPlayer.Character then return false end
    
    local targetChar = targetPlayer.Character
    local localChar = localPlayer.Character
    
    if not localChar or not targetChar:FindFirstChild("HumanoidRootPart") then return false end
    
    local targetRoot = targetChar.HumanoidRootPart
    local localRoot = localChar:FindFirstChild("HumanoidRootPart")
    
    if localRoot then
        -- Position directly under the target 
        local hiddenPosition = targetRoot.Position - Vector3.new(0, 8, 0)
        localRoot.CFrame = CFrame.new(hiddenPosition)
        return true
    end
    return false
end

-- Function to restore original position
local function restoreOriginalPosition()
    if originalPosition and localPlayer.Character then
        local localChar = localPlayer.Character
        local localRoot = localChar:FindFirstChild("HumanoidRootPart")
        
        if localRoot then
            localRoot.CFrame = originalPosition
        end
    end
end

-- Spamming Logic
local function startSpamming()
    if isSpamming then return end
    
    local targetName = usernameBox.Text
    if not targetName or targetName == "" then
        statusLabel.Text = "Status: Enter a username!"
        return
    end
    
    local targetPlayer = findPlayerByName(targetName)
    if not targetPlayer then
        statusLabel.Text = "Status: Player not found!"
        return
    end
    
    if targetPlayer == localPlayer then
        statusLabel.Text = "Status: Can't target yourself!"
        return
    end
    
    -- Save original position
    if localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") then
        originalPosition = localPlayer.Character.HumanoidRootPart.CFrame
    end
    
    isSpamming = true
    toggleButton.BackgroundColor3 = Color3.fromRGB(60, 220, 60)
    toggleButton.Text = "STOP SPAMMING"
    statusLabel.Text = "Status: Spamming " .. targetPlayer.Name
    
    spamConnection = RunService.Heartbeat:Connect(function()
        -- Check if target still exists
        targetPlayer = findPlayerByName(targetName)
        if not targetPlayer or not targetPlayer.Parent then
            stopSpamming()
            statusLabel.Text = "Status: Target left the game"
            return
        end
        
        -- Wait for our character to exist if it respawned
        if not localPlayer.Character or not localPlayer.Character:FindFirstChild("HumanoidRootPart") then
            return -- Skip this frame, wait for character to load
        end
        
        -- Position under target (8 studs below)
        local success = positionUnderTarget(targetPlayer)
        if not success then
            statusLabel.Text = "Status: Can't reach target"
            return
        end
        
        -- Then send melee event
        local args = { targetPlayer }
        pcall(function()
            ReplicatedStorage:WaitForChild("meleeEvent"):FireServer(unpack(args))
        end)
    end)
end

local function stopSpamming()
    if not isSpamming then return end
    
    isSpamming = false
    toggleButton.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    toggleButton.Text = "START SPAMMING"
    statusLabel.Text = "Status: Stopped"
    
    -- Restore original position
    restoreOriginalPosition()
    
    if spamConnection then
        spamConnection:Disconnect()
        spamConnection = nil
    end
end

-- Close GUI function
local function closeGUI()
    stopSpamming()
    screenGui:Destroy()
end

-- Event Connections
toggleButton.MouseButton1Click:Connect(function()
    if isSpamming then
        stopSpamming()
    else
        startSpamming()
    end
end)

-- Close button click
closeButton.MouseButton1Click:Connect(closeGUI)

-- Enter key to start/stop
usernameBox.FocusLost:Connect(function(enterPressed)
    if enterPressed and not isSpamming then
        startSpamming()
    end
end)

-- Handle character respawns without stopping
localPlayer.CharacterAdded:Connect(function()
    if isSpamming then
        -- Just update the status, don't stop spamming
        statusLabel.Text = "Status: Spamming " .. usernameBox.Text .. " (respawning...)"
        
        -- Wait a moment for character to fully load, then continue
        wait(2)
        if isSpamming then
            statusLabel.Text = "Status: Spamming " .. usernameBox.Text
        end
    end
end)

-- Make the title bar draggable (alternative method for better dragging)
local dragging
local dragInput
local dragStart
local startPos

local function update(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

title.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        update(input)
    end
end)

print("Script loaded successfully!")
print("P - Toggle ESP")
print("J - Teleport TouchGivers")
print("Right Click - Activate Aimbot")

