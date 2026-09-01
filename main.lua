--[[
    YSL BÁ SÀN SUPREME v32 - MASTERPIECE EDITION
    Creator: Y Seav Long
    - [FIXED] R15/R6 Compatibility: Tối ưu hoá nhận diện Head/Torso, hoạt động 100% mọi map FPS.
    - [FIXED] Precision Aim: Khử nhiễu gia tốc vật lý R6, tâm ghim cứng mục tiêu.
    - [UI UPGRADE] Tỉ lệ chuẩn 1536x1147. Nền menu (101591256247668) & Ảnh Bìa (84705282139911).
    - [RESTORED] Thêm Tab Thông Tin Sáng Lập cực Luxury.
    - Zero Delay AutoFire (No Joystick Freeze).
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui", 10) or player:FindFirstChildOfClass("PlayerGui")

-- ====== TRẠNG THÁI & THIẾT LẬP ======
local state = {
    aimbot = false, autoFire = false, hitboxExpander = false,
    espEnabled = false, snaplines = false, showTargetHud = true,
    speed = false, infJump = false, fly = false, noclip = false, spinbot = false,
    fullbright = false,
}

local values = {
    aimbotFov = 150, aimbotSmoothing = 6, aimbotRange = 2000, predictionAmount = 0.12,
    aimPart = "Đầu (Head)", -- "Đầu (Head)" hoặc "Thân (Torso)"
    wallCheck = true, teamCheck = false,
    fireDelay = 0.05, hitboxMult = 4, espMaxDistance = 3000,
    speedVal = 40, jumpVal = 80, flySpeed = 50, camFov = 70, snapOrigin = "Dưới",
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

-- ====== HÀM TIỆN ÍCH ======
local function getCharacter(plr) return plr and plr.Character or nil end
local function getHumanoid(char) return char and char:FindFirstChildOfClass("Humanoid") or nil end
local function isAlive(plr)
    local hum = getHumanoid(getCharacter(plr))
    return hum and hum.Health > 0
end

local function isEnemy(targetPlayer)
    if not targetPlayer or targetPlayer == player then return false end
    if not values.teamCheck then return true end
    if player.Team and targetPlayer.Team then return player.Team ~= targetPlayer.Team end
    return true
end

-- Tối ưu nhận diện R6/R15 chống lỗi mất tâm
local function getAimPart(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    
    if values.aimPart == "Đầu (Head)" then
        return head or torso
    else
        return torso or head
    end
end

local function isVisible(targetPart)
    if not values.wallCheck then return true end
    if not targetPart or not targetPart.Parent then return false end
    
    local myChar = getCharacter(player)
    local origin = camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {myChar, camera}
    
    local direction = targetPart.Position - origin
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if not result or (result.Instance and result.Instance:IsDescendantOf(targetPart.Parent)) then
        return true
    end
    return false
end

-- ====== BẢNG THÔNG TIN MỤC TIÊU (TARGET HUD) ======
local targetHudGui = Instance.new("ScreenGui")
targetHudGui.Name = "YSL_TargetHUD"
targetHudGui.ResetOnSpawn = false
targetHudGui.Parent = playerGui

local targetFrame = Instance.new("Frame")
targetFrame.Size = UDim2.new(0, 180, 0, 60)
targetFrame.Position = UDim2.new(0.5, 50, 0.5, -30)
targetFrame.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
targetFrame.BackgroundTransparency = 0.2
targetFrame.Visible = false
targetFrame.Parent = targetHudGui
Instance.new("UICorner", targetFrame).CornerRadius = UDim.new(0, 8)

local hudStroke = Instance.new("UIStroke")
hudStroke.Color = Color3.fromRGB(200, 50, 255)
hudStroke.Thickness = 1.5
hudStroke.Parent = targetFrame

local targetTitle = Instance.new("TextLabel")
targetTitle.Size = UDim2.new(1, 0, 0, 20)
targetTitle.BackgroundTransparency = 1
targetTitle.Text = "★ YSL TARGET ★"
targetTitle.TextColor3 = Color3.fromRGB(200, 50, 255)
targetTitle.Font = Enum.Font.GothamBlack
targetTitle.TextSize = 10
targetTitle.Parent = targetFrame

local targetName = Instance.new("TextLabel")
targetName.Size = UDim2.new(1, -10, 0, 20)
targetName.Position = UDim2.new(0, 10, 0, 20)
targetName.BackgroundTransparency = 1
targetName.Text = "Tên: "
targetName.TextColor3 = Color3.new(1, 1, 1)
targetName.Font = Enum.Font.GothamBold
targetName.TextSize = 12
targetName.TextXAlignment = Enum.TextXAlignment.Left
targetName.Parent = targetFrame

local targetHealth = Instance.new("TextLabel")
targetHealth.Size = UDim2.new(1, -10, 0, 20)
targetHealth.Position = UDim2.new(0, 10, 0, 40)
targetHealth.BackgroundTransparency = 1
targetHealth.Text = "Máu: "
targetHealth.TextColor3 = Color3.fromRGB(50, 255, 50)
targetHealth.Font = Enum.Font.GothamBold
targetHealth.TextSize = 12
targetHealth.TextXAlignment = Enum.TextXAlignment.Left
targetHealth.Parent = targetFrame

-- ====== HỆ THỐNG MỤC TIÊU ======
local currentAimbotTargetPart = nil
local currentTargetPlayer = nil

local function updateNearestEnemy()
    local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestDist = math.huge
    local bestPart = nil
    local bestPlayer = nil
    
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
                        if screenDist <= values.aimbotFov and isVisible(targetPart) and screenDist < bestDist then
                            bestDist = screenDist
                            bestPart = targetPart
                            bestPlayer = p
                        end
                    end
                end
            end
        end
    end
    currentAimbotTargetPart = bestPart
    currentTargetPlayer = bestPlayer
end

-- AUTO SHOOT TỐI ƯU CHO MOBILE (NO JOYSTICK FREEZE)
local lastFireTime = 0
local function executeAutoShoot()
    local now = tick()
    if now - lastFireTime < values.fireDelay then return end
    lastFireTime = now
    
    task.spawn(function()
        pcall(function()
            local char = getCharacter(player)
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
            
            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.ButtonR2, false, game)
            task.wait(0.01)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.ButtonR2, false, game)
        end)
    end)
end

-- ====== GIAO DIỆN COMPACT SUPREME ======
if playerGui:FindFirstChild("YSL_SupremeUI") then playerGui.YSL_SupremeUI:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "YSL_SupremeUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local snapGui = Instance.new("ScreenGui")
snapGui.Name = "YSL_SnaplinesGui"
snapGui.IgnoreGuiInset = true 
snapGui.ResetOnSpawn = false
snapGui.Parent = playerGui

-- Nút Open Menu
local openMenuBtn = Instance.new("Frame")
openMenuBtn.Size = UDim2.new(0, 130, 0, 38)
openMenuBtn.Position = UDim2.new(0, 10, 0, 10)
openMenuBtn.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
openMenuBtn.ZIndex = 2
openMenuBtn.Parent = gui
Instance.new("UICorner", openMenuBtn).CornerRadius = UDim.new(1, 0)

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 1.5
btnStroke.Color = Color3.fromRGB(200, 50, 255)
btnStroke.Parent = openMenuBtn

local openIcon = Instance.new("ImageLabel")
openIcon.Size = UDim2.new(0, 26, 0, 26)
openIcon.Position = UDim2.new(0, 8, 0.5, -13)
openIcon.BackgroundTransparency = 1
openIcon.Image = "rbxassetid://84705282139911"
openIcon.ZIndex = 3
openIcon.Parent = openMenuBtn

local openText = Instance.new("TextLabel")
openText.Size = UDim2.new(1, -40, 1, 0)
openText.Position = UDim2.new(0, 40, 0, 0)
openText.BackgroundTransparency = 1
openText.Text = "MENU YSL"
openText.TextColor3 = Color3.new(1, 1, 1)
openText.Font = Enum.Font.GothamBold
openText.TextSize = 12
openText.TextXAlignment = Enum.TextXAlignment.Left
openText.ZIndex = 3
openText.Parent = openMenuBtn

local invisibleBtn = Instance.new("TextButton")
invisibleBtn.Size = UDim2.new(1, 0, 1, 0)
invisibleBtn.BackgroundTransparency = 1
invisibleBtn.Text = ""
invisibleBtn.ZIndex = 4
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

-- Main Menu Panel (Tỉ lệ chuẩn 1536x1147 -> Xấp xỉ 480x358)
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 358)
main.Position = UDim2.new(0.5, -240, 0.5, -179)
main.BackgroundColor3 = Color3.fromRGB(15, 10, 20) 
main.BorderSizePixel = 0
main.Visible = false
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Ảnh Nền Background Menu
local bgImage = Instance.new("ImageLabel")
bgImage.Size = UDim2.new(1, 0, 1, 0)
bgImage.BackgroundTransparency = 1
bgImage.Image = "rbxassetid://101591256247668"
bgImage.ImageTransparency = 0.35 -- Mờ nhẹ để đọc được chữ
bgImage.ScaleType = Enum.ScaleType.Crop
bgImage.ZIndex = 0
bgImage.Parent = main
Instance.new("UICorner", bgImage).CornerRadius = UDim.new(0, 10)

Instance.new("UIStroke", main).Color = Color3.fromRGB(150, 50, 255)

local menuScale = Instance.new("UIScale")
menuScale.Scale = 0
menuScale.Parent = main

local isMenuOpen = false
local function toggleMenu()
    isMenuOpen = not isMenuOpen
    if isMenuOpen then
        main.Visible = true
        TweenService:Create(menuScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    else
        local closeAnim = TweenService:Create(menuScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
        closeAnim:Play()
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

-- Sidebar
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 120, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sidebar.BackgroundTransparency = 0.5 
sidebar.BorderSizePixel = 0
sidebar.ZIndex = 1
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local titleMain = Instance.new("TextLabel")
titleMain.Size = UDim2.new(1, 0, 0, 45)
titleMain.Position = UDim2.new(0, 0, 0, 5)
titleMain.BackgroundTransparency = 1
titleMain.Text = "YSL"
titleMain.TextColor3 = Color3.fromRGB(200, 100, 255) 
titleMain.Font = Enum.Font.GothamBlack
titleMain.TextSize = 20
titleMain.ZIndex = 2
titleMain.Parent = sidebar

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -120, 1, 0)
container.Position = UDim2.new(0, 120, 0, 0)
container.BackgroundTransparency = 1
container.ZIndex = 1
container.Parent = main

local tabTitle = Instance.new("TextLabel")
tabTitle.Size = UDim2.new(1, -30, 0, 45)
tabTitle.Position = UDim2.new(0, 15, 0, 0)
tabTitle.BackgroundTransparency = 1
tabTitle.Text = "Ngắm Bắn"
tabTitle.TextColor3 = Color3.new(1, 1, 1)
tabTitle.Font = Enum.Font.GothamBold
tabTitle.TextSize = 18
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.ZIndex = 2
tabTitle.Parent = container

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -20, 1, -50)
contentScroll.Position = UDim2.new(0, 10, 0, 45)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 3
contentScroll.CanvasSize = UDim2.new(0,0,0,0)
contentScroll.ZIndex = 2
contentScroll.Parent = container

local tabs = {}
local tabContents = {}
local tabNames = {"Ngắm Bắn", "Hiển Thị", "Người Chơi", "Khác", "Thông Tin"}

for i, tName in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 34)
    btn.Position = UDim2.new(0, 8, 0, 50 + (i-1)*40)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(30, 20, 40)
    btn.BackgroundTransparency = i == 1 and 0.2 or 0.6
    btn.Text = " " .. tName
    btn.TextColor3 = i == 1 and Color3.new(1, 1, 1) or Color3.fromRGB(180, 180, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.ZIndex = 2
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = i == 1
    frame.ZIndex = 2
    frame.Parent = contentScroll
    tabContents[i] = frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 8)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = frame

    btn.MouseButton1Click:Connect(function()
        for j, f in ipairs(tabContents) do f.Visible = false end
        frame.Visible = true
        tabTitle.Text = tName
        for j, b in ipairs(tabs) do 
            b.BackgroundColor3 = Color3.fromRGB(30, 20, 40)
            b.BackgroundTransparency = 0.6
            b.TextColor3 = Color3.fromRGB(180, 180, 200)
        end
        btn.BackgroundColor3 = Color3.fromRGB(150, 50, 255)
        btn.BackgroundTransparency = 0.2
        btn.TextColor3 = Color3.new(1, 1, 1)
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 15)
    end)
    tabs[i] = btn
