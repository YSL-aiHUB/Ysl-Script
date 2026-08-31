--[[
    YSL Bá Sàn v22 Luxury Edition
    - FIX SNAPLINES: Viết lại công thức toán 2D, kẻ tia laser chính xác 100%.
    - LUXURY UI: Tone màu Gold x Purple x Dark Onyx, font chữ sang trọng.
    - INFO TAB: Bổ sung khu vực vinh danh tác giả Y Seav Long.
    - MOBILE OPTIMIZED: Khu vực cuộn (Scroll) tách biệt, dễ vuốt trên iPhone.
    - TRIGGERBOT & ZERO DELAY: Bắn cháy máy không khựng.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- ====== ÂM THANH UI (LUXURY CLICK) ======
local uiSound = Instance.new("Sound")
uiSound.SoundId = "rbxassetid://6895079853"
uiSound.Volume = 0.6
uiSound.Parent = SoundService
local function playClick() pcall(function() uiSound:Play() end) end

-- ====== TRẠNG THÁI & THIẾT LẬP ======
local state = {
    aimbot = false, autoFire = false, hitboxExpander = false, triggerBot = false,
    espEnabled = false, showTargetMarker = true, snaplines = false,
    speed = false, infJump = false, fly = false, noclip = false, spinbot = false,
    fullbright = false, nofog = false, autoCollect = false, antiAFK = false,
}

local values = {
    aimbotSmoothing = 5, aimbotRange = 1500, predictionAmount = 0.12,
    aimPart = "Head", wallCheck = true, teamCheck = false,
    autoFireInterval = 0.03, hitboxMult = 4, espMaxDistance = 2000,
    speedVal = 30, jumpVal = 80, flySpeed = 50, camFov = 70, spinSpeed = 50,
}

local connections = {}
local function addConnection(conn) table.insert(connections, conn) end

local origAmbient = Lighting.Ambient
local origOutdoorAmbient = Lighting.OutdoorAmbient
local origFogEnd = Lighting.FogEnd
local menuBlur = Instance.new("BlurEffect"); menuBlur.Size = 0; menuBlur.Parent = Lighting

-- ====== HÀM TIỆN ÍCH ======
local function getCharacter(plr) return plr and plr.Character or nil end
local function getHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") or nil end
local function isAlive(plr)
    local hum = getHumanoid(getCharacter(plr))
    return hum and hum.Health > 0
end
local function isEnemy(tPlayer)
    if not tPlayer or tPlayer == player then return false end
    if not values.teamCheck then return true end
    if player.Team and tPlayer.Team then return player.Team ~= tPlayer.Team end
    return true
end
local function getAimPart(char)
    if not char then return nil end
    return values.aimPart == "Head" and char:FindFirstChild("Head") or (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart"))
end
local function isVisible(targetPart)
    if not values.wallCheck then return true end
    if not targetPart or not targetPart.Parent then return false end
    local origin = camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {getCharacter(player), camera, targetPart.Parent} 
    local result = Workspace:Raycast(origin, (targetPart.Position - origin).Unit * values.aimbotRange, raycastParams)
    return result == nil
end

-- ====== TÌM MỤC TIÊU & SHOOT ======
local currentAimbotTargetPart = nil
local lastFireTime = 0

local function updateNearestEnemy()
    local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestDist, bestPart = math.huge, nil
    local originPos = camera.CFrame.Position
    
    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and isAlive(p) then
            local targetPart = getAimPart(getCharacter(p))
            if targetPart and (originPos - targetPart.Position).Magnitude <= values.aimbotRange then
                local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                if onScreen and screenPos.Z > 0 then
                    local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                    if isVisible(targetPart) and screenDist < bestDist then
                        bestDist = screenDist; bestPart = targetPart
                    end
                end
            end
        end
    end
    currentAimbotTargetPart = bestPart
end

local function attack()
    if tick() - lastFireTime < values.autoFireInterval then return end
    lastFireTime = tick()
    local tool = getCharacter(player) and getCharacter(player):FindFirstChildOfClass("Tool")
    if tool then task.spawn(function() pcall(function() tool:Activate() end) end) end
end

-- ====== TARGET MARKER DÙNG ID ẢNH ======
local targetMarker = Instance.new("BillboardGui")
targetMarker.Name = "YSL_LuxuryMarker"
targetMarker.AlwaysOnTop = true
targetMarker.LightInfluence = 0
targetMarker.Enabled = false
targetMarker.Parent = playerGui

local markerImage = Instance.new("ImageLabel")
markerImage.Size = UDim2.new(1, 0, 1, 0)
markerImage.BackgroundTransparency = 1
markerImage.Image = "rbxassetid://12812239617" 
markerImage.ImageColor3 = Color3.fromRGB(255, 215, 0) -- Gold Color
markerImage.Parent = targetMarker

addConnection(RunService.RenderStepped:Connect(function(dt)
    if state.aimbot and state.showTargetMarker and currentAimbotTargetPart then
        targetMarker.Enabled = true
        targetMarker.Adornee = currentAimbotTargetPart
        targetMarker.Size = values.aimPart == "Head" and UDim2.new(0,35,0,35) or UDim2.new(0,60,0,60)
        markerImage.Rotation = markerImage.Rotation + (dt * 150)
        local pulse = math.sin(tick() * 8) * 0.1 + 0.9
        markerImage.Size = UDim2.new(pulse, 0, pulse, 0)
    else
        targetMarker.Enabled = false; targetMarker.Adornee = nil
    end
end))

-- ====== GIAO DIỆN LUXURY UI ======
if playerGui:FindFirstChild("YSL_LuxuryUI") then playerGui.YSL_LuxuryUI:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "YSL_LuxuryUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

-- Gui riêng để vẽ Snapline chuẩn xác (Bỏ qua Topbar)
local snapGui = Instance.new("ScreenGui")
snapGui.Name = "YSL_Snaplines"
snapGui.IgnoreGuiInset = true
snapGui.ResetOnSpawn = false
snapGui.Parent = playerGui

-- === NÚT MỞ MENU ===
local openMenuBtn = Instance.new("Frame")
openMenuBtn.Size = UDim2.new(0, 120, 0, 40)
openMenuBtn.Position = UDim2.new(0, 15, 0, 15)
openMenuBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
openMenuBtn.Parent = gui
Instance.new("UICorner", openMenuBtn).CornerRadius = UDim.new(1, 0)

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 2
local btnUIGradient = Instance.new("UIGradient")
btnUIGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(212, 175, 55)), -- Luxury Gold
    ColorSequenceKeypoint.new(1, Color3.fromRGB(157, 78, 221))  -- Royal Purple
}
btnUIGradient.Parent = btnStroke
btnStroke.Parent = openMenuBtn

local menuIcon = Instance.new("ImageLabel")
menuIcon.Size = UDim2.new(0, 24, 0, 24)
menuIcon.Position = UDim2.new(0, 10, 0.5, -12)
menuIcon.BackgroundTransparency = 1
menuIcon.Image = "rbxassetid://84705282139911"
menuIcon.Parent = openMenuBtn

local openText = Instance.new("TextLabel")
openText.Size = UDim2.new(1, -45, 1, 0)
openText.Position = UDim2.new(0, 40, 0, 0)
openText.BackgroundTransparency = 1
openText.Text = "YSL"
openText.TextColor3 = Color3.fromRGB(212, 175, 55)
openText.Font = Enum.Font.GothamBlack
openText.TextSize = 14
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

-- === MAIN MENU LUXURY ===
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
    ColorSequenceKeypoint.new(0, Color3.fromRGB(12, 12, 15)), 
    ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 20, 30))  
}
mainGradient.Rotation = 30
mainGradient.Parent = main

