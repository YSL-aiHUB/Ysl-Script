--[[
    YSL BÁ SÀN v24 - LUXURY EDITION (OPTIMIZED FOR IOS/MOBILE)
    Creator: Y Seav Long
    FB: Y Seav Long | Dis: yslaiplus | Zalo: +84 372322494
    
    * Cập nhật:
    - Target Star & Snapline Star (Sử dụng đúng ID Ảnh Roblox).
    - Zero Delay AutoFire (Fix khựng trên màn hình cảm ứng).
    - Compact UI: Giao diện Luxury nhỏ gọn, chia form vuốt chạm dễ dàng.
    - An toàn 100%, không đen màn hình, sẵn sàng Loadstring GitHub.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

-- ====== ID HÌNH ẢNH ======
local MENU_ICON_ID = "rbxassetid://84705282139911"
local STAR_ICON_ID = "rbxassetid://12812239617"

-- ====== TRẠNG THÁI & THIẾT LẬP ======
local state = {
    aimbot = false, autoFire = false, hitboxExpander = false,
    espEnabled = false, showTargetMarker = true, snaplines = false,
    speed = false, infJump = false, fly = false, noclip = false,
    fullbright = false,
}

local values = {
    aimSmoothing = 6, aimRange = 1500, predictionAmount = 0.12,
    aimPart = "Head", wallCheck = true, teamCheck = false,
    fireInterval = 0.05, hitboxMult = 4, espDist = 2000,
    speedVal = 40, jumpVal = 80, flySpeed = 50,
}

local connections = {}
local function addConn(c) table.insert(connections, c) end

local origAmbient = Lighting.Ambient
local origOutdoorAmbient = Lighting.OutdoorAmbient
local origFogEnd = Lighting.FogEnd

-- Hiệu ứng mờ nền mượt mà
local blurEffect = Instance.new("BlurEffect")
blurEffect.Size = 0
blurEffect.Parent = Lighting

-- ====== HÀM TIỆN ÍCH AN TOÀN ======
local function getChar(p) return p and p.Character end
local function getHum(char) return char and char:FindFirstChildOfClass("Humanoid") end
local function isAlive(p)
    local hum = getHum(getChar(p))
    return hum and hum.Health > 0
end

local function isEnemy(tPlayer)
    if not tPlayer or tPlayer == player then return false end
    if not values.teamCheck then return true end
    if player.Team and tPlayer.Team and player.Team == tPlayer.Team then return false end
    return true
end

local function getTargetPart(char)
    if not char then return nil end
    if values.aimPart == "Head" then
        return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
    else
        return char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
end

local function isVisible(part)
    if not values.wallCheck then return true end
    if not part then return false end
    local origin = camera.CFrame.Position
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {getChar(player), camera, part.Parent}
    local dir = (part.Position - origin).Unit * values.aimRange
    local result = Workspace:Raycast(origin, dir, rayParams)
    return result == nil
end

-- ====== HỆ THỐNG MỤC TIÊU & AUTOFIRE ======
local currentTarget = nil
local lastShot = 0

local function updateTarget()
    local center = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local minDist = math.huge
    local bestPart = nil
    
    local myRoot = getChar(player) and getChar(player):FindFirstChild("HumanoidRootPart")
    local origin = myRoot and myRoot.Position or camera.CFrame.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and isAlive(p) then
            local tPart = getTargetPart(getChar(p))
            if tPart then
                local dist3D = (origin - tPart.Position).Magnitude
                if dist3D <= values.aimRange then
                    local screenPos, onScreen = camera:WorldToViewportPoint(tPart.Position)
                    if onScreen and screenPos.Z > 0 then
                        local dist2D = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                        if isVisible(tPart) and dist2D < minDist then
                            minDist = dist2D
                            bestPart = tPart
                        end
                    end
                end
            end
        end
    end
    currentTarget = bestPart
end

local function handleAutoFire()
    local now = tick()
    if now - lastShot < values.fireInterval then return end
    lastShot = now

    local char = getChar(player)
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then
            -- Bọc trong task.spawn để không làm khựng cảm ứng iPhone
            task.spawn(function()
                pcall(function() tool:Activate() end)
            end)
        end
    end
end

-- ====== GIAO DIỆN LUXURY UI ======
if playerGui:FindFirstChild("YSL_BaSan_Luxury") then playerGui.YSL_BaSan_Luxury:Destroy() end

local yslGui = Instance.new("ScreenGui")
yslGui.Name = "YSL_BaSan_Luxury"
yslGui.ResetOnSpawn = false
yslGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
yslGui.Parent = playerGui

-- GUI riêng để vẽ Snapline đè lên mọi thứ (bỏ qua Topbar)
local snapGui = Instance.new("ScreenGui")
snapGui.Name = "YSL_Snaplines"
snapGui.IgnoreGuiInset = true
snapGui.ResetOnSpawn = false
snapGui.Parent = playerGui

-- === NÚT MỞ MENU (VIÊN THUỐC) ===
local openBtn = Instance.new("Frame")
openBtn.Size = UDim2.new(0, 130, 0, 42)
openBtn.Position = UDim2.new(0, 15, 0, 15)
openBtn.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
openBtn.Parent = yslGui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 2
local goldGradient = Instance.new("UIGradient")
goldGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 215, 0)), -- Gold
    ColorSequenceKeypoint.new(1, Color3.fromRGB(138, 43, 226))  -- Royal Purple
}
goldGradient.Parent = btnStroke
btnStroke.Parent = openBtn