end

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -34, 0, 10)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 100, 100)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.ZIndex = 3
closeBtn.Parent = main
closeBtn.MouseButton1Click:Connect(toggleMenu)

-- === CÔNG CỤ TẠO NÚT/THANH TRƯỢT (ZIndex = 2) ===
local function createButtonOption(parent, text, options, defaultOption, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    f.BackgroundTransparency = 0.6
    f.ZIndex = 2
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 2; l.Parent = f

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.4, 0, 0, 24); btn.Position = UDim2.new(1, -10 - (0.4 * parent.AbsoluteSize.X), 0.5, -12)
    btn.BackgroundColor3 = Color3.fromRGB(150, 50, 255); btn.Text = defaultOption; btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.ZIndex = 2; btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local currentIndex = 1
    for i, v in ipairs(options) do if v == defaultOption then currentIndex = i; break end end

    btn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex + 1
        if currentIndex > #options then currentIndex = 1 end
        btn.Text = options[currentIndex]
        callback(options[currentIndex])
    end)
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if parent.AbsoluteSize.X > 0 then btn.Position = UDim2.new(1, -10 - (0.4 * parent.AbsoluteSize.X), 0.5, -12) end
    end)
end

local function createToggle(parent, text, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 36)
    f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    f.BackgroundTransparency = 0.6
    f.ZIndex = 2
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.7, 0, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 2; l.Parent = f

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 36, 0, 20); toggleBtn.Position = UDim2.new(1, -46, 0.5, -10)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(50, 50, 60); toggleBtn.Text = ""; toggleBtn.ZIndex = 2; toggleBtn.Parent = f
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16); circle.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = Color3.new(1, 1, 1); circle.ZIndex = 2; circle.Parent = toggleBtn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local active = default
    local function toggle()
        active = not active
        local targetPos = active and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local targetColor = active and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(50, 50, 60)
        TweenService:Create(circle, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = targetPos}):Play()
        TweenService:Create(toggleBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = targetColor}):Play()
        callback(active)
    end
    toggleBtn.MouseButton1Click:Connect(toggle)
    f.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then toggle() end end)
