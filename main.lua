--[[
    YSL Bá Sàn v17 – Target Marker & Smart Aimbot
    - Thay thế FOV Circle bằng Target Marker 3D xoay tròn trên mục tiêu.
    - Hỗ trợ chọn vị trí ngắm (Head/Torso) tương thích R6/R15.
    - Giao diện mượt mà, tối ưu cho Mobile.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

-- ====== TRẠNG THÁI & GIÁ TRỊ ======
local state = {
    aimbot = false, autoFire = false, hitboxExpander = false,
    espEnabled = false, showTargetMarker = true,
    speed = false, infJump = false, fly = false, noclip = false,
    fullbright = false, nofog = false, autoCollect = false, antiAFK = false,
}

local values = {
    aimbotSmoothing = 7, aimbotRange = 500, predictionAmount = 0.15,
    aimPart = "Head", -- "Head" hoặc "Torso"
    wallCheck = true, teamCheck = false,
    autoFireInterval = 0.1,
    hitboxMult = 4, espMaxDistance = 1000,
    speedVal = 30, jumpVal = 80, flySpeed = 50,
}

local connections = {}
local function addConnection(conn) table.insert(connections, conn) end
local function cleanupConnections()
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    connections = {}
end

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

-- Lấy Part để ngắm (Hỗ trợ R6 & R15)
local function getAimPart(char)
    if not char then return nil end
    if values.aimPart == "Head" then
        return char:FindFirstChild("Head")
    elseif values.aimPart == "Torso" then
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return char:FindFirstChild("HumanoidRootPart")
end

local function isVisible(targetPart)
    if not values.wallCheck then return true end
    if not targetPart or not targetPart.Parent then return false end
    
    local character = targetPart.Parent
    local myChar = getCharacter(player)
    
    local origin = camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {myChar, camera}
    
    local direction = (targetPart.Position - origin).Unit * values.aimbotRange
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if not result or (result.Instance and result.Instance:IsDescendantOf(character)) then 
        return true 
    end
    return false
end

-- 캐시 lại mục tiêu gần nhất
local currentAimbotTarget = nil

local function updateNearestEnemy()
    local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestDist = math.huge
    local bestPart = nil
    
    local originPos = camera.CFrame.Position
    local myChar = getCharacter(player)
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then originPos = myRoot.Position end 
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and isAlive(p) then
            local eChar = getCharacter(p)
            local targetPart = getAimPart(eChar)
            
            if targetPart then
                local dist3D = (originPos - targetPart.Position).Magnitude
                if dist3D <= values.aimbotRange then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                    -- Chỉ lấy mục tiêu đang ở trên màn hình
                    if onScreen and screenPos.Z > 0 then
                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        -- Không cần FOV nữa, ưu tiên mục tiêu gần tâm màn hình nhất, thỏa mãn wallcheck
                        if isVisible(targetPart) then
                            if screenDist < bestDist then
                                bestDist = screenDist
                                bestPart = targetPart
                            end
                        end
                    end
                end
            end
        end
    end
    currentAimbotTarget = bestPart
end

local function attack()
    local char = getCharacter(player)
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then tool:Activate() end
end

-- ====== TARGET MARKER (TÂM ẢO 3D) ======
local targetMarker = Instance.new("BillboardGui")
targetMarker.Name = "YSL_TargetMarker"
targetMarker.Size = UDim2.new(0, 80, 0, 80) -- Kích thước tâm
targetMarker.AlwaysOnTop = true
targetMarker.Enabled = false

local markerImage = Instance.new("ImageLabel")
markerImage.Size = UDim2.new(1, 0, 1, 0)
markerImage.BackgroundTransparency = 1
-- ID hình tâm ảo (Bạn có thể thay bằng ID decal hình ngôi sao giống trong ảnh)
markerImage.Image = "rbxassetid://12812239617" 
markerImage.ImageColor3 = Color3.fromRGB(255, 50, 50)
markerImage.Parent = targetMarker

-- Đặt Marker vào CoreGui hoặc PlayerGui để không bị xóa khi nhân vật chết
targetMarker.Parent = playerGui

local markerRotation = 0
addConnection(RunService.RenderStepped:Connect(function(dt)
    if state.aimbot and state.showTargetMarker and currentAimbotTarget then
        targetMarker.Enabled = true
        targetMarker.Adornee = currentAimbotTarget
        
        -- Hiệu ứng xoay mượt mà
        markerRotation = markerRotation + (dt * 150) -- Tốc độ xoay
        markerImage.Rotation = markerRotation
        
        -- Hiệu ứng nhịp đập nhẹ (Pulse)
        local pulse = math.sin(tick() * 5) * 0.1 + 0.9
        markerImage.Size = UDim2.new(pulse, 0, pulse, 0)
    else
        targetMarker.Enabled = false
        targetMarker.Adornee = nil
    end
end))

-- ====== GIAO DIỆN FLUENT UI ======
if playerGui:FindFirstChild("YSLBaSan_v17") then playerGui.YSLBaSan_v17:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "YSLBaSan_v17"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local openBtn = Instance.new("ImageButton")
openBtn.Size = UDim2.new(0, 50, 0, 50)
openBtn.Position = UDim2.new(0, 15, 0, 15)
openBtn.BackgroundTransparency = 1
openBtn.Image = "rbxassetid://84705282139911" 
openBtn.ScaleType = Enum.ScaleType.Fit
openBtn.Parent = gui

local main = Instance.new("CanvasGroup")
main.Size = UDim2.new(0, 550, 0, 420)
main.Position = UDim2.new(0.5, -275, 0.5, -210)
main.BackgroundColor3 = Color3.fromRGB(15, 15, 18) -- Đen nhám hơn
main.BorderSizePixel = 0
main.Visible = false
main.GroupTransparency = 1 
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
Instance.new("UIStroke", main).Color = Color3.fromRGB(45, 45, 55)

local menuScale = Instance.new("UIScale")
menuScale.Scale = 0.8
menuScale.Parent = main

local isMenuOpen = false
local function toggleMenu()
    isMenuOpen = not isMenuOpen
    if isMenuOpen then
        main.Visible = true
        TweenService:Create(main, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
        TweenService:Create(menuScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    else
        local closeFade = TweenService:Create(main, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {GroupTransparency = 1})
        local closeScale = TweenService:Create(menuScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0.8})
        closeFade:Play()
        closeScale:Play()
        closeFade.Completed:Connect(function() if not isMenuOpen then main.Visible = false end end)
    end
end
openBtn.MouseButton1Click:Connect(toggleMenu)

local dragging, dragInput, dragStart, startPos
local function updateDrag(input)
    local delta = input.Position - dragStart
    main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then updateDrag(input) end
end)

local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 140, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local menuTitle = Instance.new("TextLabel")
menuTitle.Size = UDim2.new(1, 0, 0, 50)
menuTitle.BackgroundTransparency = 1
menuTitle.Text = "YSL Bá Sàn"
menuTitle.TextColor3 = Color3.fromRGB(255, 50, 80) -- Màu đỏ chủ đạo
menuTitle.Font = Enum.Font.GothamBold
menuTitle.TextSize = 18
menuTitle.Parent = sidebar

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -140, 1, 0)
container.Position = UDim2.new(0, 140, 0, 0)
container.BackgroundTransparency = 1
container.Parent = main

local tabTitle = Instance.new("TextLabel")
tabTitle.Size = UDim2.new(1, -40, 0, 50)
tabTitle.Position = UDim2.new(0, 20, 0, 0)
tabTitle.BackgroundTransparency = 1
tabTitle.Text = "Ngắm Bắn"
tabTitle.TextColor3 = Color3.new(1, 1, 1)
tabTitle.Font = Enum.Font.GothamBold
tabTitle.TextSize = 22
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.Parent = container

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -30, 1, -60)
contentScroll.Position = UDim2.new(0, 15, 0, 50)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 2
contentScroll.CanvasSize = UDim2.new(0,0,0,0)
contentScroll.Parent = container

