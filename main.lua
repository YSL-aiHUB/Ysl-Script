--[[
    YSL Bá Sàn v21 Premium – Công Nghệ Đột Phá Cho iOS
    - AUTO FIRE FIX: Sử dụng Threading (task.spawn) + Tool:Activate() -> Bắn liên tục 0% khựng màn hình.
    - SNAPLINE STAR: Đính kèm ngôi sao xoay tròn ở cuối đường kẻ định vị.
    - PREMIUM UI: Hiệu ứng Blur nền, Âm thanh Click, Animation Quint mượt như lụa.
    - ID FIX: Trả lại ID nút mở (84705282139911) và dùng ID ảnh Ngôi Sao cho tâm.
    - Bổ sung FPS: Camera FOV Changer, Spinbot (Anti-Aim).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- ====== TẠO ÂM THANH UI ======
local uiSound = Instance.new("Sound")
uiSound.SoundId = "rbxassetid://6895079853" -- Tiếng click nhẹ, hiện đại
uiSound.Volume = 0.5
uiSound.Parent = SoundService

local function playClick()
    uiSound:Play()
end

-- ====== TRẠNG THÁI & THIẾT LẬP ======
local state = {
    aimbot = false, autoFire = false, hitboxExpander = false,
    espEnabled = false, showTargetMarker = true, snaplines = false,
    speed = false, infJump = false, fly = false, noclip = false, spinbot = false,
    fullbright = false, nofog = false, autoCollect = false, antiAFK = false,
}

local values = {
    aimbotSmoothing = 7, aimbotRange = 1000, predictionAmount = 0.12,
    aimPart = "Head", 
    wallCheck = true, teamCheck = false,
    autoFireInterval = 0.05,
    hitboxMult = 4, espMaxDistance = 2000,
    speedVal = 30, jumpVal = 80, flySpeed = 50, camFov = 70, spinSpeed = 50,
}

local connections = {}
local function addConnection(conn) table.insert(connections, conn) end
local function cleanupConnections()
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    connections = {}
end

local origAmbient = Lighting.Ambient
local origOutdoorAmbient = Lighting.OutdoorAmbient
local origFogEnd = Lighting.FogEnd

-- Hiệu ứng mờ nền
local menuBlur = Instance.new("BlurEffect")
menuBlur.Size = 0
menuBlur.Parent = Lighting

-- ====== HÀM TIỆN ÍCH AN TOÀN ======
local function getCharacter(plr) return plr and plr.Character or nil end
local function getHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") or nil end
local function isAlive(plr)
    local char = getCharacter(plr)
    local hum = getHumanoid(char)
    return hum and hum.Health > 0
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    if not values.teamCheck then return true end
    if player.Team and targetPlayer.Team then return player.Team ~= targetPlayer.Team end
    return true
end

local function getAimPart(char)
    if not char then return nil end
    if values.aimPart == "Head" then
        return char:FindFirstChild("Head")
    else
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
end

local function isVisible(targetPart)
    if not values.wallCheck then return true end
    if not targetPart or not targetPart.Parent then return false end
    
    local myChar = getCharacter(player)
    local origin = camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {myChar, camera, targetPart.Parent} 
    
    local direction = (targetPart.Position - origin).Unit * values.aimbotRange
    local result = Workspace:Raycast(origin, direction, raycastParams)
    return result == nil
end

-- ====== TÌM MỤC TIÊU ======
local currentAimbotTargetPart = nil
local lastFireTime = 0

local function updateNearestEnemy()
    local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestDist = math.huge
    local bestPart = nil
    
    local originPos = camera.CFrame.Position
    local myRoot = getCharacter(player) and getCharacter(player):FindFirstChild("HumanoidRootPart")
    if myRoot then originPos = myRoot.Position end 
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and isAlive(p) then
            local targetPart = getAimPart(getCharacter(p))
            if targetPart then
                local dist3D = (originPos - targetPart.Position).Magnitude
                if dist3D <= values.aimbotRange then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen and screenPos.Z > 0 then
                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if isVisible(targetPart) and screenDist < bestDist then
                            bestDist = screenDist
                            bestPart = targetPart
                        end
                    end
                end
            end
        end
    end
    currentAimbotTargetPart = bestPart
end

-- ====== AUTO FIRE FIX (KHÔNG GIẬT KHUNG HÌNH) ======
local function attack()
    local now = tick()
    if now - lastFireTime < values.autoFireInterval then return end
    lastFireTime = now
    
    local char = getCharacter(player)
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            -- Dùng task.spawn để không block thread, giúp vuốt mượt mà
            task.spawn(function()
                pcall(function() tool:Activate() end)
            end)
        end
    end
end

-- ====== TÂM ẢO NGÔI SAO DÙNG ID ẢNH ======
local targetMarker = Instance.new("BillboardGui")
targetMarker.Name = "YSL_StarMarker_Premium"
targetMarker.AlwaysOnTop = true
targetMarker.LightInfluence = 0
targetMarker.Enabled = false
targetMarker.Parent = playerGui

local markerImage = Instance.new("ImageLabel")
markerImage.Size = UDim2.new(1, 0, 1, 0)
markerImage.BackgroundTransparency = 1
markerImage.Image = "rbxassetid://12812239617" -- ID Ngôi sao sắc nét
markerImage.ImageColor3 = Color3.fromRGB(255, 30, 150)
markerImage.Parent = targetMarker

local markerRotation = 0
addConnection(RunService.RenderStepped:Connect(function(dt)
    if state.aimbot and state.showTargetMarker and currentAimbotTargetPart then
        targetMarker.Enabled = true
        targetMarker.Adornee = currentAimbotTargetPart
        
        if values.aimPart == "Head" then
            targetMarker.Size = UDim2.new(0, 35, 0, 35) 
            targetMarker.StudsOffset = Vector3.new(0, 0, 0)
        else
            targetMarker.Size = UDim2.new(0, 60, 0, 60)
            targetMarker.StudsOffset = Vector3.new(0, 0, 0)
        end
        
        markerRotation = markerRotation + (dt * 180)
        markerImage.Rotation = markerRotation
        
        local pulse = math.sin(tick() * 10) * 0.1 + 0.9
        markerImage.Size = UDim2.new(pulse, 0, pulse, 0)
    else
        targetMarker.Enabled = false
        targetMarker.Adornee = nil
    end
end))

-- ====== GIAO DIỆN PREMIUM ======
if playerGui:FindFirstChild("YSLBaSan_v21") then playerGui.YSLBaSan_v21:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "YSLBaSan_v21"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Nút Open Menu Viên Thuốc (Dùng ID ảnh của bạn)
local openMenuBtn = Instance.new("Frame")
openMenuBtn.Size = UDim2.new(0, 140, 0, 40)
openMenuBtn.Position = UDim2.new(0, 15, 0, 15)
openMenuBtn.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
openMenuBtn.Parent = gui
Instance.new("UICorner", openMenuBtn).CornerRadius = UDim.new(1, 0)

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 2
btnStroke.Parent = openMenuBtn
local btnUIGradient = Instance.new("UIGradient")
btnUIGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 150)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 50, 255))
}
btnUIGradient.Parent = btnStroke