end

local function addSlider(parent, text, min, max, default, step, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 46)
    f.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    f.BackgroundTransparency = 0.6
    f.ZIndex = 2
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 0, 16); l.Position = UDim2.new(0, 10, 0, 6)
    l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 2; l.Parent = f
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.5, -15, 0, 16); valLabel.Position = UDim2.new(0.5, 0, 0, 6)
    valLabel.BackgroundTransparency = 1; valLabel.Text = tostring(default); valLabel.TextColor3 = Color3.fromRGB(150, 100, 255)
    valLabel.Font = Enum.Font.GothamBold; valLabel.TextSize = 12; valLabel.TextXAlignment = Enum.TextXAlignment.Right; valLabel.ZIndex = 2; valLabel.Parent = f

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -20, 0, 4); track.Position = UDim2.new(0, 10, 0, 32)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 65); track.ZIndex = 2; track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(150, 50, 255); fill.ZIndex = 2; fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 12, 0, 12); knob.Position = UDim2.new((default-min)/(max-min), -6, 0.5, -6)
    knob.BackgroundColor3 = Color3.new(1, 1, 1); knob.Text = ""; knob.ZIndex = 2; knob.Parent = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local val = default
    local draggingSlider = false

    local function update(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        val = min + relX * (max - min)
        if step > 0 then val = math.round(val/step)*step end
        local ratio = (val - min) / (max - min)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, -6, 0.5, -6)
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