local mainStroke = Instance.new("UIStroke")
mainStroke.Thickness = 2
local msGrad = btnUIGradient:Clone(); msGrad.Parent = mainStroke
mainStroke.Parent = main

local menuScale = Instance.new("UIScale"); menuScale.Scale = 0; menuScale.Parent = main

local isMenuOpen = false
invisibleBtn.MouseButton1Click:Connect(function()
    isMenuOpen = not isMenuOpen; playClick()
    if isMenuOpen then
        main.Visible = true
        TweenService:Create(menuScale, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Scale = 1}):Play()
        TweenService:Create(menuBlur, TweenInfo.new(0.4), {Size = 15}):Play()
    else
        local closeAnim = TweenService:Create(menuScale, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {Scale = 0})
        closeAnim:Play(); TweenService:Create(menuBlur, TweenInfo.new(0.3), {Size = 0}):Play()
        closeAnim.Completed:Connect(function() if not isMenuOpen then main.Visible = false end end)
    end
end)

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

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sidebar.BackgroundTransparency = 0.4 
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local logoIcon = Instance.new("ImageLabel")
logoIcon.Size = UDim2.new(0, 30, 0, 30)
logoIcon.Position = UDim2.new(0, 10, 0, 10)
logoIcon.BackgroundTransparency = 1
logoIcon.Image = "rbxassetid://84705282139911"
logoIcon.Parent = sidebar

