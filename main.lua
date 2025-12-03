-- Configuration
local espColor = Color3.new(1, 0, 0) -- Red
local chamsColor = Color3.new(1, 0, 0) -- Red
local uiBackgroundColor = Color3.fromRGB(50, 0, 50) -- Dark Purple
local uiTextColor = Color3.new(0.8, 0.8, 0.8) -- Light Gray
local buttonBackgroundColor = Color3.new(0, 0, 0) -- Black
local titleTextColor = Color3.fromRGB(0, 255, 0) -- Bright Green
local font = Enum.Font.GothamBlack
local defaultSpeed = 50 -- Default speed value
local minSpeed = 10
local maxSpeed = 100
local defaultFlySpeed = 50 -- Default fly speed value
local minFlySpeed = 10
local maxFlySpeed = 100

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()[1]
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Variables to track state
local espEnabled = false
local chamsEnabled = false
local uiVisible = true
local dragging = false
local dragStartPos
local frameStartPos
local scriptWorking = true -- Assume the script is working initially
local speedEnabled = false
local currentSpeed = defaultSpeed -- Current speed value
local flyEnabled = false
local currentFlySpeed = defaultFlySpeed
local infiniteJumpEnabled = false
local noclipEnabled = false

-- UI Elements
local screenGui
local frame
local espButton
local chamsButton
local statusDot
local speedButton
local speedSlider
local flyButton
local flySpeedSlider
local infiniteJumpButton
local noclipButton

-- Table to store Highlights
local playerHighlights = {}
local originalCollisionGroups = {}

--// Utility Functions //--

local function getPlayerHead(player)
    local Character = player.Character or player.CharacterAdded:Wait()[1]
    return Character:FindFirstChild("Head")
end

local function createNameBillboard(player)
    local head = getPlayerHead(player)
    if not head then return end

    local BillboardGui = Instance.new("BillboardGui")
    BillboardGui.Name = "NameBillboard"
    BillboardGui.AlwaysOnTop = true
    BillboardGui.Size = UDim2.new(0, 150, 0, 20) -- Reduced size
    BillboardGui.StudsOffset = Vector3.new(0, 2, 0)
    BillboardGui.Parent = head

    local NameLabel = Instance.new("TextLabel")
    NameLabel.BackgroundTransparency = 1.0
    NameLabel.Size = UDim2.new(1, 0, 1, 0)
    NameLabel.Font = font
    NameLabel.TextScaled = true
    NameLabel.TextColor3 = espColor -- Red
    NameLabel.Text = player.Name
    NameLabel.Parent = BillboardGui

    return BillboardGui
end

local function applyChams(character, color)
    if not character then return end

    for _, child in pairs(character:GetDescendants()) do
        if child:IsA("BasePart") then
            local originalColor = child:GetAttribute("OriginalColor")
            if not originalColor then
                child:SetAttribute("OriginalColor", child.Color)
            end

            if not child:IsA("MeshPart") then
                child.Color = color
                local mesh = child:FindFirstChild("SpecialMesh")
                if mesh then
                    mesh:Destroy()
                end
            else
                local mesh = child:FindFirstChild("SpecialMesh")
                if not mesh then
                    mesh = Instance.new("SpecialMesh")
                    mesh.Name = "ChamMesh"
                    mesh.MeshType = Enum.MeshType.FileMesh
                    mesh.MeshId = "rbxassetid://0"
                    mesh.TextureId = ""
                    mesh.Parent = child
                end
                child.Color = color
            end
        end
    end

    -- Create a red Highlight around the player
    local highlight = Instance.new("Highlight")
    highlight.Name = "ChamHighlight"
    highlight.FillColor = chamsColor
    highlight.OutlineColor = chamsColor
    highlight.Parent = character

    playerHighlights[character] = highlight
end

local function removeChams(character)
    if not character then return end

    for _, child in pairs(character:GetDescendants()) do
        if child:IsA("BasePart") then
            local originalColor = child:GetAttribute("OriginalColor")
            if originalColor then
                child.Color = originalColor
                child:SetAttribute("OriginalColor", nil) -- Remove the attribute
            else
                child.Color = child.BrickColor.Color -- Use BrickColor as fallback
            end

            local mesh = child:FindFirstChild("SpecialMesh")
            if mesh then
                mesh:Destroy()
            end
        end
    end

    -- Destroy Highlight object
    local highlight = playerHighlights[character]
    if highlight then
        highlight:Destroy()
        playerHighlights[character] = nil
    end
end

-- Function to toggle ESP
local function toggleESP()
    espEnabled = not espEnabled
    if espEnabled then
        for _, player in Players:GetPlayers() do
            local head = getPlayerHead(player)
            if head then
                createNameBillboard(player)
            end
        end
        espButton.Text = "ESP: On"
    else
        for _, player in Players:GetPlayers() do
            local head = getPlayerHead(player)
            if head then
                local billboard = head:FindFirstChild("NameBillboard")
                if billboard then
                    billboard:Destroy()
                end
            end
        end
        espButton.Text = "ESP: Off"
    end