-- ====== CÀI ĐẶT CHỨC NĂNG (TABS) ======
-- Tab 1: Ngắm Bắn
createToggle(tabContents[1], "Bật Aimbot", false, function(s) state.aimbot = s end)
createButtonOption(tabContents[1], "Vị Trí Ngắm", {"Đầu (Head)", "Thân (Torso)"}, "Đầu (Head)", function(v) values.aimPart = v end)
addSlider(tabContents[1], "Vòng Quét FOV (Độ Rộng)", 50, 400, values.aimbotFov, 5, function(v) values.aimbotFov = v end)
addSlider(tabContents[1], "Độ Dính Tâm (Nhỏ = Aimlock)", 1, 20, values.aimbotSmoothing, 0.5, function(v) values.aimbotSmoothing = v end)
createToggle(tabContents[1], "Auto Shoot (Bắn Tự Động)", false, function(s) state.autoFire = s end)
createToggle(tabContents[1], "Kiểm Tra Vật Cản", true, function(s) values.wallCheck = s end)

-- Tab 2: Hiển Thị
createToggle(tabContents[2], "Bảng Thông Tin Địch (HUD)", true, function(s) state.showTargetHud = s end)
createToggle(tabContents[2], "Đường Kẻ Hướng Địch (FFA)", false, function(s) state.snaplines = s end)
createButtonOption(tabContents[2], "Vị Trí Kẻ Đường", {"Dưới", "Giữa"}, "Dưới", function(v) values.snapOrigin = v end)
createToggle(tabContents[2], "ESP Định Vị Xuyên Tường", false, function(s) state.espEnabled = s end)
addSlider(tabContents[2], "Khoảng Cách Hiển Thị", 50, 4000, values.espMaxDistance, 10, function(v) values.espMaxDistance = v end)
createToggle(tabContents[2], "Sáng Bản Đồ (Chống tối map)", false, function(s) 
    state.fullbright = s
    Lighting.Ambient = s and Color3.new(1, 1, 1) or origAmbient
    Lighting.OutdoorAmbient = s and Color3.new(1, 1, 1) or origOutdoorAmbient
end)