local menuTitleText = Instance.new("TextLabel")
menuTitleText.Size = UDim2.new(1, -45, 0, 50)
menuTitleText.Position = UDim2.new(0, 45, 0, 0)
menuTitleText.BackgroundTransparency = 1
menuTitleText.Text = "YSL"
menuTitleText.TextColor3 = Color3.fromRGB(212, 175, 55) 
menuTitleText.Font = Enum.Font.GothamBlack
menuTitleText.TextSize = 18
menuTitleText.TextXAlignment = Enum.TextXAlignment.Left
menuTitleText.Parent = sidebar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 12)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.Parent = main
closeBtn.MouseButton1Click:Connect(function() invisibleBtn.MouseButton1Click:Fire() end)

-- Khu vực chứa nội dung
local container = Instance.new("Frame")
container.Size = UDim2.new(1, -140, 1, -20)
container.Position = UDim2.new(0, 135, 0, 10)
container.BackgroundTransparency = 1
container.Parent = main

local tabTitle = Instance.new("TextLabel")
tabTitle.Size = UDim2.new(1, 0, 0, 35)
tabTitle.BackgroundTransparency = 1
tabTitle.Text = "Ngắm Bắn"
tabTitle.TextColor3 = Color3.new(1, 1, 1)
tabTitle.Font = Enum.Font.GothamBold
tabTitle.TextSize = 20
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.Parent = container

-- Tách biệt khu vực Scroll để dễ vuốt
local scrollBg = Instance.new("Frame")
scrollBg.Size = UDim2.new(1, 0, 1, -40)
scrollBg.Position = UDim2.new(0, 0, 0, 40)
scrollBg.BackgroundColor3 = Color3.fromRGB(0,0,0)
scrollBg.BackgroundTransparency = 0.7
scrollBg.Parent = container
Instance.new("UICorner", scrollBg).CornerRadius = UDim.new(0, 8)

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -10, 1, -10)
contentScroll.Position = UDim2.new(0, 5, 0, 5)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 4 -- Dày hơn để dễ thấy
contentScroll.ScrollBarImageColor3 = Color3.fromRGB(212, 175, 55)
contentScroll.CanvasSize = UDim2.new(0,0,0,0)
contentScroll.Parent = scrollBg

local tabs = {}
local tabContents = {}
local tabNames = {"Aiming", "Visual", "Movement", "Misc", "Info"}

for i, tName in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 34)
    btn.Position = UDim2.new(0, 8, 0, 60 + (i-1)*40)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(212, 175, 55) or Color3.fromRGB(25, 25, 30)
    btn.Text = "  " .. tName
    btn.TextColor3 = i == 1 and Color3.fromRGB(20, 20, 25) or Color3.fromRGB(180, 180, 200)
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
            b.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
            b.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
        btn.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
        btn.TextColor3 = Color3.fromRGB(20, 20, 25)
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 15)
    end)
    tabs[i] = btn