local tabs = {}
local tabContents = {}
local tabConfigs = {
    {name = "Ngắm Bắn", icon = "rbxassetid://3944680095"},
    {name = "Hiển Thị", icon = "rbxassetid://3926305904"},
    {name = "Di Chuyển", icon = "rbxassetid://3926307971"},
    {name = "Khác", icon = "rbxassetid://3926305904"},
}

for i, cfg in ipairs(tabConfigs) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 40)
    btn.Position = UDim2.new(0, 10, 0, 50 + (i-1)*45)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(255, 50, 80) or Color3.fromRGB(30, 30, 36)
    btn.Text = "   " .. cfg.name
    btn.TextColor3 = i == 1 and Color3.new(1, 1, 1) or Color3.new(0.7, 0.7, 0.7)
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 14
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = sidebar
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

    -- Hiệu ứng Hover
    btn.MouseEnter:Connect(function()
        if btn.BackgroundColor3 ~= Color3.fromRGB(255, 50, 80) then
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 48)}):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if btn.BackgroundColor3 ~= Color3.fromRGB(255, 50, 80) then
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(30, 30, 36)}):Play()
        end
    end)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundTransparency = 1
    frame.Visible = i == 1
    frame.Parent = contentScroll
    tabContents[i] = frame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Parent = frame

    btn.MouseButton1Click:Connect(function()
        for j, f in ipairs(tabContents) do f.Visible = false end
        frame.Visible = true
        tabTitle.Text = cfg.name
        for j, b in ipairs(tabs) do 
            b.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
            b.TextColor3 = Color3.new(0.7, 0.7, 0.7)
        end
        btn.BackgroundColor3 = Color3.fromRGB(255, 50, 80)
        btn.TextColor3 = Color3.new(1, 1, 1)
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 20)
    end)
    tabs[i] = btn