end

-- Function to toggle Chams
local function toggleChams()
    chamsEnabled = not chamsEnabled
    if chamsEnabled then
        for _, player in Players:GetPlayers() do
            local character = player.Character
            if character then
                applyChams(character, chamsColor)
            end
        end
        chamsButton.Text = "Chams: On"
    else
        for _, player in Players:GetPlayers() do
            local character = player.Character
            if character then
                removeChams(character)
            end
        end
        chamsButton.Text = "Chams: Off"
    end
end

-- Function to toggle speed
local function toggleSpeed()
    speedEnabled = not speedEnabled
    if speedEnabled then
        Humanoid.WalkSpeed = currentSpeed
        speedButton.Text = "Speed: On"
    else
        Humanoid.WalkSpeed = 16 -- Default WalkSpeed
        speedButton.Text = "Speed: Off"
    end
end

-- Function to set speed from slider value
local function setSpeed(value)
    currentSpeed = minSpeed + (maxSpeed - minSpeed) * value
    if speedEnabled then
        Humanoid.WalkSpeed = currentSpeed
    end
end

-- Function to toggle fly
local function toggleFly()
    flyEnabled = not flyEnabled
    Humanoid.WalkSpeed = speedEnabled and currentSpeed or 16

    if flyEnabled then
        flyButton.Text = "Fly: On"
        Humanoid.JumpPower = 0
        Humanoid.UseJumpPower = false
        RootPart.Velocity = Vector3.new(0,0,0)

    else
        flyButton.Text = "Fly: Off"
        Humanoid.JumpPower = 50
        Humanoid.UseJumpPower = true
    end
end

-- Function to set fly speed from slider value
local function setFlySpeed(value)
    currentFlySpeed = minFlySpeed + (maxFlySpeed - minFlySpeed) * value
end

-- Function to move the player when flying is enabled
local function updateFly()
    if flyEnabled then
        RootPart.Velocity = Vector3.new(0,0,0)
        local direction = Vector3.new(0,0,0)

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            direction = direction + RootPart.CFrame.LookVector
        elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
            direction = direction - RootPart.CFrame.LookVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            direction = direction - RootPart.CFrame.RightVector
        elseif UserInputService:IsKeyDown(Enum.KeyCode.D) then
            direction = direction + RootPart.CFrame.RightVector
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0,1,0)
        elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            direction = direction - RootPart.CFrame.LeftVector
        end

        RootPart.Velocity = direction.Unit * currentFlySpeed

    end
end

-- Function to toggle Infinite Jump
local function toggleInfiniteJump()
    infiniteJumpEnabled = not infiniteJumpEnabled
    if infiniteJumpEnabled then
        infiniteJumpButton.Text = "Infinite Jump: On"
    else
        infiniteJumpButton.Text = "Infinite Jump: Off"
    end
end

-- Override the default jump
local oldJump = Humanoid.Jump
Humanoid.Jump = function()
    if infiniteJumpEnabled then
        RootPart.Velocity = Vector3.new(0, 50, 0)
    else
        oldJump(Humanoid)
    end
end

-- Function to toggle Noclip
local function toggleNoclip()
    noclipEnabled = not noclipEnabled
    local collisionGroupName = noclipEnabled and "NoClip" or "Default"
    noclipButton.Text = "NoClip: " .. (noclipEnabled and "On" or "Off")

    for _, part in pairs(Character:GetDescendants()) do
        if part:IsA("BasePart") then
            local originalGroup = originalCollisionGroups[part]
            if noclipEnabled then
                -- Save the original collision group and set to NoClip
                originalCollisionGroups[part] = part.CollisionGroup
                part.CollisionGroup = "NoClip"
            else
                -- Restore the original collision group
                part.CollisionGroup = originalGroup or "Default"
                originalCollisionGroups[part] = nil
            end
        end
    end
end

-- Function to toggle UI visibility
local function toggleUIVisibility()
    uiVisible = not uiVisible
    screenGui.Enabled = uiVisible
end