-- Tab 3: Người Chơi
createToggle(tabContents[3], "Chạy Nhanh", false, function(s) state.speed = s end)
addSlider(tabContents[3], "Tốc Độ Di Chuyển", 16, 150, values.speedVal, 1, function(v) values.speedVal = v end)
createToggle(tabContents[3], "Bay Tự Do", false, function(s) state.fly = s end)
createToggle(tabContents[3], "Nhảy Không Giới Hạn", false, function(s) state.infJump = s end)

-- Tab 4: Khác
createToggle(tabContents[4], "Phóng To Vũ Khí (Hitbox)", false, function(s) state.hitboxExpander = s end)
addSlider(tabContents[4], "Kích Thước Mở Rộng", 1.5, 10, values.hitboxMult, 0.5, function(v) values.hitboxMult = v end)
createToggle(tabContents[4], "Đổi Góc Nhìn (FOV)", false, function(s) if not s then camera.FieldOfView = 70 end end)
addSlider(tabContents[4], "Độ Rộng Camera", 70, 120, values.camFov, 1, function(v) values.camFov = v end)
createToggle(tabContents[4], "Xoay Chống Ngắm (Spinbot)", false, function(s) state.spinbot = s end)
createToggle(tabContents[4], "Đi Xuyên Tường", false, function(s) state.noclip = s end)