end

-- Hàm tạo Nút Chuyển Đổi Trạng Thái (Dropdown đơn giản)
local function createButtonOption(parent, text, options, defaultOption, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 40)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 1, 0)
    l.Position = UDim2.new(0, 15, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.4, 0, 0, 26)
    btn.Position = UDim2.new(1, -15 - (0.4 * parent.AbsoluteSize.X), 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    btn.Text = defaultOption
    btn.TextColor3 = Color3.fromRGB(255, 100, 100)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

    local currentIndex = 1
    for i, v in ipairs(options) do
        if v == defaultOption then currentIndex = i; break end
    end

    btn.MouseButton1Click:Connect(function()
        currentIndex = currentIndex + 1
        if currentIndex > #options then currentIndex = 1 end
        btn.Text = options[currentIndex]
        
        local pop = TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Size = UDim2.new(0.38, 0, 0, 22)})
        pop:Play()
        pop.Completed:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Size = UDim2.new(0.4, 0, 0, 26)}):Play()
        end)
        
        callback(options[currentIndex])
    end)
    
    -- Xử lý Resize an toàn
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        if parent.AbsoluteSize.X > 0 then
            btn.Position = UDim2.new(1, -15 - (0.4 * parent.AbsoluteSize.X), 0.5, -13)
        end
    end)
end