-- Function to create the UI
local function createUI()
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TheBronx3UI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = game.Players.LocalPlayer.PlayerGui

    frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 310) -- Increased height
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.BackgroundColor3 = uiBackgroundColor
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    frame.ClipsDescendants = true -- Prevent elements from overflowing

    -- UI Corner for rounded edges
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 5)
    UICorner.Parent = frame

    -- Title Label
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundColor3 = uiBackgroundColor
    titleLabel.TextColor3 = titleTextColor -- Bright Green
    titleLabel.Font = font
    titleLabel.Text = "The Bronx 3"
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.TextYAlignment = Enum.TextYAlignment.Center
    titleLabel.TextSize = 16
    titleLabel.BorderSizePixel = 0
    titleLabel.Parent = frame

    -- Status Dot
    statusDot = Instance.new("ImageLabel")
    statusDot.Size = UDim2.new(0, 16, 0, 16)
    statusDot.Position = UDim2.new(0, 5, 0, 3) -- Positioned to the right of the title
    statusDot.BackgroundTransparency = 1
    statusDot.Image = "rbxassetid://602342692" -- Replace with a green dot asset ID
    statusDot.Parent = frame

    -- Function to update status dot color
    local function updateStatusDot()
        if scriptWorking then
            statusDot.ImageColor3 = Color3.new(0, 1, 0) -- Green
        else
            statusDot.ImageColor3 = Color3.new(1, 0, 0) -- Red
        end
    end

    updateStatusDot() -- Set initial status

    local function createButton(text, yPos, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, -10, 0, 30)
        button.Position = UDim2.new(0, 5, 0, yPos)
        button.BackgroundColor3 = buttonBackgroundColor -- Black button
        button.TextColor3 = uiTextColor
        button.Font = font
        button.Text = text
        button.BorderSizePixel = 0
        button.Parent = frame

        -- Button hover effect
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = uiTextColor -- White on hover
            button.TextColor3 = buttonBackgroundColor
        end)

        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = buttonBackgroundColor -- Revert to black
            button.TextColor3 = uiTextColor
        end)

        button.MouseButton1Click:Connect(callback)

        local UICorner = Instance.new("UICorner")
        UICorner.CornerRadius = UDim.new(0, 3)
        UICorner.Parent = button

        return button
    end

    espButton = createButton("ESP: Off", 30, toggleESP)
    chamsButton = createButton("Chams: Off", 70, toggleChams)
    speedButton = createButton("Speed: Off", 110, toggleSpeed) -- New button
    flyButton = createButton("Fly: Off", 150, toggleFly)
    infiniteJumpButton = createButton("Infinite Jump: Off", 190, toggleInfiniteJump)
    noclipButton = createButton("NoClip: Off", 230, toggleNoclip)

    -- Speed Slider
    speedSlider = Instance.new("Slider")
    speedSlider.Size = UDim2.new(1, -10, 0, 20)
    speedSlider.Position = UDim2.new(0, 5, 0, 90) -- Positioned below the speed button
    speedSlider.BackgroundColor3 = uiBackgroundColor
    speedSlider.BorderColor3 = uiTextColor
    speedSlider.Value = (defaultSpeed - minSpeed) / (maxSpeed - minSpeed)
    speedSlider.Parent = frame
    speedSlider.Visible = false
    speedSlider.Changed:Connect(function()
        setSpeed(speedSlider.Value)
    end)

     -- Fly Speed Slider
    flySpeedSlider = Instance.new("Slider")
    flySpeedSlider.Size = UDim2.new(1, -10, 0, 20)
    flySpeedSlider.Position = UDim2.new(0, 5, 0, 270)
    flySpeedSlider.BackgroundColor3 = uiBackgroundColor
    flySpeedSlider.BorderColor3 = uiTextColor
    flySpeedSlider.Value = (defaultFlySpeed - minFlySpeed) / (maxFlySpeed - minFlySpeed)
    flySpeedSlider.Parent = frame
    flySpeedSlider.Changed:Connect(function()
        setFlySpeed(flySpeedSlider.Value)
    end)

    -- Enable dragging on left mouse click
    frame.InputBegan:Connect(function(input, gameProcessedEvent)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStartPos = input.Position
            frameStartPos = Vector2.new(frame.Position.X.Scale, frame.Position.Y.Scale)
        end
    end)

    frame.InputEnded:Connect(function(input, gameProcessedEvent)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

-- Function to toggle UI visibility
local function toggleUIVisibility()
    uiVisible = not uiVisible
    screenGui.Enabled = uiVisible
end

-- Keybind for minimizing UI
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end
    if input.KeyCode == Enum.KeyCode.M then
        toggleUIVisibility()
    end
end)

-- Update the frame position while dragging
RunService.RenderStepped:Connect(function()
    if dragging then
        local mousePos = UserInputService:GetMouseLocation()
        local delta = mousePos - dragStartPos
        frame.Position = UDim2.new(frameStartPos.X, delta.X, frameStartPos.Y, delta.Y)
    end
    updateFly()
end)

-- Initial setup
createUI()

-- Apply default speed on script start
if speedEnabled then
    Humanoid.WalkSpeed = currentSpeed
end

-- Create NoClip CollisionGroup if it doesn't exist
local physicsService = game:GetService("PhysicsService")
if not physicsService:GetCollisionGroupName("NoClip") then
    physicsService:CreateCollisionGroup("NoClip")
    physicsService:CollisionGroupSetCollidable("NoClip", false)
end

-- Override the default jump
local oldJump = Humanoid.Jump
Humanoid.Jump = function()
    if infiniteJumpEnabled then
        RootPart.Velocity = Vector3.new(0, 50, 0)
    else
        oldJump(Humanoid)
    end
end