local btnIcon = Instance.new("ImageLabel")
btnIcon.Size = UDim2.new(0, 26, 0, 26)
btnIcon.Position = UDim2.new(0, 10, 0.5, -13)
btnIcon.BackgroundTransparency = 1
btnIcon.Image = MENU_ICON_ID
btnIcon.Parent = openBtn

local btnText = Instance.new("TextLabel")
btnText.Size = UDim2.new(1, -45, 1, 0)
btnText.Position = UDim2.new(0, 42, 0, 0)
btnText.BackgroundTransparency = 1
btnText.Text = "MENU YSL"
btnText.TextColor3 = Color3.fromRGB(255, 215, 0)
btnText.Font = Enum.Font.GothamBlack
btnText.TextSize = 13
btnText.TextXAlignment = Enum.TextXAlignment.Left
btnText.Parent = openBtn

local clickZone = Instance.new("TextButton")
clickZone.Size = UDim2.new(1, 0, 1, 0)
clickZone.BackgroundTransparency = 1
clickZone.Text = ""
clickZone.Parent = openBtn

-- Kéo thả nút mở Menu
local dragBtn, dragBtnInput, dragBtnStart, startBtnPos
clickZone.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragBtn = true; dragBtnStart = input.Position; startBtnPos = openBtn.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragBtn = false end end)
    end
end)
clickZone.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragBtnInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragBtnInput and dragBtn then
        local delta = input.Position - dragBtnStart
        openBtn.Position = UDim2.new(startBtnPos.X.Scale, startBtnPos.X.Offset + delta.X, startBtnPos.Y.Scale, startBtnPos.Y.Offset + delta.Y)
    end
end)

-- === MAIN MENU (COMPACT SIZE 480x300) ===
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 300)
main.Position = UDim2.new(0.5, -240, 0.5, -150)
main.BackgroundColor3 = Color3.new(1, 1, 1) 
main.BorderSizePixel = 0
main.Visible = false
main.ClipsDescendants = true
main.Parent = yslGui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local mainGrad = Instance.new("UIGradient")
mainGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 12, 18)), 
    ColorSequenceKeypoint.new(1, Color3.fromRGB(24, 18, 30))  
}
mainGrad.Rotation = 35
mainGrad.Parent = main

local mStroke = Instance.new("UIStroke")
mStroke.Thickness = 1.5
local msGrad = goldGradient:Clone(); msGrad.Parent = mStroke
mStroke.Parent = main

local mScale = Instance.new("UIScale")
mScale.Scale = 0
mScale.Parent = main

