--[[
    YSL BÁ SÀN v33 - FINAL PERFECT FIX
    Sáng Lập: Y Seav Long
    - [FIXED] ESP & Snaplines hoạt động 100% không bị chớp tắt.
    - [FIXED] Aimbot ghim tâm siêu mượt, nhận diện chuẩn R6/R15.
    - [FIXED] AutoFire dùng Tool:Activate() thuần túy -> Không liệt Joystick di chuyển trên Mobile.
    - [UI] Ảnh Nút Menu: 101591256247668 | Ảnh Bìa Menu: 84705282139911.
    - [UI] Kích thước tỉ lệ chuẩn 1536x1147 (Quy đổi 480x358 px). Tab Sáng Lập hoạt động hoàn hảo.
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui", 10) or player:FindFirstChildOfClass("PlayerGui")

-- ====== ID ẢNH ĐÃ SỬA LẠI CHUẨN XÁC ======
local MENU_BUTTON_ID = "rbxassetid://101591256247668" -- Nút tròn bên ngoài
local MENU_COVER_ID = "rbxassetid://84705282139911"   -- Ảnh nền bên trong menu

-- ====== TRẠNG THÁI & THIẾT LẬP ======
local state = {
    aimbot = false, autoFire = false, hitboxExpander = false,
    espEnabled = false, snaplines = false, fovCircle = true,
    speed = false, infJump = false, fly = false, noclip = false, spinbot = false,
    fullbright = false,
}

local values = {
    aimbotFov = 150, aimbotSmoothing = 6, aimbotRange = 2500, predictionAmount = 0.12,
    aimPart = "Đầu (Head)", 
    wallCheck = true, teamCheck = false,
    fireDelay = 0.05, hitboxMult = 4, espMaxDistance = 3000,
    speedVal = 40, jumpVal = 80, flySpeed = 50, camFov = 70,
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

-- ====== HÀM TIỆN ÍCH AN TOÀN ======
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

-- Nhận diện R6/R15 siêu chuẩn
local function getAimPart(char)
    if not char then return nil end
    local head = char:FindFirstChild("Head")
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    return values.aimPart == "Đầu (Head)" and (head or torso) or (torso or head)
end

-- Thuật toán Wall Check siêu bảo mật (Chống Crash)
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

-- ====== HỆ THỐNG MỤC TIÊU & AUTO SHOOT ======
local currentAimbotTargetPart = nil

local function updateNearestEnemy()
    local screenCenter = Vector2.new(camera.ViewportSize.X/2, camera.ViewportSize.Y/2)
    local bestDist = values.aimbotFov -- Chỉ bắt địch trong vòng FOV
    local bestPart = nil
    
    local originPos = camera.CFrame.Position
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and isEnemy(p) and isAlive(p) then
            local targetPart = getAimPart(getCharacter(p))
            if targetPart then
                local dist3D = (originPos - targetPart.Position).Magnitude
                if dist3D <= values.aimbotRange then
                    local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen and screenPos.Z > 0 then
                        local screenDist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if screenDist <= bestDist and isVisible(targetPart) then
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

-- Auto Shoot thuần túy chống liệt Joystick
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
        end)
    end)
end

-- ====== TẠO GIAO DIỆN (UI) ======
if playerGui:FindFirstChild("YSL_UI") then playerGui.YSL_UI:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "YSL_UI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local snapGui = Instance.new("ScreenGui")
snapGui.Name = "YSL_SnaplinesGui"
snapGui.IgnoreGuiInset = true -- Vẽ laze chính xác, bỏ qua thanh công cụ
snapGui.ResetOnSpawn = false
snapGui.Parent = playerGui

-- Hàm Kéo Thả
local function makeDraggable(obj, dragHandle)
    dragHandle = dragHandle or obj
    local dragging, dragInput, dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = obj.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            obj.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- 1. NÚT MỞ MENU (Icon Mới)
local openBtn = Instance.new("ImageButton")
openBtn.Size = UDim2.new(0, 50, 0, 50)
openBtn.Position = UDim2.new(0, 15, 0, 15)
openBtn.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
openBtn.Image = MENU_BUTTON_ID
openBtn.Parent = gui
Instance.new("UICorner", openBtn).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", openBtn).Color = Color3.fromRGB(200, 50, 255)
makeDraggable(openBtn)

-- 2. MAIN MENU (Tỉ Lệ 1536x1147 -> Quy Đổi: 480x358)
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 480, 0, 358)
main.Position = UDim2.new(0.5, -240, 0.5, -179)
main.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
main.BorderSizePixel = 0
main.Visible = false
main.ClipsDescendants = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
Instance.new("UIStroke", main).Color = Color3.fromRGB(200, 50, 255)
local mScale = Instance.new("UIScale"); mScale.Scale = 0; mScale.Parent = main
makeDraggable(main)