-- ID ẢNH ROBLOX CỦA BẠN CHO MENU
local menuIcon = Instance.new("ImageLabel")
menuIcon.Size = UDim2.new(0, 28, 0, 28)
menuIcon.Position = UDim2.new(0, 8, 0.5, -14)
menuIcon.BackgroundTransparency = 1
menuIcon.Image = "rbxassetid://84705282139911"
menuIcon.Parent = openMenuBtn

local openText = Instance.new("TextLabel")
openText.Size = UDim2.new(1, -45, 1, 0)
openText.Position = UDim2.new(0, 42, 0, 0)
openText.BackgroundTransparency = 1
openText.Text = "MENU PRO"
openText.TextColor3 = Color3.new(1, 1, 1)
openText.Font = Enum.Font.GothamBold
openText.TextSize = 13
openText.TextXAlignment = Enum.TextXAlignment.Left
openText.Parent = openMenuBtn

local invisibleBtn = Instance.new("TextButton")
invisibleBtn.Size = UDim2.new(1, 0, 1, 0)
invisibleBtn.BackgroundTransparency = 1
invisibleBtn.Text = ""
invisibleBtn.Parent = openMenuBtn

local draggingBtn, dragBtnInput, dragBtnStart, startBtnPos
invisibleBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingBtn = true; dragBtnStart = input.Position; startBtnPos = openMenuBtn.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingBtn = false end end)
    end