local menuOpen = false
clickZone.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if menuOpen then
        main.Visible = true
        TweenService:Create(mScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
        TweenService:Create(blurEffect, TweenInfo.new(0.35), {Size = 12}):Play()
    else
        local closeT = TweenService:Create(mScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
        closeT:Play(); TweenService:Create(blurEffect, TweenInfo.new(0.25), {Size = 0}):Play()
        closeT.Completed:Connect(function() if not menuOpen then main.Visible = false end end)
    end
end)

-- Kéo thả Main Menu
local dragMain, dragMainInput, dragMainStart, startMainPos
main.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragMain = true; dragMainStart = input.Position; startMainPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragMain = false end end)
    end
end)
main.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragMainInput = input end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == dragMainInput and dragMain then 
        local delta = input.Position - dragMainStart
        main.Position = UDim2.new(startMainPos.X.Scale, startMainPos.X.Offset + delta.X, startMainPos.Y.Scale, startMainPos.Y.Offset + delta.Y)
    end
end)

-- === SIDEBAR (DANH MỤC TÍNH NĂNG) ===
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sidebar.BackgroundTransparency = 0.5 
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local titleMain = Instance.new("TextLabel")
titleMain.Size = UDim2.new(1, 0, 0, 45)
titleMain.Position = UDim2.new(0, 0, 0, 5)
titleMain.BackgroundTransparency = 1
titleMain.Text = "YSL"
titleMain.TextColor3 = Color3.fromRGB(255, 215, 0)
titleMain.Font = Enum.Font.GothamBlack
titleMain.TextSize = 22
titleMain.Parent = sidebar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -30, 0, 12)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.Parent = main
closeBtn.MouseButton1Click:Connect(function() clickZone.MouseButton1Click:Fire() end)

-- === KHU VỰC CUỘN NỘI DUNG (DỄ VUỐT) ===
local container = Instance.new("Frame")
container.Size = UDim2.new(1, -135, 1, -10)
container.Position = UDim2.new(0, 135, 0, 5)
container.BackgroundTransparency = 1
container.Parent = main

local tabNameDisplay = Instance.new("TextLabel")
tabNameDisplay.Size = UDim2.new(1, 0, 0, 35)
tabNameDisplay.Position = UDim2.new(0, 5, 0, 0)
tabNameDisplay.BackgroundTransparency = 1
tabNameDisplay.Text = "Aimbot"
tabNameDisplay.TextColor3 = Color3.new(1, 1, 1)
tabNameDisplay.Font = Enum.Font.GothamBold
tabNameDisplay.TextSize = 20
tabNameDisplay.TextXAlignment = Enum.TextXAlignment.Left
tabNameDisplay.Parent = container

-- Phân vùng cuộn được tô đen mờ để dễ nhận diện vuốt ngón tay
local scrollBg = Instance.new("Frame")
scrollBg.Size = UDim2.new(1, -5, 1, -40)
scrollBg.Position = UDim2.new(0, 0, 0, 35)
scrollBg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
scrollBg.BackgroundTransparency = 0.6
scrollBg.Parent = container
Instance.new("UICorner", scrollBg).CornerRadius = UDim.new(0, 8)

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -10, 1, -10)
contentScroll.Position = UDim2.new(0, 5, 0, 5)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 4
contentScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 215, 0)
contentScroll.CanvasSize = UDim2.new(0,0,0,0)
contentScroll.Parent = scrollBg

local tabs = {}
local tabFrames = {}
local tabList = {"Aimbot", "Visual", "Player", "Info"}