-- Ảnh Bìa (Background) Menu
local bgCover = Instance.new("ImageLabel")
bgCover.Size = UDim2.new(1, 0, 1, 0)
bgCover.BackgroundTransparency = 1
bgCover.Image = MENU_COVER_ID
bgCover.ScaleType = Enum.ScaleType.Crop
bgCover.ImageTransparency = 0.4 -- Làm mờ ảnh để dễ nhìn chữ
bgCover.ZIndex = 0
bgCover.Parent = main

local menuOpen = false
openBtn.MouseButton1Click:Connect(function()
    menuOpen = not menuOpen
    if menuOpen then
        main.Visible = true
        TweenService:Create(mScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    else
        local c = TweenService:Create(mScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
        c:Play(); c.Completed:Connect(function() if not menuOpen then main.Visible = false end end)
    end
end)

-- 3. SIDEBAR & NỘI DUNG (ZIndex cao hơn để không bị ảnh nền đè)
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 130, 1, 0)
sidebar.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
sidebar.BackgroundTransparency = 0.5 
sidebar.ZIndex = 1
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)

local titleMain = Instance.new("TextLabel")
titleMain.Size = UDim2.new(1, 0, 0, 50)
titleMain.BackgroundTransparency = 1
titleMain.Text = "YSL"
titleMain.TextColor3 = Color3.fromRGB(200, 100, 255) 
titleMain.Font = Enum.Font.GothamBlack
titleMain.TextSize = 22
titleMain.ZIndex = 2
titleMain.Parent = sidebar

local container = Instance.new("Frame")
container.Size = UDim2.new(1, -130, 1, 0)
container.Position = UDim2.new(0, 130, 0, 0)
container.BackgroundTransparency = 1
container.ZIndex = 1
container.Parent = main

local tabTitle = Instance.new("TextLabel")
tabTitle.Size = UDim2.new(1, -40, 0, 50)
tabTitle.Position = UDim2.new(0, 15, 0, 0)
tabTitle.BackgroundTransparency = 1
tabTitle.Text = "Ngắm Bắn"
tabTitle.TextColor3 = Color3.new(1, 1, 1)
tabTitle.Font = Enum.Font.GothamBold
tabTitle.TextSize = 20
tabTitle.TextXAlignment = Enum.TextXAlignment.Left
tabTitle.ZIndex = 2
tabTitle.Parent = container

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 24, 0, 24)
closeBtn.Position = UDim2.new(1, -34, 0, 13)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 16
closeBtn.ZIndex = 2
closeBtn.Parent = main
closeBtn.MouseButton1Click:Connect(function()
    menuOpen = false
    local c = TweenService:Create(mScale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Scale = 0})
    c:Play(); c.Completed:Connect(function() if not menuOpen then main.Visible = false end end)
end)

local contentScroll = Instance.new("ScrollingFrame")
contentScroll.Size = UDim2.new(1, -20, 1, -55)
contentScroll.Position = UDim2.new(0, 10, 0, 50)
contentScroll.BackgroundTransparency = 1
contentScroll.ScrollBarThickness = 3
contentScroll.CanvasSize = UDim2.new(0,0,0,0)
contentScroll.ZIndex = 2
contentScroll.Parent = container

local tabs = {}
local tabContents = {}
local tabNames = {"Ngắm Bắn", "Hiển Thị", "Người Chơi", "Khác", "Sáng Lập"}