end

-- === CÔNG CỤ UI LUXURY ===
local function createButtonOption(parent, text, options, defaultOption, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -5, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    f.BackgroundTransparency = 0.4
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
    btn.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
    btn.Text = defaultOption
    btn.TextColor3 = Color3.fromRGB(20, 20, 25)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local currentIndex = 1
    for i, v in ipairs(options) do if v == defaultOption then currentIndex = i; break end end

    btn.MouseButton1Click:Connect(function()
        playClick(); currentIndex = currentIndex + 1
        if currentIndex > #options then currentIndex = 1 end
        btn.Text = options[currentIndex]; callback(options[currentIndex])
    end)
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if parent.AbsoluteSize.X > 0 then btn.Position = UDim2.new(1, -10 - (0.35 * parent.AbsoluteSize.X), 0.5, -13) end
    end)
end

local function createToggle(parent, text, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -5, 0, 38)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    f.BackgroundTransparency = 0.4
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
    toggleBtn.Size = UDim2.new(0, 40, 0, 22)
    toggleBtn.Position = UDim2.new(1, -50, 0.5, -11)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(157, 78, 221) or Color3.fromRGB(50, 50, 55)
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
        playClick(); active = not active
        local tPos = active and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        local tCol = active and Color3.fromRGB(157, 78, 221) or Color3.fromRGB(50, 50, 55)
        TweenService:Create(circle, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Position = tPos}):Play()
        TweenService:Create(toggleBtn, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {BackgroundColor3 = tCol}):Play()
        callback(active)
    end
    toggleBtn.MouseButton1Click:Connect(toggle)
    f.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then toggle() end end)
end