for i, name in ipairs(tabList) do
    local tBtn = Instance.new("TextButton")
    tBtn.Size = UDim2.new(1, -16, 0, 36)
    tBtn.Position = UDim2.new(0, 8, 0, 50 + (i-1)*42)
    tBtn.BackgroundColor3 = i == 1 and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(20, 20, 25)
    tBtn.Text = "  " .. name
    tBtn.TextColor3 = i == 1 and Color3.fromRGB(15, 15, 18) or Color3.fromRGB(180, 180, 180)
    tBtn.Font = Enum.Font.GothamBold
    tBtn.TextSize = 13
    tBtn.TextXAlignment = Enum.TextXAlignment.Left
    tBtn.Parent = sidebar
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(0, 6)

    local tFrame = Instance.new("Frame")
    tFrame.Size = UDim2.new(1, 0, 1, 0)
    tFrame.BackgroundTransparency = 1
    tFrame.Visible = i == 1
    tFrame.Parent = contentScroll
    tabFrames[i] = tFrame

    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 8)
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = tFrame

    tBtn.MouseButton1Click:Connect(function()
        for _, f in ipairs(tabFrames) do f.Visible = false end
        tFrame.Visible = true
        tabNameDisplay.Text = name
        for _, b in ipairs(tabs) do 
            b.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            b.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        tBtn.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
        tBtn.TextColor3 = Color3.fromRGB(15, 15, 18)
        contentScroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 15)
    end)
    tabs[i] = tBtn
end

-- === CÔNG CỤ TẠO CHỨC NĂNG ===
local function createDrop(parent, text, options, def, callback)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, -5, 0, 38); f.BackgroundColor3 = Color3.fromRGB(30, 30, 35); f.BackgroundTransparency = 0.4; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.5, 0, 1, 0); l.Position = UDim2.new(0, 10, 0, 0); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9,0.9,0.9); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0.35, 0, 0, 26); btn.Position = UDim2.new(1, -10 - (0.35 * parent.AbsoluteSize.X), 0.5, -13); btn.BackgroundColor3 = Color3.fromRGB(138, 43, 226); btn.Text = def; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local cur = 1; for i, v in ipairs(options) do if v == def then cur = i; break end end
    btn.MouseButton1Click:Connect(function()
        cur = cur + 1; if cur > #options then cur = 1 end
        btn.Text = options[cur]; callback(options[cur])
    end)
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if parent.AbsoluteSize.X > 0 then btn.Position = UDim2.new(1, -10 - (0.35 * parent.AbsoluteSize.X), 0.5, -13) end end)
end

local function createToggle(parent, text, default, callback)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, -5, 0, 38); f.BackgroundColor3 = Color3.fromRGB(30, 30, 35); f.BackgroundTransparency = 0.4; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.7, 0, 1, 0); l.Position = UDim2.new(0, 10, 0, 0); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9,0.9,0.9); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local tBtn = Instance.new("TextButton"); tBtn.Size = UDim2.new(0, 38, 0, 20); tBtn.Position = UDim2.new(1, -48, 0.5, -10); tBtn.BackgroundColor3 = default and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(50, 50, 55); tBtn.Text = ""; tBtn.Parent = f
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(1, 0)
    local cir = Instance.new("Frame"); cir.Size = UDim2.new(0, 16, 0, 16); cir.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8); cir.BackgroundColor3 = Color3.new(1,1,1); cir.Parent = tBtn
    Instance.new("UICorner", cir).CornerRadius = UDim.new(1, 0)
    local act = default
    local function toggle()
        act = not act
        TweenService:Create(cir, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {Position = act and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}):Play()
        TweenService:Create(tBtn, TweenInfo.new(0.25, Enum.EasingStyle.Quint), {BackgroundColor3 = act and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(50, 50, 55)}):Play()
        callback(act)
    end
    tBtn.MouseButton1Click:Connect(toggle)
    f.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then toggle() end end)
end