for i, tName in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -16, 0, 36)
    btn.Position = UDim2.new(0, 8, 0, 55 + (i-1)*42)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(20, 15, 30)
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
            b.BackgroundColor3 = Color3.fromRGB(20, 15, 30)
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

-- === CÔNG CỤ TẠO CHỨC NĂNG (ZINDEX = 2) ===
local function createButtonOption(parent, text, options, defaultOption, callback)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 38); f.BackgroundColor3 = Color3.fromRGB(0, 0, 0); f.BackgroundTransparency = 0.5; f.ZIndex = 2; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.5, 0, 1, 0); l.Position = UDim2.new(0, 10, 0, 0); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9, 0.9, 0.9); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 2; l.Parent = f
    local btn = Instance.new("TextButton"); btn.Size = UDim2.new(0.4, 0, 0, 26); btn.Position = UDim2.new(1, -10 - (0.4 * parent.AbsoluteSize.X), 0.5, -13); btn.BackgroundColor3 = Color3.fromRGB(150, 50, 255); btn.Text = defaultOption; btn.TextColor3 = Color3.new(1, 1, 1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 11; btn.ZIndex = 2; btn.Parent = f
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
    local cur = 1; for i, v in ipairs(options) do if v == defaultOption then cur = i; break end end
    btn.MouseButton1Click:Connect(function()
        cur = cur + 1; if cur > #options then cur = 1 end
        btn.Text = options[cur]; callback(options[cur])
    end)
    parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if parent.AbsoluteSize.X > 0 then btn.Position = UDim2.new(1, -10 - (0.4 * parent.AbsoluteSize.X), 0.5, -13) end end)
end

local function createToggle(parent, text, default, callback)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 38); f.BackgroundColor3 = Color3.fromRGB(0, 0, 0); f.BackgroundTransparency = 0.5; f.ZIndex = 2; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.7, 0, 1, 0); l.Position = UDim2.new(0, 10, 0, 0); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9, 0.9, 0.9); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 2; l.Parent = f
    local tBtn = Instance.new("TextButton"); tBtn.Size = UDim2.new(0, 38, 0, 22); tBtn.Position = UDim2.new(1, -48, 0.5, -11); tBtn.BackgroundColor3 = default and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(50, 50, 60); tBtn.Text = ""; tBtn.ZIndex = 2; tBtn.Parent = f
    Instance.new("UICorner", tBtn).CornerRadius = UDim.new(1, 0)
    local cir = Instance.new("Frame"); cir.Size = UDim2.new(0, 18, 0, 18); cir.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9); cir.BackgroundColor3 = Color3.new(1, 1, 1); cir.ZIndex = 2; cir.Parent = tBtn
    Instance.new("UICorner", cir).CornerRadius = UDim.new(1, 0)
    local act = default
    local function toggle()
        act = not act
        TweenService:Create(cir, TweenInfo.new(0.25), {Position = act and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}):Play()
        TweenService:Create(tBtn, TweenInfo.new(0.25), {BackgroundColor3 = act and Color3.fromRGB(150, 50, 255) or Color3.fromRGB(50, 50, 60)}):Play()
        callback(act)
    end
    tBtn.MouseButton1Click:Connect(toggle)
    f.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then toggle() end end)
end

