local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Rayfield UIライブラリの読み込み
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 横一列の配置設定
local rowConfig = {
    spacing = 1.2,
    heightOffset = 1,
    forwardOffset = 4,
    sidewaysOffset = 0,
    maxObjects = 20,
    waveSpeed = 2.5,
    baseAmplitude = 2,
    distanceMultiplier = 0.4,
    phaseOffset = 0.3,
    xRotation = -45,
    yRotation = 0,
    zRotation = 90,
    enabled = true,
    smoothness = 0.6,
    horizontalWaveAmount = 0.5,
    targetPlayer = nil,
    objectType = "FireworkSparkler",
    -- 羽モード設定
    wingMode = false,  -- 羽モードのオンオフ
    wingAngle = 45,  -- 羽の角度（上向きの角度）
    wingSpread = 3,  -- 羽の広がり具合
}

-- 対応するオブジェクトタイプのリスト
local objectTypes = {
    "FireworkSparkler",
    "GlassBoxGray",
    "SpookyCandle5",
    "PalletLightBrown",
}

local speed = 2
local uiVisible = true

-- オブジェクトを検索する関数（複数タイプ対応）
local function findObjects(objectName)
    local objects = {}
    
    for _, item in ipairs(workspace:GetDescendants()) do
        if item:IsA("Model") and item.Name == objectName then
            local alreadyAdded = false
            for _, existingObj in ipairs(objects) do
                if existingObj == item then
                    alreadyAdded = true
                    break
                end
            end
            if not alreadyAdded then
                table.insert(objects, item)
            end
        end
    end
    
    table.sort(objects, function(a, b)
        return a.Name < b.Name
    end)
    
    return objects
end

local Objects = findObjects(rowConfig.objectType)

local function CP()
    local Part = Instance.new("Part")
    Part.CanCollide = false
    Part.Anchored = true
    Part.Transparency = 1
    Part.Size = Vector3.new(4, 1, 4)
    Part.Parent = workspace
    return Part
end

local function CBM(Part)
    if not Part then return nil, nil end
    
    local existingBG = Part:FindFirstChildOfClass("BodyGyro")
    local existingBP = Part:FindFirstChildOfClass("BodyPosition")
    
    if existingBG and existingBP then 
        return existingBG, existingBP
    end
    
    if existingBG then existingBG:Destroy() end
    if existingBP then existingBP:Destroy() end
    
    local BP = Instance.new("BodyPosition")  
    local BG = Instance.new("BodyGyro")  
    
    BP.P = 25000
    BP.D = 800
    BP.MaxForce = Vector3.new(1, 1, 1) * 1e10  
    BP.Parent = Part  
    
    BG.P = 25000  
    BG.D = 800  
    BG.MaxTorque = Vector3.new(1, 1, 1) * 1e10  
    BG.Parent = Part  
    
    return BG, BP
end

local function getPrimaryPart(model)
    if model.PrimaryPart then
        return model.PrimaryPart
    end
    
    -- より多くのパーツ名に対応
    local potentialParts = {"Handle", "Main", "Part", "Base", "Sparkler", "Firework", "Box", "Glass", "Center", "Core", "Candle", "Flame", "Wick", "Pallet", "Wood"}
    for _, partName in ipairs(potentialParts) do
        local part = model:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            return part
        end
    end
    
    for _, child in ipairs(model:GetChildren()) do
        if child:IsA("BasePart") then
            return child
        end
    end
    
    return nil
end

local function createRowPoints(count)
    local points = {}
    
    if count == 0 then return points end
    
    local halfCount = math.floor(count / 2)
    local isOdd = count % 2 == 1
    
    local index = 1
    
    if isOdd then
        points[index] = {
            offsetX = 0,
            part = CP(),
            assignedObject = nil,
            index = index,
            baseOffsetX = 0,
        }
        index = index + 1
    end
    
    for i = 1, halfCount do
        local offset = i * rowConfig.spacing
        
        points[index] = {
            offsetX = offset,
            part = CP(),
            assignedObject = nil,
            index = index,
            baseOffsetX = offset,
        }
        index = index + 1
        
        points[index] = {
            offsetX = -offset,
            part = CP(),
            assignedObject = nil,
            index = index,
            baseOffsetX = -offset,
        }
        index = index + 1
    end
    
    return points
end