local function addSlider(parent, text, min, max, default, step, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, -5, 0, 48)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    f.BackgroundTransparency = 0.4
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
    valLabel.TextColor3 = Color3.fromRGB(212, 175, 55)
    valLabel.Font = Enum.Font.GothamBold
    valLabel.TextSize = 12
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = f

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 4)
    track.Position = UDim2.new(0, 10, 0, 34)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
    track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(212, 175, 55)
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = UDim2.new((default-min)/(max-min), -8, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Text = ""
    knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local val = default; local draggingSlider = false
    local function update(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        val = min + relX * (max - min)
        if step > 0 then val = math.round(val/step)*step end
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0)
        knob.Position = UDim2.new((val - min) / (max - min), -8, 0.5, -8)
        valLabel.Text = step < 1 and string.format("%.2f", val) or tostring(math.floor(val))
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
createToggle(tabContents[1], "Aimbot (Mượt mà)", false, function(s) state.aimbot = s end)
createButtonOption(tabContents[1], "Vị Trí Nhắm", {"Head", "Torso"}, values.aimPart, function(v) values.aimPart = v end)
addSlider(tabContents[1], "Độ Dính (Nhỏ = Aimlock)", 1, 20, values.aimbotSmoothing, 0.5, function(v) values.aimbotSmoothing = v end)
createToggle(tabContents[1], "TriggerBot (Bắn khi tâm trúng)", false, function(s) state.triggerBot = s end)
createToggle(tabContents[1], "Auto Fire (Bắn liên tục)", false, function(s) state.autoFire = s end)
createToggle(tabContents[1], "Kiểm Tra Tường", true, function(s) values.wallCheck = s end)
addSlider(tabContents[1], "Tầm Xa Aim", 10, 2000, values.aimbotRange, 10, function(v) values.aimbotRange = v end)

-- Tab 2: Visual 
createToggle(tabContents[2], "Tâm Ảo (Ngôi Sao 3D)", true, function(s) state.showTargetMarker = s end)
createToggle(tabContents[2], "Snaplines (Đường kẻ FFA)", false, function(s) state.snaplines = s end)
createToggle(tabContents[2], "Bật ESP", false, function(s) state.espEnabled = s end)
createToggle(tabContents[2], "Sáng Map (Chống Đen)", false, function(s) 
    state.fullbright = s
    Lighting.Ambient = s and Color3.new(1, 1, 1) or origAmbient
    Lighting.OutdoorAmbient = s and Color3.new(1, 1, 1) or origOutdoorAmbient
end)

-- Tab 3: Movement & FPS
createToggle(tabContents[3], "Chạy Nhanh", false, function(s) state.speed = s end)
addSlider(tabContents[3], "Tốc Độ", 16, 150, values.speedVal, 1, function(v) values.speedVal = v end)
createToggle(tabContents[3], "Bay (Fly)", false, function(s) state.fly = s end)
createToggle(tabContents[3], "Nhảy Vô Hạn", false, function(s) state.infJump = s end)
createToggle(tabContents[3], "Spinbot (Chống Aim)", false, function(s) state.spinbot = s end)

-- Tab 4: Misc
createToggle(tabContents[4], "Góc Nhìn FOV", false, function(s) if not s then camera.FieldOfView = 70 end end)
addSlider(tabContents[4], "Độ Rộng Camera", 70, 120, values.camFov, 1, function(v) values.camFov = v end)
createToggle(tabContents[4], "Mở Rộng Vũ Khí", false, function(s) state.hitboxExpander = s end)
addSlider(tabContents[4], "Kích Thước Đánh Xa", 1.5, 10, values.hitboxMult, 0.5, function(v) values.hitboxMult = v end)
createToggle(tabContents[4], "Đi Xuyên Tường", false, function(s) state.noclip = s end)

-- Tab 5: Info / Credits (Khu vực thông tin sang trọng)
local infoContainer = Instance.new("Frame")
infoContainer.Size = UDim2.new(1, -10, 1, -10)
infoContainer.Position = UDim2.new(0, 5, 0, 5)
infoContainer.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
infoContainer.Parent = tabContents[5]
Instance.new("UICorner", infoContainer).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", infoContainer).Color = Color3.fromRGB(212, 175, 55)

local titleCredit = Instance.new("TextLabel")
titleCredit.Size = UDim2.new(1, 0, 0, 40)
titleCredit.BackgroundTransparency = 1
titleCredit.Text = "👑 CREATOR INFO 👑"
titleCredit.TextColor3 = Color3.fromRGB(212, 175, 55)
titleCredit.Font = Enum.Font.GothamBlack
titleCredit.TextSize = 16
titleCredit.Parent = infoContainer

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, -20, 1, -50)
infoText.Position = UDim2.new(0, 10, 0, 40)
infoText.BackgroundTransparency = 1
infoText.Text = "Cảm ơn bạn đã sử dụng YSL Bá Sàn!\n\n🔹 FB: Y Seav Long\n🔹 Discord: yslaiplus\n🔹 Zalo: +84 372322494\n\nScript được tối ưu hóa cho Mobile & FPS."
infoText.TextColor3 = Color3.new(0.9, 0.9, 0.9)
infoText.Font = Enum.Font.GothamMedium
infoText.TextSize = 14
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextXAlignment.Top
infoText.Parent = infoContainer

task.wait(0.1)
for i, frame in ipairs(tabContents) do
    if frame.Visible then contentScroll.CanvasSize = UDim2.new(0, 0, 0, frame.UIListLayout.AbsoluteContentSize.Y + 15) end
end