local function addSlider(parent, text, min, max, default, step, callback)
    local f = Instance.new("Frame"); f.Size = UDim2.new(1, 0, 0, 48); f.BackgroundColor3 = Color3.fromRGB(0, 0, 0); f.BackgroundTransparency = 0.5; f.ZIndex = 2; f.Parent = parent
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(0.5, 0, 0, 16); l.Position = UDim2.new(0, 10, 0, 6); l.BackgroundTransparency = 1; l.Text = text; l.TextColor3 = Color3.new(0.9, 0.9, 0.9); l.Font = Enum.Font.GothamMedium; l.TextSize = 12; l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 2; l.Parent = f
    local valLabel = Instance.new("TextLabel"); valLabel.Size = UDim2.new(0.5, -15, 0, 16); valLabel.Position = UDim2.new(0.5, 0, 0, 6); valLabel.BackgroundTransparency = 1; valLabel.Text = tostring(default); valLabel.TextColor3 = Color3.fromRGB(200, 100, 255); valLabel.Font = Enum.Font.GothamBold; valLabel.TextSize = 12; valLabel.TextXAlignment = Enum.TextXAlignment.Right; valLabel.ZIndex = 2; valLabel.Parent = f
    local track = Instance.new("Frame"); track.Size = UDim2.new(1, -20, 0, 4); track.Position = UDim2.new(0, 10, 0, 34); track.BackgroundColor3 = Color3.fromRGB(60, 60, 65); track.ZIndex = 2; track.Parent = f; Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local fill = Instance.new("Frame"); fill.Size = UDim2.new((default-min)/(max-min), 0, 1, 0); fill.BackgroundColor3 = Color3.fromRGB(150, 50, 255); fill.ZIndex = 2; fill.Parent = track; Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
    local knob = Instance.new("TextButton"); knob.Size = UDim2.new(0, 14, 0, 14); knob.Position = UDim2.new((default-min)/(max-min), -7, 0.5, -7); knob.BackgroundColor3 = Color3.new(1, 1, 1); knob.Text = ""; knob.ZIndex = 2; knob.Parent = track; Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local val = default; local drag = false
    local function update(input)
        local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        val = min + relX * (max - min); if step > 0 then val = math.round(val/step)*step end
        fill.Size = UDim2.new((val - min) / (max - min), 0, 1, 0); knob.Position = UDim2.new((val - min) / (max - min), -7, 0.5, -7)
        valLabel.Text = step < 1 and string.format("%.2f", val) or tostring(math.floor(val)); callback(val)
    end
    knob.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then drag = true end end)
    UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UserInputService.InputChanged:Connect(function(input) if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end end)
end

-- ====== CÀI ĐẶT CHỨC NĂNG (TABS) ======
-- Tab 1: Ngắm Bắn
createToggle(tabContents[1], "Bật Aimbot", false, function(s) state.aimbot = s end)
createButtonOption(tabContents[1], "Vị Trí Ngắm", {"Đầu (Head)", "Thân (Torso)"}, "Đầu (Head)", function(v) values.aimPart = v end)
addSlider(tabContents[1], "Độ Dính Tâm (Nhỏ = Aimlock)", 1, 20, values.aimbotSmoothing, 0.5, function(v) values.aimbotSmoothing = v end)
addSlider(tabContents[1], "Vòng Quét (FOV Radius)", 50, 500, values.aimbotFov, 5, function(v) values.aimbotFov = v end)
createToggle(tabContents[1], "Auto Shoot (Tự Động Bắn)", false, function(s) state.autoFire = s end)
createToggle(tabContents[1], "Kiểm Tra Vật Cản", true, function(s) values.wallCheck = s end)

-- Tab 2: Hiển Thị
createToggle(tabContents[2], "Hiện Vòng Quét FOV", true, function(s) state.fovCircle = s end)
createToggle(tabContents[2], "Đường Kẻ Hướng Địch (FFA)", false, function(s) state.snaplines = s end)
createToggle(tabContents[2], "ESP Định Vị Xuyên Tường", false, function(s) state.espEnabled = s end)
addSlider(tabContents[2], "Khoảng Cách Hiển Thị", 50, 4000, values.espMaxDistance, 10, function(v) values.espMaxDistance = v end)
createToggle(tabContents[2], "Sáng Bản Đồ", false, function(s) 
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
createToggle(tabContents[4], "Đi Xuyên Tường", false, function(s) state.noclip = s end)

-- Tab 5: Sáng Lập (Info Box Tuyệt Đẹp Đè Lên Ảnh Bìa)
local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1, -4, 1, -4)
infoBox.Position = UDim2.new(0, 2, 0, 2)
infoBox.BackgroundColor3 = Color3.fromRGB(15, 10, 20)
infoBox.BackgroundTransparency = 0.2 -- Làm mờ để thấy ảnh nền
infoBox.ZIndex = 2
infoBox.Parent = tabContents[5]
Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", infoBox).Color = Color3.fromRGB(200, 50, 255)