local function addSlider(parent, text, min, max, def, step, callback)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, -5, 0, 48); f.BackgroundColor3 = Color3.fromRGB(30, 30, 35); f.BackgroundTransparency = 0.4; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.5, 0, 0, 16); l.Position = UDim2.new(0, 10, 0, 6); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9,0.9,0.9); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = f
    local valL = Instance.new("TextLabel"); valL.Size = UDim2.new(0.5, -15, 0, 16); valL.Position = UDim2.new(0.5, 0, 0, 6); valL.BackgroundTransparency = 1; valL.Text = tostring(def); valL.TextColor3 = Color3.fromRGB(255, 215, 0); valL.Font = Enum.Font.GothamBold; valL.TextSize = 12; valL.TextXAlignment = Enum.TextXAlignment.Right; valL.Parent = f
    local track = Instance.new("Frame"); track.Size = UDim2.new(1, -20, 0, 4); track.Position = UDim2.new(0, 10, 0, 34); track.BackgroundColor3 = Color3.fromRGB(50, 50, 55); track.Parent = f; Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame"); fill.Size = UDim2.new((def-min)/(max-min), 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(138, 43, 226); fill.Parent = track; Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("TextButton"); knob.Size = UDim2.new(0, 16, 0, 16); knob.Position = UDim2.new((def-min)/(max-min), -8, 0.5, -8); knob.BackgroundColor3 = Color3.new(1,1,1); knob.Text = ""; knob.Parent = track; Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local val = def; local dragging = false
    local function update(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        val = min + relX * (max - min); if step > 0 then val = math.round(val/step)*step end
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0); knob.Position = UDim2.new((val - min) / (max - min), -8, 0.5, -8)
        valL.Text = step < 1 and string.format("%.2f", val) or tostring(math.floor(val)); callback(val)
    end
    knob.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end end)
end

-- ====== XÂY DỰNG CHỨC NĂNG ======
-- Tab 1: Aimbot
createToggle(tabFrames[1], "Bật Aimbot", false, function(s) state.aimbot = s end)
createDrop(tabFrames[1], "Vị Trí Ngắm", {"Head", "Torso"}, values.aimPart, function(v) values.aimPart = v end)
addSlider(tabFrames[1], "Độ Dính Tâm (Nhỏ = Aimlock)", 1, 20, values.aimSmoothing, 0.5, function(v) values.aimSmoothing = v end)
createToggle(tabFrames[1], "Auto Fire (Tự bắn mượt mà)", false, function(s) state.autoFire = s end)
createToggle(tabFrames[1], "Check Tường (Wallcheck)", true, function(s) values.wallCheck = s end)
addSlider(tabFrames[1], "Tầm Xa Quét Địch", 10, 2500, values.aimRange, 10, function(v) values.aimRange = v end)

-- Tab 2: Visual (ESP & Snapline)
createToggle(tabFrames[2], "Tâm Ảo 3D (Ngôi sao bám địch)", true, function(s) state.showTargetMarker = s end)
createToggle(tabFrames[2], "Snaplines (Đường kẻ FFA + Sao)", false, function(s) state.snaplines = s end)
createToggle(tabFrames[2], "ESP Xuyên Tường", false, function(s) state.espEnabled = s end)
addSlider(tabFrames[2], "Khoảng Cách ESP", 50, 3000, values.espDist, 10, function(v) values.espDist = v end)
createToggle(tabFrames[2], "Sáng Map (Fullbright)", false, function(s) 
    state.fullbright = s
    Lighting.Ambient = s and Color3.new(1,1,1) or origAmbient
    Lighting.OutdoorAmbient = s and Color3.new(1,1,1) or origOutdoorAmbient
end)

-- Tab 3: Player
createToggle(tabFrames[3], "Chạy Nhanh (Speed)", false, function(s) state.speed = s end)
addSlider(tabFrames[3], "Tốc Độ Của Bạn", 16, 150, values.speedVal, 1, function(v) values.speedVal = v end)
createToggle(tabFrames[3], "Bay Tự Do (Fly)", false, function(s) state.fly = s end)
createToggle(tabFrames[3], "Nhảy Không Giới Hạn", false, function(s) state.infJump = s end)
createToggle(tabFrames[3], "Mở Rộng Hitbox (Đánh xa)", false, function(s) state.hitboxExpander = s end)
addSlider(tabFrames[3], "Kích Thước Hitbox", 1.5, 10, values.hitboxMult, 0.5, function(v) values.hitboxMult = v end)
createToggle(tabFrames[3], "Đi Xuyên Tường", false, function(s) state.noclip = s end)