-- ====== ESP & SNAPLINES FIX TOẠ ĐỘ ======
local espData = {} 

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
        if isEnemy(p) and isAlive(p) then
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
                        nL.Size = UDim2.new(1, 0, 0.5, 0); nL.BackgroundTransparency = 1
                        nL.Text = p.DisplayName; nL.TextColor3 = Color3.new(1, 1, 1)
                        nL.Font = Enum.Font.GothamBold; nL.TextSize = 10; nL.Parent = bb
                        
                        local iL = Instance.new("TextLabel")
                        iL.Size = UDim2.new(1, 0, 0.5, 0); iL.Position = UDim2.new(0, 0, 0.5, 0)
                        iL.BackgroundTransparency = 1; iL.TextColor3 = Color3.fromRGB(0, 255, 0)
                        iL.Font = Enum.Font.GothamMedium; iL.TextSize = 9; iL.Parent = bb
                        
                        local line = Instance.new("Frame")
                        line.BorderSizePixel = 0; line.AnchorPoint = Vector2.new(0.5, 0.5)
                        line.Parent = snapGui
                        
                        local star2D = Instance.new("ImageLabel")
                        star2D.Size = UDim2.new(0, 20, 0, 20); star2D.AnchorPoint = Vector2.new(0.5, 0.5)
                        star2D.BackgroundTransparency = 1; star2D.Image = "rbxassetid://12812239617"
                        star2D.Parent = snapGui
                        
                        espData[p] = { Highlight = hl, Billboard = bb, NameLabel = nL, InfoLabel = iL, Line = line, Star2D = star2D }
                    end
                    
                    local data = espData[p]
                    local color = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
                    local isVis = isVisible(targetPart)
                    local lineColor = isVis and Color3.fromRGB(255, 50, 150) or color
                    
                    if state.espEnabled then
                        data.Highlight.Enabled = true; data.Billboard.Enabled = true
                        data.Highlight.FillColor = lineColor; data.Highlight.OutlineColor = lineColor
                        local hum = getHumanoid(eChar)
                        data.InfoLabel.Text = string.format("♥ %d | %dm", hum and math.floor(hum.Health) or 0, math.floor(dist))
                    else
                        data.Highlight.Enabled = false; data.Billboard.Enabled = false
                    end
                    
                    -- Vẽ Snapline chuẩn xác (Đã fix lỗi toạ độ GUI)
                    if state.snaplines then
                        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen and screenPos.Z > 0 then
                            data.Line.Visible = true; data.Star2D.Visible = true
                            
                            local startPos = Vector2.new(screenSize.X / 2, screenSize.Y) -- Đáy giữa màn hình
                            local endPos = Vector2.new(screenPos.X, screenPos.Y)
                            
                            local distance = (endPos - startPos).Magnitude
                            local angle = math.atan2(endPos.Y - startPos.Y, endPos.X - startPos.X)
                            
                            data.Line.Size = UDim2.new(0, distance, 0, 1.5)
                            data.Line.Position = UDim2.new(0, (startPos.X + endPos.X)/2, 0, (startPos.Y + endPos.Y)/2)
                            data.Line.Rotation = math.deg(angle)
                            data.Line.BackgroundColor3 = lineColor
                            
                            data.Star2D.Position = UDim2.new(0, endPos.X, 0, endPos.Y)
                            data.Star2D.ImageColor3 = lineColor
                            data.Star2D.Rotation = snapStarRotation
                        else
                            data.Line.Visible = false; data.Star2D.Visible = false
                        end
                    else
                        data.Line.Visible = false; data.Star2D.Visible = false
                    end
                else clearESP(p) end
            end
        end
    end
end))