local rowPoints = createRowPoints(math.min(#Objects, rowConfig.maxObjects))

local function disableSystem()
    for _, point in ipairs(rowPoints) do
        if point.assignedObject and point.assignedObject.Pallet then
            if point.assignedObject.BP then
                point.assignedObject.BP:Destroy()
                point.assignedObject.BP = nil
            end
            if point.assignedObject.BG then
                point.assignedObject.BG:Destroy()
                point.assignedObject.BG = nil
            end
            
            for _, child in ipairs(point.assignedObject.Model:GetChildren()) do
                if child:IsA("BasePart") then
                    child.Anchored = true
                    child.Velocity = Vector3.new(0, 0, 0)
                    child.RotVelocity = Vector3.new(0, 0, 0)
                end
            end
        end
    end
end

local function enableSystem()
    for _, point in ipairs(rowPoints) do
        if point.assignedObject and point.assignedObject.Pallet then
            for _, child in ipairs(point.assignedObject.Model:GetChildren()) do
                if child:IsA("BasePart") then
                    child.Anchored = false
                end
            end
            
            local BG, BP = CBM(point.assignedObject.Pallet)
            point.assignedObject.BG = BG
            point.assignedObject.BP = BP
        end
    end
end

local function getTargetCharacter()
    if rowConfig.targetPlayer and rowConfig.targetPlayer.Character then
        return rowConfig.targetPlayer.Character
    elseif LocalPlayer.Character then
        return LocalPlayer.Character
    end
    return nil
end

local function assignObjectsToPoints()
    local assignedObjects = {}
    
    local character = getTargetCharacter()
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return assignedObjects
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    
    if not humanoidRootPart or not torso then
        return assignedObjects
    end
    
    local charCFrame = humanoidRootPart.CFrame
    local rightVector = charCFrame.RightVector
    local lookVector = charCFrame.LookVector
    
    local basePosition = torso.Position + 
                         Vector3.new(0, rowConfig.heightOffset, 0) + 
                         (lookVector * rowConfig.forwardOffset) +
                         (rightVector * rowConfig.sidewaysOffset)
    
    for i = 1, math.min(#Objects, #rowPoints) do
        local obj = Objects[i]
        if obj and obj:IsA("Model") then
            local primaryPart = getPrimaryPart(obj)
            
            if primaryPart then  
                for _, child in ipairs(obj:GetChildren()) do  
                    if child:IsA("BasePart") then  
                        child.CanCollide = false
                        child.CanTouch = false
                        child.Anchored = false
                    end  
                end
                
                local BG, BP = CBM(primaryPart)  
                
                local initialPosition = basePosition + (rightVector * rowPoints[i].offsetX)
                
                local objTable = {  
                    BG = BG,  
                    BP = BP,  
                    Pallet = primaryPart,
                    Model = obj,
                    RowIndex = i,
                    offsetX = rowPoints[i].offsetX,
                    baseOffsetX = rowPoints[i].baseOffsetX,
                    index = rowPoints[i].index,
                }  
                
                if BP then
                    BP.Position = initialPosition
                end
                
                if BG then
                    local baseCFrame = CFrame.new(initialPosition)
                    local _, playerYRot, _ = charCFrame:ToOrientation()
                    baseCFrame = baseCFrame * CFrame.Angles(0, playerYRot + math.rad(rowConfig.yRotation), 0)
                    baseCFrame = baseCFrame * CFrame.Angles(math.rad(rowConfig.xRotation), 0, 0)
                    baseCFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(rowConfig.zRotation))
                    
                    BG.CFrame = baseCFrame
                end
                
                rowPoints[i].assignedObject = objTable
                table.insert(assignedObjects, objTable)
            end  
        end
    end
    
    return assignedObjects
end

local assignedObjects = assignObjectsToPoints()

-- 新しいオブジェクトが追加された時の処理
workspace.DescendantAdded:Connect(function(descendant)
    if descendant:IsA("Model") and descendant.Name == rowConfig.objectType then
        task.wait(0.5)
        Objects = findObjects(rowConfig.objectType)
        rowPoints = createRowPoints(math.min(#Objects, rowConfig.maxObjects))
        assignedObjects = assignObjectsToPoints()
    end
end)

local Window = Rayfield:CreateWindow({
    Name = "Object Control",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by Script",
    ConfigurationSaving = {Enabled = false},
    Discord = {Enabled = false},
    KeySystem = false,
})

local MainTab = Window:CreateTab("Main", 4483362458)
local Section0 = MainTab:CreateSection("System")

local EnableToggle = MainTab:CreateToggle({
    Name = "Enable",
    CurrentValue = rowConfig.enabled,
    Flag = "EnableToggle",
    Callback = function(Value)
        rowConfig.enabled = Value
        if Value then
            enableSystem()
            Rayfield:Notify({Title = "Enabled", Content = "System ON", Duration = 2, Image = 4483362458})
        else
            disableSystem()
            Rayfield:Notify({Title = "Disabled", Content = "System OFF", Duration = 2, Image = 4483362458})
        end
    end,
})

local ObjectTypeDropdown = MainTab:CreateDropdown({
    Name = "Object Type",
    Options = objectTypes,
    CurrentOption = {rowConfig.objectType},
    MultipleOptions = false,
    Flag = "ObjectTypeDropdown",
    Callback = function(Option)
        rowConfig.objectType = Option[1]
        Objects = findObjects(rowConfig.objectType)
        rowPoints = createRowPoints(math.min(#Objects, rowConfig.maxObjects))
        assignedObjects = assignObjectsToPoints()
        Rayfield:Notify({Title = "Type Changed", Content = Option[1] .. " (" .. #Objects .. ")", Duration = 2, Image = 4483362458})
    end,
})

local function getPlayerList()
    local playerNames = {"Self"}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            table.insert(playerNames, player.Name)
        end
    end
    return playerNames
end

local PlayerDropdown = MainTab:CreateDropdown({
    Name = "Target Player",
    Options = getPlayerList(),
    CurrentOption = {"Self"},
    MultipleOptions = false,
    Flag = "PlayerDropdown",
    Callback = function(Option)
        if Option[1] == "Self" then
            rowConfig.targetPlayer = nil
            Rayfield:Notify({Title = "Target", Content = "Self", Duration = 2, Image = 4483362458})
        else
            local targetPlayer = Players:FindFirstChild(Option[1])
            if targetPlayer then
                rowConfig.targetPlayer = targetPlayer
                Rayfield:Notify({Title = "Target", Content = Option[1], Duration = 2, Image = 4483362458})
            end
        end
        assignedObjects = assignObjectsToPoints()
    end,
})

local RefreshPlayersButton = MainTab:CreateButton({
    Name = "Refresh Players",
    Callback = function()
        PlayerDropdown:Refresh(getPlayerList())
        Rayfield:Notify({Title = "Refreshed", Content = "Player list updated", Duration = 2, Image = 4483362458})
    end,
})

local Section1 = MainTab:CreateSection("Position")

local MaxObjectsSlider = MainTab:CreateSlider({
    Name = "Max Objects",
    Range = {2, 600},
    Increment = 2,
    CurrentValue = rowConfig.maxObjects,
    Flag = "MaxObjectsSlider",
    Callback = function(Value)
        rowConfig.maxObjects = Value
        rowPoints = createRowPoints(math.min(#Objects, rowConfig.maxObjects))
        assignedObjects = assignObjectsToPoints()
        Rayfield:Notify({Title = "Max Changed", Content = Value, Duration = 2, Image = 4483362458})
    end,
})

local SpacingSlider = MainTab:CreateSlider({
    Name = "Spacing",
    Range = {0.5, 5},
    Increment = 0.1,
    CurrentValue = rowConfig.spacing,
    Flag = "SpacingSlider",
    Callback = function(Value)
        rowConfig.spacing = Value
        rowPoints = createRowPoints(math.min(#Objects, rowConfig.maxObjects))
        assignedObjects = assignObjectsToPoints()
    end,
})

local HeightSlider = MainTab:CreateSlider({
    Name = "Height",
    Range = {-5, 10},
    Increment = 0.5,
    CurrentValue = rowConfig.heightOffset,
    Flag = "HeightSlider",
    Callback = function(Value) rowConfig.heightOffset = Value end,
})

local ForwardSlider = MainTab:CreateSlider({
    Name = "Forward",
    Range = {0, 15},
    Increment = 0.5,
    CurrentValue = rowConfig.forwardOffset,
    Flag = "ForwardSlider",
    Callback = function(Value) rowConfig.forwardOffset = Value end,
})

local SidewaysSlider = MainTab:CreateSlider({
    Name = "Sideways",
    Range = {-15, 15},
    Increment = 0.5,
    CurrentValue = rowConfig.sidewaysOffset,
    Flag = "SidewaysSlider",
    Callback = function(Value) rowConfig.sidewaysOffset = Value end,
})

local Section2 = MainTab:CreateSection("Wing Mode")

local WingModeToggle = MainTab:CreateToggle({
    Name = "Enable Wing Mode",
    CurrentValue = rowConfig.wingMode,
    Flag = "WingModeToggle",
    Callback = function(Value)
        rowConfig.wingMode = Value
        Rayfield:Notify({Title = "Wing Mode", Content = Value and "ON" or "OFF", Duration = 2, Image = 4483362458})
    end,
})

local WingAngleSlider = MainTab:CreateSlider({
    Name = "Wing Angle",
    Range = {0, 90},
    Increment = 5,
    CurrentValue = rowConfig.wingAngle,
    Flag = "WingAngleSlider",
    Callback = function(Value) rowConfig.wingAngle = Value end,
})

local Section3 = MainTab:CreateSection("Rotation")

local XRotationSlider = MainTab:CreateSlider({
    Name = "X Rotation",
    Range = {-180, 180},
    Increment = 5,
    CurrentValue = rowConfig.xRotation,
    Flag = "XRotationSlider",
    Callback = function(Value) rowConfig.xRotation = Value end,
})

local YRotationSlider = MainTab:CreateSlider({
    Name = "Y Rotation",
    Range = {-180, 180},
    Increment = 5,
    CurrentValue = rowConfig.yRotation,
    Flag = "YRotationSlider",
    Callback = function(Value) rowConfig.yRotation = Value end,
})

local ZRotationSlider = MainTab:CreateSlider({
    Name = "Z Rotation",
    Range = {-180, 180},
    Increment = 5,
    CurrentValue = rowConfig.zRotation,
    Flag = "ZRotationSlider",
    Callback = function(Value) rowConfig.zRotation = Value end,
})

local ResetRotationButton = MainTab:CreateButton({
    Name = "Reset Rotation",
    Callback = function()
        rowConfig.xRotation = -45
        rowConfig.yRotation = 0
        rowConfig.zRotation = 90
        XRotationSlider:Set(-45)
        YRotationSlider:Set(0)
        ZRotationSlider:Set(90)
        Rayfield:Notify({Title = "Reset", Content = "Default rotation", Duration = 2, Image = 4483362458})
    end,
})

local Section4 = MainTab:CreateSection("Wave Settings")

local WaveSpeedSlider = MainTab:CreateSlider({
    Name = "Speed",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = rowConfig.waveSpeed,
    Flag = "WaveSpeedSlider",
    Callback = function(Value) rowConfig.waveSpeed = Value end,
})

local BaseAmplitudeSlider = MainTab:CreateSlider({
    Name = "Amplitude",
    Range = {0, 10},
    Increment = 0.5,
    CurrentValue = rowConfig.baseAmplitude,
    Flag = "BaseAmplitudeSlider",
    Callback = function(Value) rowConfig.baseAmplitude = Value end,
})

local DistanceMultiplierSlider = MainTab:CreateSlider({
    Name = "Distance Mult",
    Range = {0, 2},
    Increment = 0.05,
    CurrentValue = rowConfig.distanceMultiplier,
    Flag = "DistanceMultiplierSlider",
    Callback = function(Value) rowConfig.distanceMultiplier = Value end,
})

local PhaseOffsetSlider = MainTab:CreateSlider({
    Name = "Phase Offset",
    Range = {0, 2},
    Increment = 0.1,
    CurrentValue = rowConfig.phaseOffset,
    Flag = "PhaseOffsetSlider",
    Callback = function(Value) rowConfig.phaseOffset = Value end,
})

local HorizontalWaveSlider = MainTab:CreateSlider({
    Name = "Horizontal Wave",
    Range = {0, 2},
    Increment = 0.1,
    CurrentValue = rowConfig.horizontalWaveAmount,
    Flag = "HorizontalWaveSlider",
    Callback = function(Value) rowConfig.horizontalWaveAmount = Value end,
})

local SmoothnessSlider = MainTab:CreateSlider({
    Name = "Smoothness",
    Range = {0.1, 1},
    Increment = 0.05,
    CurrentValue = rowConfig.smoothness,
    Flag = "SmoothnessSlider",
    Callback = function(Value) rowConfig.smoothness = Value end,
})

local Section5 = MainTab:CreateSection("Other")

local RefreshButton = MainTab:CreateButton({
    Name = "Refresh Objects",
    Callback = function()
        Objects = findObjects(rowConfig.objectType)
        rowPoints = createRowPoints(math.min(#Objects, rowConfig.maxObjects))
        assignedObjects = assignObjectsToPoints()
        Rayfield:Notify({Title = "Refreshed", Content = rowConfig.objectType .. ": " .. #Objects, Duration = 2, Image = 4483362458})
    end,
})

local time = 0

RunService.RenderStepped:Connect(function(dt)
    if not rowConfig.enabled then
        return
    end
    
    local character = getTargetCharacter()
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not torso or not humanoidRootPart then
        return
    end
    
    time += dt * rowConfig.waveSpeed
    
    local charCFrame = humanoidRootPart.CFrame
    local rightVector = charCFrame.RightVector
    local lookVector = charCFrame.LookVector
    
    local basePosition = torso.Position + 
                         Vector3.new(0, rowConfig.heightOffset, 0) + 
                         (lookVector * rowConfig.forwardOffset) +
                         (rightVector * rowConfig.sidewaysOffset)
    
    for i, point in ipairs(rowPoints) do
        if point.assignedObject and point.assignedObject.BP and point.assignedObject.BG then
            local obj = point.assignedObject
            
            local distanceFromCenter = math.abs(obj.baseOffsetX)
            local amplitude = rowConfig.baseAmplitude + (distanceFromCenter * rowConfig.distanceMultiplier)
            
            local phase = time + (obj.index * rowConfig.phaseOffset)
            local waveValue = math.sin(phase)
            local waveMovement = waveValue * amplitude
            
            local horizontalOffset = obj.baseOffsetX
            if obj.baseOffsetX ~= 0 then
                local horizontalShrink = waveValue * rowConfig.horizontalWaveAmount
                local sign = obj.baseOffsetX > 0 and 1 or -1
                horizontalOffset = obj.baseOffsetX - (sign * math.abs(obj.baseOffsetX) * horizontalShrink)
            end
            
            -- 羽モードの場合の追加オフセット
            local wingHeightOffset = 0
            local wingForwardOffset = 0
            if rowConfig.wingMode then
                local wingSign = obj.baseOffsetX > 0 and 1 or -1
                local wingDist = math.abs(obj.baseOffsetX)
                local angleRad = math.rad(rowConfig.wingAngle)
                wingHeightOffset = wingDist * rowConfig.wingSpread * math.sin(angleRad) * wingSign
                wingForwardOffset = wingDist * rowConfig.wingSpread * math.cos(angleRad)
            end
            
            local targetPosition = basePosition + (rightVector * horizontalOffset) + (lookVector * wingForwardOffset)
            local finalPosition = targetPosition + Vector3.new(0, waveMovement + wingHeightOffset, 0)
            
            if point.part then
                point.part.Position = finalPosition
            end
            
            obj.BP.Position = finalPosition
            
            local baseCFrame = CFrame.new(finalPosition)
            local _, playerYRot, _ = charCFrame:ToOrientation()
            baseCFrame = baseCFrame * CFrame.Angles(0, playerYRot + math.rad(rowConfig.yRotation), 0)
            baseCFrame = baseCFrame * CFrame.Angles(math.rad(rowConfig.xRotation), 0, 0)
            baseCFrame = baseCFrame * CFrame.Angles(0, 0, math.rad(rowConfig.zRotation))
            
            local currentCFrame = obj.BG.CFrame
            local interpolatedCFrame = currentCFrame:Lerp(baseCFrame, rowConfig.smoothness)
            
            obj.BG.CFrame = interpolatedCFrame
        end
    end
end)

Rayfield:Notify({
    Title = "System Started",
    Content = rowConfig.objectType .. " x " .. #Objects,
    Duration = 3,
    Image = 4483362458,
})

print("Multi-Object System Started")
print("Type: " .. rowConfig.objectType)
print("Found: " .. #Objects)
print("Assigned: " .. #assignedObjects)