end)
invisibleBtn.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragBtnInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragBtnInput and draggingBtn then
        local delta = input.Position - dragBtnStart
        openMenuBtn.Position = UDim2.new(startBtnPos.X.Scale, startBtnPos.X.Offset + delta.X, startBtnPos.Y.Scale, startBtnPos.Y.Offset + delta.Y)
    end
end)

-- Main Menu (Premium Compact)
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 320)
main.Position = UDim2.new(0.5, -240, 0.5, -160)
main.BackgroundColor3 = Color3.new(1, 1, 1) 
main.BorderSizePixel = 0
main.Visible = false
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 10, 20)), 
    ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 18, 40))  
}
mainGradient.Rotation = 45
mainGradient.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(150, 50, 255)
mainStroke.Thickness = 1.5
mainStroke.Parent = main

local menuScale = Instance.new("UIScale")
menuScale.Scale = 0
menuScale.Parent = main

local isMenuOpen = false
local function toggleMenu()
    isMenuOpen = not isMenuOpen
    playClick()
    if isMenuOpen then
        main.Visible = true
        TweenService:Create(menuScale, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()
        TweenService:Create(menuBlur, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {Size = 15}):Play()
    else
        local closeAnim = TweenService:Create(menuScale, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Scale = 0})
        closeAnim:Play()
        TweenService:Create(menuBlur, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = 0}):Play()
        closeAnim.Completed:Connect(function() if not isMenuOpen then main.Visible = false end end)
    end
end
invisibleBtn.MouseButton1Click:Connect(toggleMenu)

local draggingMain, dragMainInput, dragMainStart, startMainPos
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        draggingMain = true; dragMainStart = input.Position; startMainPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then draggingMain = false end end)
    end
end)
main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragMainInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragMainInput and draggingMain then 
        local delta = input.Position - dragMainStart
        main.Position = UDim2.new(startMainPos.X.Scale, startMainPos.X.Offset + delta.X, startMainPos.Y.Scale, startMainPos.Y.Offset + delta.Y)
    end
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sidebar.BackgroundTransparency = 0.5 
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local logoIcon = Instance.new("ImageLabel")
logoIcon.Size = UDim2.new(0, 24, 0, 24)
logoIcon.Position = UDim2.new(0, 12, 0, 12)
logoIcon.BackgroundTransparency = 1
logoIcon.Image = "rbxassetid://84705282139911"
logoIcon.Parent = sidebar

local menuTitleText = Instance.new("TextLabel")
menuTitleText.Size = UDim2.new(1, -45, 0, 48)
menuTitleText.Position = UDim2.new(0, 42, 0, 0)
menuTitleText.BackgroundTransparency = 1
menuTitleText.Text = "PREMIUM"
menuTitleText.TextColor3 = Color3.fromRGB(200, 100, 255) 
menuTitleText.Font = Enum.Font.GothamBlack
menuTitleText.TextSize = 13
menuTitleText.TextXAlignment = Enum.TextXAlignment.Left
menuTitleText.Parent = sidebar

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -130, 1, 0)
container.Position = UDim2.new(0, 130, 0, 0)
container.BackgroundTransparency = 1
container.Parent = main

local tabTitle = Instance.new("TextLabel")
tabTitle.Size = UDim2.new(1, -30, 0, 48)
tabTitle.Position = UDim2.new(0, 15, 0, 0)
tabTitle.BackgroundTransparency = 1
tabTitle.Text = "Ngắm Bắn"
tabTitle.TextColor3 = Color3.new(1, 1, 1)
tabTitle.Font = Enum.Font.GothamBold
tabTitle.TextSize = 18
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.Parent = container

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -20, 1, -50)
contentScroll.Position = UDim2.new(0, 10, 0, 48)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 2
contentScroll.CanvasSize = UDim2.new(0,0,0,0)
contentScroll.Parent = container

local tabs = {}
local tabContents = {}
local tabNames = {"Aiming", "Visual", "Movement", "Misc"}