-- Tab 4: Thông Tin Của Bạn
local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, -5, 1, -5)
infoBox.BackgroundColor3 = Color3.fromRGB(20, 15, 25)
infoBox.Parent = tabFrames[4]
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", infoBox).Color = Color3.fromRGB(255, 215, 0)

local iTitle = Instance.new("TextLabel")
iTitle.Size = UDim2.new(1, 0, 0, 40)
iTitle.BackgroundTransparency = 1
iTitle.Text = "👑 YSL CREATOR 👑"
iTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
iTitle.Font = Enum.Font.GothamBlack
iTitle.TextSize = 16
iTitle.Parent = infoBox

local iText = Instance.new("TextLabel")
iText.Size = UDim2.new(1, -20, 1, -50)
iText.Position = UDim2.new(0, 10, 0, 40)
iText.BackgroundTransparency = 1
iText.Text = "Menu được tối ưu hóa cho Mobile & FPS.\n\n🔹 FB: Y Seav Long\n🔹 Discord: yslaiplus\n🔹 Zalo: +84 372322494\n\nCảm ơn bạn đã sử dụng YSL Bá Sàn!"
iText.TextColor3 = Color3.new(0.9, 0.9, 0.9)
iText.Font = Enum.Font.GothamMedium
iText.TextSize = 13
iText.TextXAlignment = Enum.TextXAlignment.Left
iText.TextYAlignment = Enum.TextXAlignment.Top
iText.Parent = infoBox

task.wait(0.1)
for i, f in ipairs(tabFrames) do if f.Visible then contentScroll.CanvasSize = UDim2.new(0, 0, 0, f.UIListLayout.AbsoluteContentSize.Y + 15) end end

-- ====== TÂM ẢO NGÔI SAO (AIMBOT) ======
local targetMarkerGui = Instance.new("BillboardGui")
targetMarkerGui.Name = "YSL_Star3D"
targetMarkerGui.AlwaysOnTop = true
targetMarkerGui.LightInfluence = 0
targetMarkerGui.Enabled = false
targetMarkerGui.Parent = playerGui

local targetStarImg = Instance.new("ImageLabel")
targetStarImg.Size = UDim2.new(1, 0, 1, 0)
targetStarImg.BackgroundTransparency = 1
targetStarImg.Image = STAR_ICON_ID
targetStarImg.ImageColor3 = Color3.fromRGB(255, 215, 0)
targetStarImg.Parent = targetMarkerGui

-- ====== ESP & SNAPLINES FFA MƯỢT MÀ ======
local espPool = {}

local function removeESP(p)
    if espPool[p] then
        for _, v in pairs(espPool[p]) do pcall(function() v:Destroy() end) end
        espPool[p] = nil
    end
end