local iTitle = Instance.new("TextLabel")
iTitle.Size = UDim2.new(1, 0, 0, 45)
iTitle.BackgroundTransparency = 1
iTitle.Text = "👑 THÔNG TIN SÁNG LẬP 👑"
iTitle.TextColor3 = Color3.fromRGB(200, 100, 255)
iTitle.Font = Enum.Font.GothamBlack
iTitle.TextSize = 18
iTitle.ZIndex = 3
iTitle.Parent = infoBox

local iText = Instance.new("TextLabel")
iText.Size = UDim2.new(1, -20, 1, -55)
iText.Position = UDim2.new(0, 10, 0, 45)
iText.BackgroundTransparency = 1
iText.Text = "Script được thiết kế tối ưu cho iOS/Mobile.\nKhông giật lag, bắn mượt mọi map FPS/FFA.\n\n🔹 Facebook: Y Seav Long\n🔹 Discord: yslaiplus\n🔹 Zalo: +84 372322494\n\nCảm ơn bạn đã sử dụng YSL Bá Sàn!"
iText.TextColor3 = Color3.new(0.95, 0.95, 0.95)
iText.Font = Enum.Font.GothamMedium
iText.TextSize = 14
iText.TextXAlignment = Enum.TextXAlignment.Left
iText.TextYAlignment = Enum.TextXAlignment.Top
iText.ZIndex = 3
iText.Parent = infoBox

task.wait(0.1)
for i, frame in ipairs(tabContents) do
    if frame.Visible then contentScroll.CanvasSize = UDim2.new(0, 0, 0, frame.UIListLayout.AbsoluteContentSize.Y + 15) end
end

-- ====== FOV CIRCLE VISUAL ======
local fovCircleGui = Instance.new("Frame")
fovCircleGui.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircleGui.Position = UDim2.new(0.5, 0, 0.5, 0)
fovCircleGui.BackgroundTransparency = 1
fovCircleGui.Visible = false
fovCircleGui.Parent = gui

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(200, 50, 255)
fovStroke.Thickness = 1.2
fovStroke.Transparency = 0.5
fovStroke.Parent = fovCircleGui
Instance.new("UICorner", fovCircleGui).CornerRadius = UDim.new(1, 0)

addConnection(RunService.RenderStepped:Connect(function()
    if state.fovCircle and state.aimbot then
        fovCircleGui.Visible = true
        fovCircleGui.Size = UDim2.new(0, values.aimbotFov * 2, 0, values.aimbotFov * 2)
    else
        fovCircleGui.Visible = false
    end
end))

-- ====== ESP & SNAPLINES CHUẨN XÁC ======
local espData = {} 