for i, tName in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 34)
    btn.Position = UDim2.new(0, 8, 0, 50 + (i-1)*40)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(30, 20, 40)
    btn.Text = "  " .. tName
    btn.TextColor3 = i == 1 and Color3.new(1, 1, 1) or Color3.fromRGB(180, 180, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = i == 1
    frame.Parent = contentScroll
    tabContents[i] = frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = frame

    btn.MouseButton1Click:Connect(function()
        playClick()
        for j, f in ipairs(tabContents) do f.Visible = false end
        frame.Visible = true
        tabTitle.Text = tName
        for j, b in ipairs(tabs) do 
            b.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
            b.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
        btn.BackgroundColor3 = Color3.fromRGB(150, 50, 255)
        btn.TextColor3 = Color3.new(1, 1, 1)
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 15)
    end)
    tabs[i] = btn
end

-- === CÔNG CỤ UI PREMIUM ===
local function createButtonOption(parent, text, options, defaultOption, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    f.BackgroundTransparency = 0.6
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.35, 0, 0, 26)
    btn.Position = UDim2.new(1, -10 - (0.35 * parent.AbsoluteSize.X), 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(150, 50, 255)
    btn.Text = defaultOption
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local currentIndex = 1
    for i, v in ipairs(options) do if v == defaultOption then currentIndex = i; break end end

    btn.MouseButton1Click:Connect(function()
        playClick()
        currentIndex = currentIndex + 1
        if currentIndex > #options then currentIndex = 1 end
        btn.Text = options[currentIndex]
        callback(options[currentIndex])
    end)
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if parent.AbsoluteSize.X > 0 then btn.Position = UDim2.new(1, -10 - (0.35 * parent.AbsoluteSize.X), 0.5, -13) end
    end)
end

local function createToggle(parent, text, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    f.BackgroundTransparency = 0.6
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.7, 0, 1, 0)
    l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 38, 0, 22)
    toggleBtn.Position = UDim2.new(1, -48, 0.5, -11)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(255, 50, 150) or Color3.fromRGB(50, 50, 60)
    toggleBtn.Text = ""
    toggleBtn.Parent = f
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 18, 0, 18)
    circle.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    circle.BackgroundColor3 = Color3.new(1, 1, 1)
    circle.Parent = toggleBtn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local active = default
    local function toggle()
        playClick()
        active = not active
        local targetPos = active and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        local targetColor = active and Color3.fromRGB(255, 50, 150) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(circle, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Position = targetPos}):Play()
        TweenService:Create(toggleBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = targetColor}):Play()
        callback(active)
    end
    toggleBtn.MouseButton1Click:Connect(toggle)
    f.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then toggle() end end)
end