local globalRot = 0
addConn(RunService.RenderStepped:Connect(function(dt)
    globalRot = globalRot + (dt * 150)
    
    -- Xử lý Aimbot Star Marker
    if state.aimbot and state.showTargetMarker and currentTarget then
        targetMarkerGui.Enabled = true
        targetMarkerGui.Adornee = currentTarget
        targetMarkerGui.Size = values.aimPart == "Head" and UDim2.new(0,35,0,35) or UDim2.new(0,60,0,60)
        targetStarImg.Rotation = globalRot
        local scale = math.sin(tick() * 10) * 0.1 + 0.9
        targetStarImg.Size = UDim2.new(scale, 0, scale, 0)
    else
        targetMarkerGui.Enabled = false
        targetMarkerGui.Adornee = nil
    end

    -- Xử lý ESP & Snapline
    for p, _ in pairs(espPool) do
        if not p.Parent or not isAlive(p) or (not state.espEnabled and not state.snaplines) then removeESP(p) end
    end
    
    if not state.espEnabled and not state.snaplines then return end
    
    local myRoot = getChar(player) and getChar(player):FindFirstChild("HumanoidRootPart")
    local origin = myRoot and myRoot.Position or camera.CFrame.Position
    local scSize = camera.ViewportSize

    for _, p in ipairs(Players:GetPlayers()) do
        if isEnemy(p) and isAlive(p) then
            local tPart = getTargetPart(getChar(p))
            if tPart then
                local dist = (origin - tPart.Position).Magnitude
                if dist <= values.espDist then
                    if not espPool[p] then
                        local hl = Instance.new("Highlight"); hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.FillTransparency = 0.6; hl.OutlineTransparency = 0; hl.Parent = getChar(p)
                        local bb = Instance.new("BillboardGui"); bb.Size = UDim2.new(0, 100, 0, 40); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Adornee = tPart; bb.Parent = getChar(p)
                        local nL = Instance.new("TextLabel"); nL.Size = UDim2.new(1, 0, 0.5, 0); nL.BackgroundTransparency = 1; nL.Text = p.DisplayName; nL.TextColor3 = Color3.new(1,1,1); nL.Font = Enum.Font.GothamBold; nL.TextSize = 10; nL.Parent = bb
                        local iL = Instance.new("TextLabel"); iL.Size = UDim2.new(1, 0, 0.5, 0); iL.Position = UDim2.new(0, 0, 0.5, 0); iL.BackgroundTransparency = 1; iL.TextColor3 = Color3.fromRGB(0, 255, 0); iL.Font = Enum.Font.GothamMedium; iL.TextSize = 9; iL.Parent = bb
                        local line = Instance.new("Frame"); line.BorderSizePixel = 0; line.AnchorPoint = Vector2.new(0.5, 0.5); line.Parent = snapGui
                        local star = Instance.new("ImageLabel"); star.Size = UDim2.new(0, 25, 0, 25); star.AnchorPoint = Vector2.new(0.5, 0.5); star.BackgroundTransparency = 1; star.Image = STAR_ICON_ID; star.Parent = snapGui
                        espPool[p] = {hl=hl, bb=bb, nL=nL, iL=iL, line=line, star=star}
                    end
                    
                    local d = espPool[p]
                    local col = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
                    local vis = isVisible(tPart)
                    local lCol = vis and Color3.fromRGB(138, 43, 226) or col -- Địch trong tầm bắn -> Tím Royal
                    
                    if state.espEnabled then
                        d.hl.Enabled = true; d.bb.Enabled = true
                        d.hl.FillColor = lCol; d.hl.OutlineColor = lCol
                        local hum = getHum(getChar(p))
                        d.iL.Text = string.format("♥ %d | %dm", hum and math.floor(hum.Health) or 0, math.floor(dist))
                    else
                        d.hl.Enabled = false; d.bb.Enabled = false
                    end
                    
                    if state.snaplines then
                        local screenPos, onScreen = camera:WorldToViewportPoint(tPart.Position)
                        if onScreen and screenPos.Z > 0 then
                            d.line.Visible = true; d.star.Visible = true
                            local startP = Vector2.new(scSize.X / 2, scSize.Y) 
                            local endP = Vector2.new(screenPos.X, screenPos.Y)
                            local len = (endP - startP).Magnitude
                            local ang = math.atan2(endP.Y - startP.Y, endP.X - startP.X)
                            
                            d.line.Size = UDim2.new(0, len, 0, 1.5)
                            d.line.Position = UDim2.new(0, (startP.X + endP.X)/2, 0, (startP.Y + endP.Y)/2)
                            d.line.Rotation = math.deg(ang)
                            d.line.BackgroundColor3 = lCol
                            
                            -- Đính ngôi sao ID 12812239617 xoay tít ở đỉnh đầu
                            d.star.Position = UDim2.new(0, endP.X, 0, endP.Y)
                            d.star.ImageColor3 = lCol
                            d.star.Rotation = globalRot
                        else
                            d.line.Visible = false; d.star.Visible = false
                        end
                    else
                        d.line.Visible = false; d.star.Visible = false
                    end
                else removeESP(p) end
            end
        end
    end
end))