local function createToggle(parent, text, default, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 40)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.7, 0, 1, 0)
    l.Position = UDim2.new(0, 15, 0, 0)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 40, 0, 20)
    toggleBtn.Position = UDim2.new(1, -55, 0.5, -10)
    toggleBtn.BackgroundColor3 = default and Color3.fromRGB(255, 50, 80) or Color3.fromRGB(60, 60, 65)
    toggleBtn.Text = ""
    toggleBtn.Parent = f
    Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame")
    circle.Size = UDim2.new(0, 16, 0, 16)
    circle.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    circle.BackgroundColor3 = Color3.new(1, 1, 1)
    circle.Parent = toggleBtn
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local active = default
    local baseTweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

    local function toggle()
        active = not active
        local targetPos = active and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
        local targetColor = active and Color3.fromRGB(255, 50, 80) or Color3.fromRGB(60, 60, 65)
        
        TweenService:Create(circle, baseTweenInfo, {Position = targetPos}):Play()
        TweenService:Create(toggleBtn, baseTweenInfo, {BackgroundColor3 = targetColor}):Play()
        
        local squeeze = TweenService:Create(circle, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Size = UDim2.new(0, 22, 0, 12)})
        squeeze:Play()
        squeeze.Completed:Connect(function()
            TweenService:Create(circle, TweenInfo.new(0.2, Enum.EasingStyle.Bounce), {Size = UDim2.new(0, 16, 0, 16)}):Play()
        end)
        
        callback(active)
    end

    toggleBtn.MouseButton1Click:Connect(toggle)
    f.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then toggle() end end)
end

local function addSlider(parent, text, min, max, default, step, callback)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, 50)
    f.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
    f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0.5, 0, 0, 20)
    l.Position = UDim2.new(0, 15, 0, 5)
    l.BackgroundTransparency = 1
    l.Text = text
    l.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    l.Font = Enum.Font.GothamMedium
    l.TextSize = 14
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = f
    
    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.5, -15, 0, 20)
    valLabel.Position = UDim2.new(0.5, 0, 0, 5)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(default)
    valLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    valLabel.Font = Enum.Font.GothamMedium
    valLabel.TextSize = 14
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = f

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, -30, 0, 4)
    track.Position = UDim2.new(0, 15, 0, 35)
    track.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    track.Parent = f
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 50, 80)
    fill.Parent = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("TextButton")
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = UDim2.new((default-min)/(max-min), -6, 0.5, -6)
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

-- Tab 1: Ngắm Bắn
createToggle(tabContents[1], "Aimbot (Mượt)", false, function(s) state.aimbot = s end)
createButtonOption(tabContents[1], "Vị Trí Ngắm", {"Head", "Torso"}, values.aimPart, function(v) values.aimPart = v end)
addSlider(tabContents[1], "Độ Mượt (Nhỏ = Dính)", 1, 20, values.aimbotSmoothing, 0.5, function(v) values.aimbotSmoothing = v end)
addSlider(tabContents[1], "Tầm Xa Bắn", 10, 1000, values.aimbotRange, 10, function(v) values.aimbotRange = v end)
addSlider(tabContents[1], "Dự Đoán Chuyển Động", 0, 0.5, values.predictionAmount, 0.01, function(v) values.predictionAmount = v end)
createToggle(tabContents[1], "Kiểm Tra Vật Cản (Wall Check)", true, function(s) values.wallCheck = s end)
createToggle(tabContents[1], "Kiểm Tra Đồng Đội", false, function(s) values.teamCheck = s end) 
createToggle(tabContents[1], "Tự Động Bắn (Auto Fire)", false, function(s) state.autoFire = s end)
createToggle(tabContents[1], "Mở Rộng Hitbox (Đánh xa)", false, function(s) state.hitboxExpander = s end)
addSlider(tabContents[1], "Hệ Số Hitbox", 1.5, 10, values.hitboxMult, 0.5, function(v) values.hitboxMult = v end)