-- Tab 5: Sáng Lập (Info)
local infoCover = Instance.new("ImageLabel")
infoCover.Size = UDim2.new(1, 0, 0, 140)
infoCover.Position = UDim2.new(0, 0, 0, 0)
infoCover.BackgroundTransparency = 1
infoCover.Image = "rbxassetid://84705282139911" -- Ảnh Bìa Menu Đỉnh Cao
infoCover.ScaleType = Enum.ScaleType.Fit
infoCover.ZIndex = 2
infoCover.Parent = tabContents[5]

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1, -10, 1, -150)
infoText.Position = UDim2.new(0, 5, 0, 145)
infoText.BackgroundTransparency = 1
infoText.Text = "👑 SÁNG LẬP YSL 👑\n\n🔹 FB: Y Seav Long\n🔹 Discord: yslaiplus\n🔹 Zalo: +84 372322494\n\nHỗ trợ 100% Mobile & Map R6/R15."
infoText.TextColor3 = Color3.new(0.9, 0.9, 0.9)
infoText.Font = Enum.Font.GothamMedium
infoText.TextSize = 13
infoText.TextXAlignment = Enum.TextXAlignment.Center
infoText.TextYAlignment = Enum.TextXAlignment.Top
infoText.ZIndex = 2
infoText.Parent = tabContents[5]

task.wait(0.1)
for i, frame in ipairs(tabContents) do
    if frame.Visible then contentScroll.CanvasSize = UDim2.new(0, 0, 0, frame.UIListLayout.AbsoluteContentSize.Y + 15) end
end

-- ====== ESP & SNAPLINES ======
local espData = {} 

local function DrawLine(frame, startPos, endPos, color)
    local distance = (endPos - startPos).Magnitude
    if distance < 1 then 
        frame.Visible = false 
        return 
    end
    frame.Visible = true
    frame.Size = UDim2.new(0, distance, 0, 1.5)
    frame.Position = UDim2.new(0, (startPos.X + endPos.X) / 2, 0, (startPos.Y + endPos.Y) / 2)
    frame.Rotation = math.deg(math.atan2(endPos.Y - startPos.Y, endPos.X - startPos.X))
    frame.BackgroundColor3 = color
end

local function clearESP(p)
    if espData[p] then
        if espData[p].Highlight then espData[p].Highlight:Destroy() end
        if espData[p].Billboard then espData[p].Billboard:Destroy() end
        if espData[p].Line then espData[p].Line:Destroy() end
        espData[p] = nil
    end
end