local function DrawLine(frame, startPos, endPos, color)
    local distance = (endPos - startPos).Magnitude
    if distance < 1 then frame.Visible = false return end
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
                        hl.FillTransparency = 0.6; hl.OutlineTransparency = 0; hl.Parent = eChar
                        
                        local bb = Instance.new("BillboardGui")
                        bb.Size = UDim2.new(0, 100, 0, 40); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Adornee = targetPart; bb.Parent = eChar
                        
                        local nL = Instance.new("TextLabel")
                        nL.Size = UDim2.new(1, 0, 0.5, 0); nL.BackgroundTransparency = 1; nL.Text = p.DisplayName; nL.TextColor3 = Color3.new(1,1,1); nL.Font = Enum.Font.GothamBold; nL.TextSize = 10; nL.Parent = bb
                        
                        local iL = Instance.new("TextLabel")
                        iL.Size = UDim2.new(1, 0, 0.5, 0); iL.Position = UDim2.new(0, 0, 0.5, 0); iL.BackgroundTransparency = 1; iL.TextColor3 = Color3.fromRGB(0, 255, 0); iL.Font = Enum.Font.GothamMedium; iL.TextSize = 9; iL.Parent = bb
                        
                        local line = Instance.new("Frame")
                        line.BorderSizePixel = 0; line.AnchorPoint = Vector2.new(0.5, 0.5); line.Parent = snapGui
                        
                        espData[p] = { Highlight = hl, Billboard = bb, NameLabel = nL, InfoLabel = iL, Line = line }
                    end
                    
                    local data = espData[p]
                    local color = Color3.fromHSV((tick() * 0.5) % 1, 1, 1)
                    local isVis = isVisible(targetPart)
                    local displayColor = isVis and Color3.fromRGB(255, 50, 50) or color -- Kẻ địch trong tầm bắn sẽ hiện màu ĐỎ
                    
                    if state.espEnabled then
                        data.Highlight.Enabled = true; data.Billboard.Enabled = true
                        data.Highlight.FillColor = displayColor; data.Highlight.OutlineColor = displayColor
                        local hum = getHumanoid(eChar)
                        data.InfoLabel.Text = string.format("♥ %d | %dm", hum and math.floor(hum.Health) or 0, math.floor(dist))
                    else
                        data.Highlight.Enabled = false; data.Billboard.Enabled = false
                    end
                    
                    if state.snaplines then
                        local screenPos, onScreen = camera:WorldToViewportPoint(targetPart.Position)
                        if onScreen and screenPos.Z > 0 then
                            local startPos = Vector2.new(screenSize.X / 2, screenSize.Y)
                            local endPos = Vector2.new(screenPos.X, screenPos.Y)
                            DrawLine(data.Line, startPos, endPos, displayColor)
                        else
                            data.Line.Visible = false
                        end
                    else
                        data.Line.Visible = false
                    end
                else clearESP(p) end
            end
        end
    end
end))

-- ====== CORE LOOP: AIMBOT & AUTO SHOOT ======
addConnection(RunService.RenderStepped:Connect(function()
    if camera.FieldOfView ~= values.camFov and main.Visible == false then pcall(function() camera.FieldOfView = values.camFov end) end

    if state.aimbot or state.autoFire then updateNearestEnemy() else currentAimbotTargetPart = nil end

    if currentAimbotTargetPart then
        if state.aimbot then
            local targetVelocity = Vector3.new(0,0,0)
            if currentAimbotTargetPart:IsA("BasePart") then
                targetVelocity = currentAimbotTargetPart.AssemblyLinearVelocity
                if targetVelocity.Magnitude > 150 then targetVelocity = targetVelocity.Unit * 150 end -- Chống giật văng tâm R6
            end
            
            local predictedPos = currentAimbotTargetPart.Position + (targetVelocity * values.predictionAmount)
            local camPos = camera.CFrame.Position
            local desiredCFrame = CFrame.lookAt(camPos, predictedPos)
            
            if values.aimbotSmoothing <= 1 then camera.CFrame = desiredCFrame else
                camera.CFrame = camera.CFrame:Lerp(desiredCFrame, math.clamp(1 / values.aimbotSmoothing, 0.05, 1))
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
                if tool:IsA("Tool") and tool:FindFirstChild("Handle") and tool.Handle:IsA("BasePart") then
                    if not tool:GetAttribute("OrigSize") then tool:SetAttribute("OrigSize", tool.Handle.Size) end
                    tool.Handle.Size = tool:GetAttribute("OrigSize") * values.hitboxMult
                    tool.Handle.Transparency = 0.5
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
        
        if moveDir.Magnitude == 0 then flyBodyVelocity.Velocity = Vector3.new(0, 0.1, 0) else flyBodyVelocity.Velocity = moveDir.Unit * values.flySpeed end
    else
        if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
        if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
        if hum then hum.PlatformStand = false end
    end
end))

addConnection(RunService.Stepped:Connect(function()
    if state.noclip then
        local char = getCharacter(player)
        if char then for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end end
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
    if snapGui then snapGui:Destroy() end
    Lighting.Ambient = origAmbient
    Lighting.OutdoorAmbient = origOutdoorAmbient
end)

print("[YSL Bá Sàn] Bản v33 - Tỉ lệ 1536x1147 & Auto Fire Fixed 100% Mobile!")