-- ====== LOOP CHUNG CHO AIMBOT & TRIGGERBOT ======
addConnection(RunService.RenderStepped:Connect(function()
    if camera.FieldOfView ~= values.camFov and main.Visible == false then pcall(function() camera.FieldOfView = values.camFov end) end

    if state.aimbot or state.autoFire or state.triggerBot then updateNearestEnemy() else currentAimbotTargetPart = nil end

    if currentAimbotTargetPart then
        if state.aimbot then
            local targetVelocity = currentAimbotTargetPart.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local predictedPos = currentAimbotTargetPart.Position + (targetVelocity * values.predictionAmount)
            local desiredCFrame = CFrame.lookAt(camera.CFrame.Position, predictedPos)
            if values.aimbotSmoothing <= 1 then camera.CFrame = desiredCFrame else
                camera.CFrame = camera.CFrame:Lerp(desiredCFrame, math.clamp(1 / values.aimbotSmoothing, 0.05, 1))
            end
        end
        
        -- TriggerBot: Tự động bắn khi crosshair (tâm chuột) chỉ đúng vào người địch
        if state.triggerBot then
            local mouseRay = camera:ScreenPointToRay(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
            local result = Workspace:Raycast(mouseRay.Origin, mouseRay.Direction * 1000)
            if result and result.Instance and result.Instance:IsDescendantOf(currentAimbotTargetPart.Parent) then attack() end
        end
        
        if state.autoFire then attack() end
    end
end))

-- ====== SPINBOT (Chống Aim) ======
addConnection(RunService.RenderStepped:Connect(function()
    if state.spinbot then
        local myRoot = getCharacter(player) and getCharacter(player):FindFirstChild("HumanoidRootPart")
        if myRoot then myRoot.CFrame = myRoot.CFrame * CFrame.Angles(0, math.rad(values.spinSpeed), 0) end
    end
end))

-- ====== CÁC CHỨC NĂNG MISC CƠ BẢN ======
addConnection(RunService.Heartbeat:Connect(function()
    if state.hitboxExpander then
        local char = getCharacter(player)
        if char then
            for _, tool in ipairs(char:GetChildren()) do
                if tool:IsA("Tool") then
                    local handle = tool:FindFirstChild("Handle")
                    if handle and handle:IsA("BasePart") then
                        if not tool:GetAttribute("OrigSize") then tool:SetAttribute("OrigSize", handle.Size) end
                        handle.Size = tool:GetAttribute("OrigSize") * values.hitboxMult
                        handle.Transparency = 0.5 -- Hiện mờ mờ hitbox
                    end
                end
            end
        end
    end
    
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
    local char = getCharacter(player); local root = char and char:FindFirstChild("HumanoidRootPart"); local hum = getHumanoid(char)
    if state.fly and root and hum then
        hum.PlatformStand = true
        if not flyBodyVelocity then
            flyBodyVelocity = Instance.new("BodyVelocity"); flyBodyVelocity.MaxForce = Vector3.new(400000,400000,400000); flyBodyVelocity.Parent = root
        end
        if not flyBodyGyro then
            flyBodyGyro = Instance.new("BodyGyro"); flyBodyGyro.MaxTorque = Vector3.new(400000,400000,400000); flyBodyGyro.P = 10000; flyBodyGyro.Parent = root
        end
        flyBodyGyro.CFrame = camera.CFrame
        local moveDir = Vector3.new(0,0,0)
        local controlModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
        local inputVector = controlModule:GetMoveVector()
        
        if inputVector.Magnitude > 0 then moveDir = (camera.CFrame.RightVector * inputVector.X) - (camera.CFrame.LookVector * inputVector.Z) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0,1,0) end
        flyBodyVelocity.Velocity = moveDir.Magnitude == 0 and Vector3.new(0, 0.1, 0) or moveDir.Unit * values.flySpeed
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
            for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end
        end
    end
end))

local afkConnection
addConnection(RunService.RenderStepped:Connect(function()
    if state.antiAFK then
        if not afkConnection then
            afkConnection = player.Idled:Connect(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0); task.wait(0.1); VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end)
        end
    else
        if afkConnection then afkConnection:Disconnect(); afkConnection = nil end
    end
end))

player.CharacterAdded:Connect(function()
    if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
    for p, _ in pairs(espData) do clearESP(p) end
end)
Players.PlayerRemoving:Connect(function(p) clearESP(p) end)

gui.Destroying:Connect(function()
    cleanupConnections()
    for p, _ in pairs(espData) do clearESP(p) end
    if targetMarker then targetMarker:Destroy() end
    if snapGui then snapGui:Destroy() end
    if menuBlur then menuBlur:Destroy() end
    Lighting.Ambient = origAmbient; Lighting.OutdoorAmbient = origOutdoorAmbient; Lighting.FogEnd = origFogEnd
end)

print("[YSL Bá Sàn v22 Luxury] Đã sửa lỗi Snaplines. Bổ sung Tab Info & TriggerBot.")