-- Tab 2: Hiển Thị
createToggle(tabContents[2], "Hiện Tâm Ảo (Target Marker)", true, function(s) state.showTargetMarker = s end)
createToggle(tabContents[2], "Bật ESP (Xuyên Tường)", false, function(s) state.espEnabled = s end)
addSlider(tabContents[2], "Khoảng Cách ESP", 50, 1500, values.espMaxDistance, 10, function(v) values.espMaxDistance = v end)
createToggle(tabContents[2], "Sáng Màn Hình (Fullbright)", false, function(s) 
    state.fullbright = s; Lighting.Brightness = s and 3 or 1; Lighting.ClockTime = s and 14 or 12
end)
createToggle(tabContents[2], "Tắt Sương Mù (No Fog)", false, function(s) 
    state.nofog = s; Lighting.FogEnd = s and 100000 or 1000 
end)

-- Tab 3 & 4: Di Chuyển & Khác
createToggle(tabContents[3], "Chạy Nhanh (Speed)", false, function(s) state.speed = s end)
addSlider(tabContents[3], "Tốc Độ Chạy", 16, 150, values.speedVal, 1, function(v) values.speedVal = v end)
createToggle(tabContents[3], "Nhảy Cao (Jump)", false, function(s) state.infJump = s end)
addSlider(tabContents[3], "Lực Nhảy", 50, 300, values.jumpVal, 5, function(v) values.jumpVal = v end)
createToggle(tabContents[3], "Bay (Fly)", false, function(s) state.fly = s end)
addSlider(tabContents[3], "Tốc Độ Bay", 20, 200, values.flySpeed, 5, function(v) values.flySpeed = v end)
createToggle(tabContents[3], "Đi Xuyên Tường (Noclip)", false, function(s) state.noclip = s end)

createToggle(tabContents[4], "Tự Động Nhặt Đồ", false, function(s) state.autoCollect = s end)
createToggle(tabContents[4], "Chống Văng Game (Anti-AFK)", false, function(s) state.antiAFK = s end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0, 10)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(150, 150, 150)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.Parent = main
closeBtn.MouseButton1Click:Connect(toggleMenu)

task.wait(0.1)
for i, frame in ipairs(tabContents) do
    if frame.Visible then contentScroll.CanvasSize = UDim2.new(0, 0, 0, frame.UIListLayout.AbsoluteContentSize.Y + 20) end
end

-- ====== ESP ======
local espData = {} 
local function clearESP(p)
    if espData[p] then
        if espData[p].Highlight then espData[p].Highlight:Destroy() end
        if espData[p].Billboard then espData[p].Billboard:Destroy() end
        espData[p] = nil
    end
end

addConnection(RunService.RenderStepped:Connect(function()
    for p, _ in pairs(espData) do
        if not state.espEnabled or not p.Parent or not isAlive(p) then clearESP(p) end
    end
    
    if not state.espEnabled then return end
    
    local originPos = camera.CFrame.Position
    local myChar = getCharacter(player)
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myRoot then originPos = myRoot.Position end 

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and isAlive(p) then
            local eChar = getCharacter(p)
            local targetPart = getAimPart(eChar)
            
            if targetPart then
                local dist = (originPos - targetPart.Position).Magnitude
                if dist <= values.espMaxDistance then
                    if not espData[p] then
                        local highlight = Instance.new("Highlight")
                        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                        highlight.FillTransparency = 0.6
                        highlight.OutlineTransparency = 0
                        highlight.Parent = eChar
                        
                        local billboard = Instance.new("BillboardGui")
                        billboard.Size = UDim2.new(0, 100, 0, 40)
                        billboard.StudsOffset = Vector3.new(0, 3, 0)
                        billboard.AlwaysOnTop = true
                        billboard.Adornee = eChar:FindFirstChild("Head") or targetPart 
                        billboard.Parent = eChar
                        
                        local nameLabel = Instance.new("TextLabel")
                        nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.Text = p.DisplayName
                        nameLabel.TextColor3 = Color3.new(1, 1, 1)
                        nameLabel.Font = Enum.Font.GothamBold
                        nameLabel.TextSize = 12
                        nameLabel.TextStrokeTransparency = 0.5
                        nameLabel.Parent = billboard
                        
                        local infoLabel = Instance.new("TextLabel")
                        infoLabel.Size = UDim2.new(1, 0, 0.5, 0)
                        infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
                        infoLabel.BackgroundTransparency = 1
                        infoLabel.Text = ""
                        infoLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
                        infoLabel.Font = Enum.Font.GothamMedium
                        infoLabel.TextSize = 10
                        infoLabel.TextStrokeTransparency = 0.5
                        infoLabel.Parent = billboard
                        
                        espData[p] = { Highlight = highlight, Billboard = billboard, NameLabel = nameLabel, InfoLabel = infoLabel }
                    end
                    
                    local data = espData[p]
                    local color = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
                    
                    if isVisible(targetPart) then
                        data.Highlight.FillColor = Color3.fromRGB(255, 50, 50)
                        data.Highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
                    else
                        data.Highlight.FillColor = color
                        data.Highlight.OutlineColor = color
                    end
                    
                    local hum = getHumanoid(eChar)
                    local health = hum and math.floor(hum.Health) or 0
                    data.InfoLabel.Text = string.format("♥ %d | %dm", health, math.floor(dist))
                    
                    if health < 30 then data.InfoLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
                    elseif health < 70 then data.InfoLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
                    else data.InfoLabel.TextColor3 = Color3.fromRGB(50, 255, 50) end
                else 
                    clearESP(p) 
                end
            end
        end
    end
end))