local function addSlider(parent, text, min, max, default, step, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 48)
    f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    f.BackgroundTransparency = 0.6
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 0, 16)
    l.Position = UDim2.new(0, 10, 0, 6)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 12
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.5, -15, 0, 16)
    valLabel.Position = UDim2.new(0.5, 0, 0, 6)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(default)
    valLabel.TextColor3 = Color3.fromRGB(150, 100, 255)
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 12
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = f

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 4)
    track.Position = UDim2.new(0, 10, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(150, 50, 255)
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new((default-min)/(max-min), -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Text = ""
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local val = default
    local draggingSlider = false

    local function update(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        val = min + relX * (max - min)
        if step > 0 then val = math.round(val/step)*step end
        local ratio = (val - min) / (max - min)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, -7, 0.5, -7)
        if step < 1 then valLabel.Text = string.format("%.2f", val) else valLabel.Text = tostring(math.floor(val)) end
        callback(val)
    end

    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then draggingSlider = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
    end)
end

-- Tab 1: Aiming
createToggle(tabContents[1], "Aimbot", false, function(s) state.aimbot = s end)
createButtonOption(tabContents[1], "Vị Trí (Aim)", {"Head", "Torso"}, values.aimPart, function(v) values.aimPart = v end)
addSlider(tabContents[1], "Độ Dính Tâm (Nhỏ = Aimlock)", 1, 20, values.aimbotSmoothing, 0.5, function(v) values.aimbotSmoothing = v end)
createToggle(tabContents[1], "Tự Động Bắn (Zero Delay)", false, function(s) state.autoFire = s end)
createToggle(tabContents[1], "Kiểm Tra Vật Cản", true, function(s) values.wallCheck = s end)
addSlider(tabContents[1], "Tầm Xa Quét Địch", 10, 1500, values.aimbotRange, 10, function(v) values.aimbotRange = v end)

-- Tab 2: Visual 
createToggle(tabContents[2], "Tâm Ảo 3D (Khi Ngắm)", true, function(s) state.showTargetMarker = s end)
createToggle(tabContents[2], "Đường Kẻ Bám Sao (Snaplines)", false, function(s) state.snaplines = s end)
createToggle(tabContents[2], "Bật ESP", false, function(s) state.espEnabled = s end)
createToggle(tabContents[2], "Map Sáng (Chống Đen)", false, function(s) 
    state.fullbright = s
    Lighting.Ambient = s and Color3.new(1, 1, 1) or origAmbient
    Lighting.OutdoorAmbient = s and Color3.new(1, 1, 1) or origOutdoorAmbient
end)

-- Tab 3: Movement
createToggle(tabContents[3], "Chạy Nhanh", false, function(s) state.speed = s end)
addSlider(tabContents[3], "Tốc Độ", 16, 150, values.speedVal, 1, function(v) values.speedVal = v end)
createToggle(tabContents[3], "Bay Mượt (Fly)", false, function(s) state.fly = s end)
createToggle(tabContents[3], "Nhảy Không Giới Hạn", false, function(s) state.infJump = s end)

-- Tab 4: Misc (Thêm Tính Năng FPS)
createToggle(tabContents[4], "Góc Nhìn Rộng (FOV Changer)", false, function(s) 
    if not s then camera.FieldOfView = 70 end
end)
addSlider(tabContents[4], "Mức Độ Góc Nhìn", 70, 120, values.camFov, 1, function(v) values.camFov = v end)
createToggle(tabContents[4], "Spinbot (Chống Bị Aim)", false, function(s) state.spinbot = s end)
createToggle(tabContents[4], "Mở Rộng Vũ Khí (Hitbox)", false, function(s) state.hitboxExpander = s end)
addSlider(tabContents[4], "Kích Thước Đánh Xa", 1.5, 10, values.hitboxMult, 0.5, function(v) values.hitboxMult = v end)
createToggle(tabContents[4], "Đi Xuyên Tường", false, function(s) state.noclip = s end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 26, 0, 26)
closeBtn.Position = UDim2.new(1, -34, 0, 10)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 15
closeBtn.Parent = main
closeBtn.MouseButton1Click:Connect(toggleMenu)

task.wait(0.1)
for i, frame in ipairs(tabContents) do
    if frame.Visible then contentScroll.CanvasSize = UDim2.new(0, 0, 0, frame.UIListLayout.AbsoluteContentSize.Y + 15) end
end

-- ====== ESP & SNAPLINES CÓ NGÔI SAO XOAY ======
local espData = {} 
local lineFolder = Instance.new("ScreenGui") -- Đổi thành ScreenGui để dễ vẽ 2D
lineFolder.Name = "YSL_SnaplinesGui"
lineFolder.Parent = playerGui

local function clearESP(p)
    if espData[p] then
        if espData[p].Highlight then espData[p].Highlight:Destroy() end
        if espData[p].Billboard then espData[p].Billboard:Destroy() end
        if espData[p].Line then espData[p].Line:Destroy() end
        if espData[p].Star2D then espData[p].Star2D:Destroy() end
        espData[p] = nil
    end
end

local snapStarRotation = 0
addConnection(RunService.RenderStepped:Connect(function(dt)
    snapStarRotation = snapStarRotation + (dt * 150)
    
    for p, _ in pairs(espData) do
        if not p.Parent or not isAlive(p) or (not state.espEnabled and not state.snaplines) then clearESP(p) end
    end
    
    if not state.espEnabled and not state.snaplines then return end
    
    local originPos = camera.CFrame.Position
    local myRoot = getCharacter(player) and getCharacter(player):FindFirstChild("HumanoidRootPart")
    if myRoot then originPos = myRoot.Position end 
    local screenSize = camera.ViewportSize

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and isAlive(p) then
            local eChar = getCharacter(p)
            local targetPart = getAimPart(eChar)
            
            if targetPart then
                local dist = (originPos - targetPart.Position).Magnitude
                if dist <= values.espMaxDistance then
                    if not espData[p] then
                        local hl = Instance.new("Highlight")
                        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        hl.FillTransparency = 0.6
                        hl.OutlineTransparency = 0
                        hl.Parent = eChar
                        
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 100, 0, 40)
                        bb.StudsOffset = Vector3.new(0, 3, 0)
                        bb.AlwaysOnTop = true
                        bb.Adornee = targetPart 
                        bb.Parent = eChar
                        
                        local nL = Instance.new("TextLabel")
                        nL.Size = UDim2.new(1, 0, 0.5, 0)
                        nL.BackgroundTransparency = 1
                        nL.Text = p.DisplayName
                        nL.TextColor3 = Color3.new(1, 1, 1)
                        nL.Font = Enum.Font.GothamBold
                        nL.TextSize = 10
                        nL.Parent = bb
                        
                        local iL = Instance.new("TextLabel")
                        iL.Size = UDim2.new(1, 0, 0.5, 0)
                        iL.Position = UDim2.new(0, 0, 0.5, 0)
                        iL.BackgroundTransparency = 1
                        iL.TextColor3 = Color3.fromRGB(0, 255, 0)
                        iL.Font = Enum.Font.GothamMedium
                        iL.TextSize = 9
                        iL.Parent = bb
                        
                        -- Frame cho đường kẻ Snapline
                        local line = Instance.new("Frame")
                        line.BorderSizePixel = 0
                        line.AnchorPoint = Vector2.new(0.5, 0.5)
                        line.Parent = lineFolder
                        
                        -- Ngôi sao 2D đính ở cuối đường Snapline
                        local star2D = Instance.new("ImageLabel")
                        star2D.Size = UDim2.new(0, 20, 0, 20)
                        star2D.AnchorPoint = Vector2.new(0.5, 0.5)
                        star2D.BackgroundTransparency = 1
                        star2D.Image = "rbxassetid://12812239617" -- Ngôi sao
                        star2D.Parent = lineFolder
                        
                        espData[p] = { Highlight = hl, Billboard = bb, NameLabel = nL, InfoLabel = iL, Line = line, Star2D = star2D }
                    end
                    
                    local data = espData[p]
                    local color = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
                    local isVis = isVisible(targetPart)
                    local lineColor = isVis and Color3.fromRGB(255, 50, 150) or color
                    
                    if state.espEnabled then
                        data.Highlight.Enabled = true
                        data.Billboard.Enabled = true
                        data.Highlight.FillColor = lineColor
                        data.Highlight.OutlineColor = lineColor
                        local hum = getHumanoid(eChar)
                        local health = hum and math.floor(hum.Health) or 0
                        data.InfoLabel.Text = string.format("♥ %d | %dm", health, math.floor(dist))
                    else
                        data.Highlight.Enabled = false
                        data.Billboard.Enabled = false
                    end
                    
                    -- Xử lý Snapline + Star
                    if state.snaplines then
                        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen and screenPos.Z > 0 then
                            data.Line.Visible = true
                            data.Star2D.Visible = true
                            
                            local startPos = Vector2.new(screenSize.X / 2, screenSize.Y)
                            local endPos = Vector2.new(screenPos.X, screenPos.Y)
                            
                            local lineVector = endPos - startPos
                            local length = lineVector.Magnitude
                            local angle = math.atan2(lineVector.Y, lineVector.X)
                            
                            data.Line.Size = UDim2.new(0, length, 0, 1.5)
                            data.Line.Position = UDim2.new(0, (startPos.X + endPos.X)/2, 0, (startPos.Y + endPos.Y)/2)
                            data.Line.Rotation = math.deg(angle)
                            data.Line.BackgroundColor3 = lineColor
                            
                            data.Star2D.Position = UDim2.new(0, endPos.X, 0, endPos.Y)
                            data.Star2D.ImageColor3 = lineColor
                            data.Star2D.Rotation = snapStarRotation
                        else
                            data.Line.Visible = false
                            data.Star2D.Visible = false
                        end
                    else
                        data.Line.Visible = false
                        data.Star2D.Visible = false
                    end
                else 
                    clearESP(p) 
                end
            end
        end
    end
end))