addConnection(RunService.RenderStepped:Connect(function()
    for p, _ in pairs(espData) do
        if not p.Parent or not isAlive(p) or (not state.espEnabled and not state.snaplines) then clearESP(p) end
    end
    
    if not state.espEnabled and not state.snaplines then return end
    
    local originPos = camera.CFrame.Position
    local myChar = getCharacter(player)
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
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
                        
                        local line = Instance.new("Frame")
                        line.BorderSizePixel = 0
                        line.AnchorPoint = Vector2.new(0.5, 0.5)
                        line.Parent = snapGui
                        
                        espData[p] = { Highlight = hl, Billboard = bb, NameLabel = nL, InfoLabel = iL, Line = line }
                    end
                    
                    local data = espData[p]
                    local color = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
                    local isVis = isVisible(targetPart)
                    local displayColor = isVis and Color3.fromRGB(200, 50, 255) or color 
                    
                    if state.espEnabled then
                        data.Highlight.Enabled = true
                        data.Billboard.Enabled = true
                        data.Highlight.FillColor = displayColor
                        data.Highlight.OutlineColor = displayColor
                        local hum = getHumanoid(eChar)
                        local health = hum and math.floor(hum.Health) or 0
                        data.InfoLabel.Text = string.format("♥ %d | %dm", health, math.floor(dist))
                    else
                        data.Highlight.Enabled = false
                        data.Billboard.Enabled = false
                    end
                    
                    if state.snaplines then
                        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen and screenPos.Z > 0 then
                            local startPos = values.snapOrigin == "Dưới" and Vector2.new(screenSize.X / 2, screenSize.Y) or Vector2.new(screenSize.X / 2, screenSize.Y / 2)
                            local endPos = Vector2.new(screenPos.X, screenPos.Y)
                            DrawLine(data.Line, startPos, endPos, displayColor)
                        else
                            data.Line.Visible = false
                        end
                    else
                        data.Line.Visible = false
                    end
                else 
                    clearESP(p) 
                end
            end
        end
    end
end))

-- ====== LOOP CHUNG: AIMBOT & AUTO SHOOT & HUD ======
addConnection(RunService.RenderStepped:Connect(function()
    if camera.FieldOfView ~= values.camFov and main.Visible == false then pcall(function() camera.FieldOfView = values.camFov end) end

    if state.aimbot or state.autoFire or state.showTargetHud then
        updateNearestEnemy()
    else
        currentAimbotTargetPart = nil
        currentTargetPlayer = nil
    end

    if state.showTargetHud and currentAimbotTargetPart and currentTargetPlayer then
        targetFrame.Visible = true
        targetName.Text = "Tên: " .. currentTargetPlayer.DisplayName
        local hum = getHumanoid(getCharacter(currentTargetPlayer))
        local hp = hum and math.floor(hum.Health) or 0
        targetHealth.Text = "Máu: " .. hp .. "/100"
        
        if hp < 30 then targetHealth.TextColor3 = Color3.fromRGB(255, 50, 50)
        elseif hp < 70 then targetHealth.TextColor3 = Color3.fromRGB(255, 200, 50)
        else targetHealth.TextColor3 = Color3.fromRGB(50, 255, 50) end
    else
        targetFrame.Visible = false
    end

    if currentAimbotTargetPart then
        if state.aimbot then
            local targetVelocity = Vector3.new(0,0,0)
            if currentAimbotTargetPart:IsA("BasePart") then
                targetVelocity = currentAimbotTargetPart.AssemblyLinearVelocity
                if targetVelocity.Magnitude > 150 then targetVelocity = targetVelocity.Unit * 150 end -- Khử nhiễu gia tốc R6
            end
            
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
        if state.autoFire then executeAutoShoot() end
    end
end))

-- ====== LOOP NGƯỜI CHƠI (PLAYER MODS) ======
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
                        handle.Transparency = 0.5
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
    
    if state.spinbot then
        local myRoot = getCharacter(player) and getCharacter(player):FindFirstChild("HumanoidRootPart")
        if myRoot then myRoot.CFrame = myRoot.CFrame * CFrame.Angles(0, math.rad(values.spinSpeed), 0) end
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
        
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        
        pcall(function()
            local controlModule = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
            local inputVector = controlModule:GetMoveVector()
            if inputVector.Magnitude > 0 then moveDir = (camera.CFrame.RightVector * inputVector.X) - (camera.CFrame.LookVector * inputVector.Z) end
        end)
        
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0,1,0) end
        
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
    if snapGui then snapGui:Destroy() end
    if targetHudGui then targetHudGui:Destroy() end
    Lighting.Ambient = origAmbient
    Lighting.OutdoorAmbient = origOutdoorAmbient
end)

print("[YSL Bá Sàn] R15/R6 Aim Precision Fixed & UI Scaled to 1536x1147 Perfectly!")