-- ====== LOOP CHUNG CHO AIMBOT VÀ AUTOFIRE ======
addConnection(RunService.RenderStepped:Connect(function()
    if state.aimbot or state.autoFire then
        updateNearestEnemy()
    else
        currentAimbotTarget = nil
    end

    if state.aimbot and currentAimbotTarget then
        local targetVelocity = currentAimbotTarget.AssemblyLinearVelocity or Vector3.new(0,0,0)
        local predictedPos = currentAimbotTarget.Position + (targetVelocity * values.predictionAmount)
        local camPos = camera.CFrame.Position
        local desiredCFrame = CFrame.lookAt(camPos, predictedPos)
        
        if values.aimbotSmoothing <= 1 then
            camera.CFrame = desiredCFrame
        else
            local alpha = math.clamp(1 / values.aimbotSmoothing, 0.05, 1)
            camera.CFrame = camera.CFrame:Lerp(desiredCFrame, alpha)
        end
    end
end))

local lastAutoFire = 0
addConnection(RunService.Heartbeat:Connect(function()
    if not state.autoFire then return end
    
    if currentAimbotTarget then
        local now = tick()
        if now - lastAutoFire >= values.autoFireInterval then
            lastAutoFire = now
            attack()
        end
    end
end))

-- ====== CÁC CHỨC NĂNG KHÁC ======
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

addConnection(RunService.Heartbeat:Connect(function()
    if not state.autoCollect then return end
    local char = getCharacter(player)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    for _, prompt in ipairs(ProximityPromptService:GetPrompts()) do
        if prompt.Enabled and prompt.Parent and prompt.Parent:IsA("BasePart") then
            if (root.Position - prompt.Parent.Position).Magnitude <= prompt.MaxActivationDistance then 
                pcall(function() fireproximityprompt(prompt) end)
            end
        end
    end
end))

local afkConnection
addConnection(RunService.RenderStepped:Connect(function()
    if state.antiAFK then
        if not afkConnection then
            afkConnection = player.Idled:Connect(function()
                VirtualUser:Button2Down(Vector2.new(0,0), camera.CFrame)
                task.wait(1)
                VirtualUser:Button2Up(Vector2.new(0,0), camera.CFrame)
            end)
        end
    else
        if afkConnection then afkConnection:Disconnect(); afkConnection = nil end
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
end)

print("[YSL Bá Sàn v17] Nâng Cấp Target Marker, Smart Aim (Head/Torso), R6/R15 & Giao Diện.")