-- ====== LOOP CHUNG CHO AIMBOT & MISC FPS ======
addConnection(RunService.RenderStepped:Connect(function()
    -- FOV Changer
    if camera.FieldOfView ~= values.camFov and main.Visible == false then
        -- Kích hoạt FOV slider, bỏ qua khi đang dùng chuột trong menu (nếu cấn)
        pcall(function() camera.FieldOfView = values.camFov end)
    end

    if state.aimbot or state.autoFire then
        updateNearestEnemy()
    else
        currentAimbotTargetPart = nil
    end

    if currentAimbotTargetPart then
        if state.aimbot then
            local targetVelocity = currentAimbotTargetPart.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local predictedPos = currentAimbotTargetPart.Position + (targetVelocity * values.predictionAmount)
            local camPos = camera.CFrame.Position
            local desiredCFrame = CFrame.lookAt(camPos, predictedPos)
            
            if values.aimbotSmoothing <= 1 then
                camera.CFrame = desiredCFrame
            else
                local alpha = math.clamp(1 / values.aimbotSmoothing, 0.05, 1)
                camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
            end
        end
        if state.autoFire then attack() end
    end
end))

-- ====== SPINBOT (ANTI-AIM) ======
addConnection(RunService.RenderStepped:Connect(function()
    if state.spinbot then
        local myChar = getCharacter(player)
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if myRoot then
            myRoot.CFrame = myRoot.CFrame * CFrame.Angles(0, math.rad(values.spinSpeed), 0)
        end
    end
end))