-- ====== LÕI AIMBOT & AUTO FIRE ======
addConn(RunService.RenderStepped:Connect(function()
    if state.aimbot or state.autoFire then updateTarget() else currentTarget = nil end

    if currentTarget then
        if state.aimbot then
            local vel = currentTarget.AssemblyLinearVelocity or Vector3.new(0,0,0)
            local pred = currentTarget.Position + (vel * values.predictionAmount)
            local dCFrame = CFrame.lookAt(camera.CFrame.Position, pred)
            if values.aimSmoothing <= 1 then camera.CFrame = dCFrame else
                camera.CFrame = camera.CFrame:Lerp(dCFrame, math.clamp(1 / values.aimSmoothing, 0.05, 1))
            end
        end
        if state.autoFire then handleAutoFire() end
    end
end))

-- ====== CÁC CHỨC NĂNG NGƯỜI CHƠI ======
addConn(RunService.Heartbeat:Connect(function()
    if state.hitboxExpander then
        local char = getChar(player)
        if char then
            for _, t in ipairs(char:GetChildren()) do
                if t:IsA("Tool") and t:FindFirstChild("Handle") and t.Handle:IsA("BasePart") then
                    if not t:GetAttribute("OrigSize") then t:SetAttribute("OrigSize", t.Handle.Size) end
                    t.Handle.Size = t:GetAttribute("OrigSize") * values.hitboxMult
                    t.Handle.Transparency = 0.5
                end
            end
        end
    end
    
    local hum = getHum(getChar(player))
    if hum then
        if state.speed then hum.WalkSpeed = values.speedVal end
        if state.infJump then hum.JumpPower = values.jumpVal end
    end
end))

UserInputService.JumpRequest:Connect(function()
    if state.infJump then
        local hum = getHum(getChar(player))
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

local flyVel, flyGyro
addConn(RunService.RenderStepped:Connect(function()
    local char = getChar(player)
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = getHum(char)
    
    if state.fly and root and hum then
        hum.PlatformStand = true
        if not flyVel then flyVel = Instance.new("BodyVelocity"); flyVel.MaxForce = Vector3.new(1e5,1e5,1e5); flyVel.Parent = root end
        if not flyGyro then flyGyro = Instance.new("BodyGyro"); flyGyro.MaxTorque = Vector3.new(1e5,1e5,1e5); flyGyro.P = 10000; flyGyro.Parent = root end
        
        flyGyro.CFrame = camera.CFrame
        local moveDir = Vector3.new(0,0,0)
        
        -- Nhận phím PC 
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
        
        -- Joystick Mobile An Toàn
        pcall(function()
            local control = require(player.PlayerScripts.PlayerModule):GetControls()
            local vec = control:GetMoveVector()
            if vec.Magnitude > 0 then moveDir = (camera.CFrame.RightVector * vec.X) - (camera.CFrame.LookVector * vec.Z) end
        end)

        flyVel.Velocity = moveDir.Magnitude == 0 and Vector3.new(0, 0.1, 0) or moveDir.Unit * values.flySpeed
    else
        if flyVel then flyVel:Destroy(); flyVel = nil end
        if flyGyro then flyGyro:Destroy(); flyGyro = nil end
        if hum then hum.PlatformStand = false end
    end
end))

addConn(RunService.Stepped:Connect(function()
    if state.noclip then
        local char = getChar(player)
        if char then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end end end
    end
end))

-- ====== DỌN DẸP SỰ KIỆN KHI CHẾT/THOÁT ======
player.CharacterAdded:Connect(function()
    if flyVel then flyVel:Destroy(); flyVel = nil end
    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
    for p, _ in pairs(espPool) do removeESP(p) end
end)
Players.PlayerRemoving:Connect(function(p) removeESP(p) end)

yslGui.Destroying:Connect(function()
    cleanupConnections()
    for p, _ in pairs(espPool) do removeESP(p) end
    if targetMarkerGui then targetMarkerGui:Destroy() end
    if snapGui then snapGui:Destroy() end
    if blurEffect then blurEffect:Destroy() end
    Lighting.Ambient = origAmbient; Lighting.OutdoorAmbient = origOutdoorAmbient; Lighting.FogEnd = origFogEnd
end)

print("🔥 YSL Bá Sàn v24 Luxury - AutoFire Fixed & Snaplines Star Active! 🔥")