-- ====== CÁC CHỨC NĂNG CƠ BẢN ======
addConnection(RunService.Heartbeat:Connect(function()
    if not state.hitboxExpander then return end
    local char = getCharacter(player)
    if char then
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local handle = tool:FindFirstChild("Handle")
                if handle and handle:IsA("BasePart") then
                    if not tool:GetAttribute("OrigSize") then tool:SetAttribute("OrigSize", handle.Size) end
                    handle.Size = tool:GetAttribute("OrigSize") * values.hitboxMult
                end
            end
        end
    end
end))

addConnection(RunService.Heartbeat:Connect(function()
    local hum = getHumanoid(getCharacter(player))
    if hum then
        if state.speed then hum.WalkSpeed = values.speedVal end
        if state.infJump then hum.JumpPower = values.jumpVal end
    end
end))

UserInputService.JumpRequest:Connect(function()
    if state.infJump then
        local hum = getHumanoid(getCharacter(player))
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local flyBodyVelocity, flyBodyGyro
addConnection(RunService.RenderStepped:Connect(function()
    local char = getCharacter(player)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = getHumanoid(char)
    if state.fly and root and hum then
        hum.PlatformStand = true
        if not flyBodyVelocity then
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.MaxForce = Vector3.new(400000,400000,400000)
            flyBodyVelocity.Parent = root
        end
        if not flyBodyGyro then
            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.MaxTorque = Vector3.new(400000,400000,400000)
            flyBodyGyro.P = 10000
            flyBodyGyro.Parent = root
        end
        flyBodyGyro.CFrame = camera.CFrame
        local moveDir = Vector3.new(0,0,0)
        local controlModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
        local inputVector = controlModule:GetMoveVector()
        
        if inputVector.Magnitude > 0 then moveDir = (camera.CFrame.RightVector * inputVector.X) - (camera.CFrame.LookVector * inputVector.Z) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0,1,0) end
        
        if moveDir.Magnitude == 0 then flyBodyVelocity.Velocity = Vector3.new(0, 0.1, 0)
        else flyBodyVelocity.Velocity = moveDir.Unit * values.flySpeed end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        if hum then hum.PlatformStand = false end
    end
end))

addConnection(RunService.Stepped:Connect(function()
    if state.noclip then
        local char = getCharacter(player)
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
    end
end))

player.CharacterAdded:Connect(function(char)
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    for p, _ in pairs(espData) do clearESP(p) end
end)
Players.PlayerRemoving:Connect(function(p) clearESP(p) end)

gui.Destroying:Connect(function()
    cleanupConnections()
    for p, _ in pairs(espData) do clearESP(p) end
    if targetMarker then targetMarker:Destroy() end
    if lineFolder then lineFolder:Destroy() end
    if menuBlur then menuBlur:Destroy() end
    Lighting.Ambient = origAmbient
    Lighting.OutdoorAmbient = origOutdoorAmbient
end)

print("[YSL Bá Sàn v21 Premium] Nạp siêu cấp: AutoFire fix triệt để, Premium UI & Animation hoàn chỉnh.")
