--[[
    Main Cheat File: HONX Hub
    Description: Core cheat logic for HONX Hub
    Version: 2.0.0
--]]

-- ============================================
-- GAME DETECTION
-- ============================================
local DA_HOOD_PLACE_ID = 2788229376
local PLATFORMER_TESTING_PLACE_ID = 129596000683069
local YUU_HOOD_PLACE_ID = 98247054732585

local function isDaHoodGame()
    return game.PlaceId == DA_HOOD_PLACE_ID
end

local function isPlatformerTestingGame()
    return game.PlaceId == PLATFORMER_TESTING_PLACE_ID
end

local function isYuuHoodGame()
    return game.PlaceId == YUU_HOOD_PLACE_ID
end

local function isSupportedGame()
    return isDaHoodGame() or isPlatformerTestingGame() or isYuuHoodGame()
end

local Players = game:GetService('Players')
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local localPlayer = Players.LocalPlayer
local LocalPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse = nil

local function updateHitbox(player)
    if getgenv().Enabled and player ~= LocalPlayer and player.Character then
        local targetPart = player.Character:FindFirstChild(getgenv().TargetPart)
        if targetPart and targetPart:IsA('BasePart') then
            targetPart.Size = getgenv().HitboxSize
            targetPart.CanCollide = false
            targetPart.Transparency = 1
        end
    end
end

local function applyToAllPlayers()
    for _, player in ipairs(Players:GetPlayers()) do
        updateHitbox(player)
    end
end

local function isStaffOrAdmin(player)
    if not player then
        return false
    end

    local name = tostring(player.Name or ''):lower()
    local displayName = tostring(player.DisplayName or ''):lower()
    local keywords = {
        'admin',
        'owner',
        'staff',
        'mod',
        'moderator',
        'administrator',
        'creator',
        'developer',
    }

    for _, keyword in ipairs(keywords) do
        if name:find(keyword, 1, true) or displayName:find(keyword, 1, true) then
            return true
        end
    end

    return false
end

local function kickLocalPlayer(reason)
    if localPlayer and localPlayer.Kick then
        pcall(function()
            localPlayer:Kick(reason)
        end)
    end
end

local function checkExistingPlayersForStaff()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isStaffOrAdmin(player) then
            kickLocalPlayer('Staff or admin joined the server.')
            return
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    if isStaffOrAdmin(player) then
        kickLocalPlayer('Staff or admin joined the server.')
    end

    player.CharacterAdded:Connect(function()
        updateHitbox(player)
    end)
end)

for _, player in ipairs(Players:GetPlayers()) do
    if isStaffOrAdmin(player) then
        kickLocalPlayer('Staff or admin joined the server.')
        break
    end
    player.CharacterAdded:Connect(function()
        updateHitbox(player)
    end)
    updateHitbox(player)
end

checkExistingPlayersForStaff()

local aimEnabled = false
local selectedAimbotTarget = nil
local silentEnabled = false
local triggerEnabled = false
local rapidFireEnabled = false
local flyEnabled = false
local flyBodyVelocity = nil
local mouseDown = false
local silentAimCache = { tick = 0, hit = nil, target = nil }
local lastHeavyUpdate = 0
local heavyUpdateInterval = 0
local walkSpeedEnabled = shared.honx['Local Player']['Speed']['Enabled'] or false
local jumpPowerEnabled = shared.honx['Local Player']['Jump']['Enabled'] or false
local healthDisplayEnabled = shared.honx['Health Display']['Enabled'] or true

local function initializePlayer()
    if not localPlayer then
        localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
    end
    if localPlayer then
        mouse = localPlayer:GetMouse()
    end
end

local function initializeCamera()
    camera = workspace.CurrentCamera or workspace:GetPropertyChangedSignal('CurrentCamera'):Wait()
end

initializePlayer()
initializeCamera()

workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
    camera = workspace.CurrentCamera
end)

Players.PlayerAdded:Connect(function(player)
    if not localPlayer and player then
        localPlayer = player
        mouse = player:GetMouse()
    end
end)

local function getRootPart(character)
    if not character then return nil end
    return character:FindFirstChild('HumanoidRootPart')
        or character:FindFirstChild('UpperTorso')
        or character:FindFirstChild('LowerTorso')
        or character:FindFirstChild('Head')
end

local function isValidTarget(player)
    if not player or player == localPlayer then
        return false
    end
    local character = player.Character
    if not character then
        return false
    end
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    return humanoid and humanoid.Health > 0
end

local function getTargetPart(character, hitPartName)
    if not character then return nil end
    local part = character:FindFirstChild(hitPartName)
    if part then
        return part
    end
    return getRootPart(character) or character:FindFirstChild('Head')
end

local function getAimbotTorsoPart(character)
    if not character then return nil end
    return character:FindFirstChild('HumanoidRootPart')
        or character:FindFirstChild('UpperTorso')
        or character:FindFirstChild('LowerTorso')
        or character:FindFirstChild('Torso')
end

local function getTargetFromMouse()
    if mouse and mouse.Target and mouse.Target:IsDescendantOf(workspace) then
        return mouse.Target
    end

    if not camera then
        return nil
    end

    local viewportSize = camera.ViewportSize
    local ray = camera:ViewportPointToRay(viewportSize.X / 2, viewportSize.Y / 2)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {localPlayer and localPlayer.Character}
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, raycastParams)
    return result and result.Instance
end

local function getPlayerFromCharacter(character)
    if not character then
        return nil
    end
    return Players:GetPlayerFromCharacter(character)
end

local function getDistanceFromCenter(position)
    local viewportSize = camera.ViewportSize
    local screenPoint, onScreen = camera:WorldToViewportPoint(position)
    if not onScreen then
        return math.huge
    end
    return (Vector2.new(screenPoint.X, screenPoint.Y) - viewportSize / 2).Magnitude
end

local function getClosestTarget(config)
    local bestTarget = nil
    local bestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if isValidTarget(player) then
            local character = player.Character
            local rootPart = getTargetPart(character, config['Hit Part'])
            if rootPart then
                local screenDistance = getDistanceFromCenter(rootPart.Position)
                local fovValue = config.FOV
                local validByFOV = screenDistance <= (fovValue or math.huge)

                local maxDistance = config.Distance or math.huge
                local worldDistance = (camera.CFrame.Position - rootPart.Position).Magnitude
                local validByDistance = worldDistance <= maxDistance

                if validByFOV and validByDistance and screenDistance < bestDistance then
                    bestDistance = screenDistance
                    bestTarget = character
                end
            end
        end
    end

    return bestTarget
end

local function getPredictedPosition(part, prediction)
    if not part then return nil end
    local velocity = part.Velocity or Vector3.new()
    prediction = prediction or {}
    return part.Position + Vector3.new(
        velocity.X * (prediction.X or 0),
        velocity.Y * (prediction.Y or 0),
        velocity.Z * (prediction.Z or 0)
    )
end

local function getEquippedTool()
    if not localPlayer then
        return nil
    end
    local character = localPlayer.Character
    if not character then
        return nil
    end
    for _, child in ipairs(character:GetChildren()) do
        if child:IsA('Tool') then
            return child
        end
    end
    return nil
end

local function isWeaponEquipped()
    return getEquippedTool() ~= nil
end

local function autoFire()
    if not mouseDown then
        return
    end
    local tool = getEquippedTool()
    if not tool then
        return
    end
    pcall(function()
        tool:Activate()
    end)
end

local function aimAt(part)
    if not part then
        return
    end
    local targetPosition = getPredictedPosition(part, shared.honx['Aim Assist']['Prediction'])
    if not targetPosition then
        return
    end
    local currentCFrame = camera.CFrame
    local goalCFrame = CFrame.lookAt(currentCFrame.Position, targetPosition)
    local smoothness = shared.honx['Aim Assist']['Smoothness']
    if type(smoothness) == 'number' and smoothness > 0 and smoothness < 1 then
        camera.CFrame = currentCFrame:Lerp(goalCFrame, smoothness)
    else
        camera.CFrame = goalCFrame
    end
end

local function getSilentAimValues()
    local currentTick = math.floor(tick() * 60)
    if silentAimCache.tick == currentTick and silentAimCache.hit and silentAimCache.target then
        return silentAimCache.hit, silentAimCache.target
    end

    local targetCharacter = getClosestTarget(shared.honx['Silent Aim'])
    if not targetCharacter then
        silentAimCache.tick = currentTick
        silentAimCache.hit = nil
        silentAimCache.target = nil
        return nil, nil
    end

    local targetPart = getTargetPart(targetCharacter, shared.honx['Silent Aim']['Hit Part'])
    if not targetPart then
        silentAimCache.tick = currentTick
        silentAimCache.hit = nil
        silentAimCache.target = nil
        return nil, nil
    end

    local predictedPosition = getPredictedPosition(targetPart, shared.honx['Silent Aim']['Prediction'])
    if not predictedPosition then
        silentAimCache.tick = currentTick
        silentAimCache.hit = nil
        silentAimCache.target = nil
        return nil, nil
    end

    local hitCFrame = CFrame.new(predictedPosition)
    silentAimCache.tick = currentTick
    silentAimCache.hit = hitCFrame
    silentAimCache.target = targetPart
    return hitCFrame, targetPart
end

local function hookMouse()
    if type(getrawmetatable) ~= 'function' or type(setreadonly) ~= 'function' then
        return
    end
    if not mouse then
        return
    end

    local success, mt = pcall(getrawmetatable, mouse)
    if not success or not mt then
        return
    end

    local oldIndex = mt.__index
    setreadonly(mt, false)
    mt.__index = newcclosure(function(self, key)
        if self == mouse and shared.honx['Silent Aim']['Enabled'] and silentEnabled then
            if key == 'Hit' then
                local hitCFrame = getSilentAimValues()
                if hitCFrame then
                    return hitCFrame
                end
            elseif key == 'Target' then
                local _, targetPart = getSilentAimValues()
                if targetPart then
                    return targetPart
                end
            end
        end
        return oldIndex(self, key)
    end)
    setreadonly(mt, true)
end

local function patchAmmoObject(obj, ammoValue)
    if not obj then
        return
    end

    local name = obj.Name and obj.Name:lower()
    if obj:IsA('NumberValue') or obj:IsA('IntValue') then
        if name and (name:find('ammo') or name:find('currentammo') or name:find('ammocount') or name:find('mag') or name:find('clip') or name:find('rounds') or name:find('bullets') or name:find('remaining') or name:find('magazine')) then
            obj.Value = ammoValue
        elseif name and (name:find('firerate') or name:find('fire_rate') or name:find('rate') or name:find('reload') or name:find('cooldown') or name:find('delay') or name:find('rpm')) then
            obj.Value = 0
        end
    elseif obj:IsA('Tool') then
        if obj:GetAttribute('Ammo') then
            obj:SetAttribute('Ammo', ammoValue)
        end
        if obj:GetAttribute('MaxAmmo') then
            obj:SetAttribute('MaxAmmo', ammoValue)
        end
        if obj:GetAttribute('CurrentAmmo') then
            obj:SetAttribute('CurrentAmmo', ammoValue)
        end
        if obj:GetAttribute('AmmoInClip') then
            obj:SetAttribute('AmmoInClip', ammoValue)
        end
        if obj:GetAttribute('ClipSize') then
            obj:SetAttribute('ClipSize', ammoValue)
        end
        if obj:GetAttribute('FireRate') then
            obj:SetAttribute('FireRate', 0)
        end
        if obj:GetAttribute('ReloadTime') then
            obj:SetAttribute('ReloadTime', 0)
        end
        if obj:GetAttribute('Cooldown') then
            obj:SetAttribute('Cooldown', 0)
        end
        if obj:GetAttribute('RateOfFire') then
            obj:SetAttribute('RateOfFire', 0)
        end
        if obj:GetAttribute('Delay') then
            obj:SetAttribute('Delay', 0)
        end
        if obj:GetAttribute('Automatic') ~= nil then
            obj:SetAttribute('Automatic', true)
        end
        if obj:GetAttribute('Reloading') ~= nil then
            obj:SetAttribute('Reloading', false)
        end
    end

    if obj.SetAttribute then
        local attributes = {
            Ammo = ammoValue,
            MaxAmmo = ammoValue,
            CurrentAmmo = ammoValue,
            AmmoInClip = ammoValue,
            ClipSize = ammoValue,
            ReserveAmmo = ammoValue,
            FireRate = 0,
            ReloadTime = 0,
            Cooldown = 0,
            RateOfFire = 0,
            Delay = 0,
            Automatic = true,
            Reloading = false,
            CanFire = true,
            CanReload = false,
            Loaded = true,
        }
        for attrName, attrValue in pairs(attributes) do
            if obj:GetAttribute(attrName) ~= nil then
                obj:SetAttribute(attrName, attrValue)
            end
        end
    end
end

local function isGunModWeapon(tool, weaponList)
    if not tool or type(weaponList) ~= 'table' then
        return false
    end
    local toolName = tostring(tool.Name or ''):lower()
    for _, name in ipairs(weaponList) do
        if type(name) == 'string' and name ~= '' then
            local pattern = name:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1')
            if toolName:find(pattern:lower()) then
                return true
            end
        end
    end
    return false
end

local function patchSpreadValues(tool, spreadAmount)
    if not tool then
        return
    end

    local normalizedAmount = tonumber(spreadAmount) or 0
    local function patchInstance(instance)
        if not instance then
            return
        end
        if instance:IsA('NumberValue') or instance:IsA('IntValue') then
            local name = instance.Name:lower()
            if name:find('spread') or name:find('accuracy') or name:find('deviation') then
                instance.Value = normalizedAmount
            end
        end
        if instance.SetAttribute then
            for _, attrName in ipairs({'Spread', 'SpreadAmount', 'SpreadRadius', 'Accuracy', 'Deviation'}) do
                if instance:GetAttribute(attrName) ~= nil then
                    instance:SetAttribute(attrName, normalizedAmount)
                end
            end
        end
    end

    patchInstance(tool)
    for _, child in ipairs(tool:GetDescendants()) do
        patchInstance(child)
    end
end

local function applyGunModifications()
    local mods = shared.honx['Gun Modifications']
    if not mods then
        return
    end

    local tool = getEquippedTool()
    if not tool then
        return
    end

    if mods['Spread Modifier'] and mods['Spread Modifier']['Enabled'] then
        local weapons = mods['Spread Modifier']['Weapons']
        if isGunModWeapon(tool, weapons) then
            patchSpreadValues(tool, mods['Spread Modifier']['Spread Amount'])
        end
    end

    if mods['Double Tap'] and mods['Double Tap']['Enabled'] and mouseDown then
        local weapons = mods['Double Tap']['Weapons']
        if isGunModWeapon(tool, weapons) then
            pcall(function()
                tool:Activate()
            end)
        end
    end
end

local function applyInfiniteAmmo()
    if not shared.honx['Infinite Ammo'] or not shared.honx['Infinite Ammo']['Enabled'] then
        return
    end

    local ammoValue = tonumber(shared.honx['Infinite Ammo']['Ammo Value']) or 6
    ammoValue = math.min(ammoValue, 6)
    local player = localPlayer
    if not player then
        return
    end

    local function patchDescendants(instance)
        for _, obj in ipairs(instance:GetDescendants()) do
            patchAmmoObject(obj, ammoValue)
        end
        for _, obj in ipairs(instance:GetChildren()) do
            patchAmmoObject(obj, ammoValue)
        end
    end

    local character = player.Character
    if character then
        patchDescendants(character)
    end

    local backpack = player:FindFirstChildOfClass('Backpack')
    if backpack then
        patchDescendants(backpack)
    end
end

local function patchRapidFireValues(tool)
    if not tool then
        return
    end

    local function patchInstance(instance)
        if not instance then
            return
        end

        if instance:IsA('NumberValue') or instance:IsA('IntValue') then
            local name = instance.Name:lower()
            if name:find('fire') or name:find('rate') or name:find('delay') or name:find('cooldown') or name:find('reload') or name:find('charge') or name:find('recovery') then
                instance.Value = 0
            end
        end

        if instance.SetAttribute then
            local attributes = {
                FireRate = 0,
                ReloadTime = 0,
                Cooldown = 0,
                RateOfFire = 0,
                Delay = 0,
                ChargeTime = 0,
                Recovery = 0,
                ReloadDelay = 0,
                Automatic = true,
                CanFire = true,
                CanReload = false,
                Loaded = true,
            }
            for attrName, attrValue in pairs(attributes) do
                if instance:GetAttribute(attrName) ~= nil then
                    instance:SetAttribute(attrName, attrValue)
                end
            end
        end
    end

    patchInstance(tool)
    for _, child in ipairs(tool:GetDescendants()) do
        patchInstance(child)
    end
end

local function applyRapidFire()
    if not shared.honx['Gun Modifications']['Double Tap']['Enabled'] then
        return
    end

    local tool = getEquippedTool()
    if not tool then
        return
    end

    local weapons = shared.honx['Gun Modifications']['Double Tap']['Weapons']
    if type(weapons) == 'table' and #weapons > 0 then
        if not isGunModWeapon(tool, weapons) then
            return
        end
    end

    patchRapidFireValues(tool)
end

local originalViewportSize = nil
local function applyStretchRes()
    if not camera then
        return
    end

    if shared.honx['Stretch Resolution'] and shared.honx['Stretch Resolution']['Enabled'] then
        if not originalViewportSize then
            originalViewportSize = camera.ViewportSize
        end
        pcall(function()
            camera.ViewportSize = shared.honx['Stretch Resolution']['Size'] or Vector2.new(1280, 720)
        end)
    elseif originalViewportSize then
        pcall(function()
            camera.ViewportSize = originalViewportSize
        end)
        originalViewportSize = nil
    end
end

local function applyMovementModifiers()
    local player = localPlayer
    if not player or not player.Character then
        return
    end

    local humanoid = player.Character:FindFirstChildOfClass('Humanoid')
    if not humanoid then
        return
    end

    local walkConfig = shared.honx['Local Player']['Speed']
    if walkConfig and walkConfig['Enabled'] then
        local active = walkConfig['Keybind'] == '' or walkSpeedEnabled
        humanoid.WalkSpeed = active and (tonumber(walkConfig['Speed']) or 300) or 16
    else
        if humanoid.WalkSpeed ~= 16 then
            humanoid.WalkSpeed = 16
        end
    end

    local jumpConfig = shared.honx['Local Player']['Jump']
    if jumpConfig and jumpConfig['Enabled'] then
        local active = jumpConfig['Keybind'] == '' or jumpPowerEnabled
        humanoid.JumpPower = active and (tonumber(jumpConfig['Power']) or 100) or 50
    else
        if humanoid.JumpPower ~= 50 then
            humanoid.JumpPower = 50
        end
    end
end

local function destroyFlyBodyVelocity()
    if flyBodyVelocity and flyBodyVelocity.Parent then
        flyBodyVelocity:Destroy()
    end
    flyBodyVelocity = nil
end

local function updateFlyBodyVelocity(rootPart)
    if not rootPart then
        return
    end

    if not flyBodyVelocity or not flyBodyVelocity.Parent then
        flyBodyVelocity = Instance.new('BodyVelocity')
        flyBodyVelocity.Name = 'HONX_FlyBodyVelocity'
        flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBodyVelocity.P = 10000
        flyBodyVelocity.Parent = rootPart
    end

    local speed = tonumber(shared.honx['Local Player']['Fly']['Speed']) or 20
    local moveVector = Vector3.new()
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then
        moveVector = moveVector + camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then
        moveVector = moveVector - camera.CFrame.LookVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then
        moveVector = moveVector - camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then
        moveVector = moveVector + camera.CFrame.RightVector
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
        moveVector = moveVector + Vector3.new(0, 1, 0)
    end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C) then
        moveVector = moveVector - Vector3.new(0, 1, 0)
    end

    if moveVector.Magnitude > 0 then
        flyBodyVelocity.Velocity = moveVector.Unit * speed
    else
        flyBodyVelocity.Velocity = Vector3.new(0, -2, 0)
    end
end

local function handleFly()
    if not shared.honx['Local Player']['Fly'] or not shared.honx['Local Player']['Fly']['Enabled'] then
        destroyFlyBodyVelocity()
        return
    end

    local player = localPlayer
    if not player or not player.Character then
        destroyFlyBodyVelocity()
        return
    end

    local rootPart = getRootPart(player.Character)
    if not rootPart then
        destroyFlyBodyVelocity()
        return
    end

    if flyEnabled then
        updateFlyBodyVelocity(rootPart)
    else
        destroyFlyBodyVelocity()
    end
end

local function applyGunSettings()
    if not isSupportedGame() then
        return
    end

    local settings = shared.honx['Gun Settings']
    if not settings or not settings['Enabled'] then
        return
    end

    local tool = getEquippedTool()
    if not tool or not mouseDown then
        return
    end

    local targetCharacter = getClosestTarget(shared.honx['Aim Assist'])
    if not targetCharacter then
        return
    end

    local targetPart = getTargetPart(targetCharacter, shared.honx['Aim Assist']['Hit Part'])
    if not targetPart then
        return
    end

    local worldDistance = (camera.CFrame.Position - targetPart.Position).Magnitude
    local maxGunDistance = math.huge
    local ranges = settings['Distance Detections'] or {}
    maxGunDistance = ranges.Far or math.huge
    
    if worldDistance <= maxGunDistance then
        pcall(function()
            tool:Activate()
        end)
    end
end

local espGuis = {}
local hitboxParts = {}
local tracerLines = {}
local statusGui = nil
local statusList = nil
local drawingAvailable = type(Drawing) == 'table' and type(Drawing.new) == 'function'

local function createEspGui(player)
    if not player or not player.Character then
        return nil
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        return nil
    end

    local playerGui = localPlayer and localPlayer:FindFirstChildOfClass('PlayerGui')
    if not playerGui then
        return nil
    end

    local billboard = Instance.new('BillboardGui')
    billboard.Name = 'HONX_ESP'
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 110, 0, 16)
    billboard.StudsOffset = Vector3.new(0, 2, 0)
    billboard.Adornee = targetPart
    billboard.Parent = playerGui

    local label = Instance.new('TextLabel')
    label.Name = 'EspLabel'
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = player.Name
    label.TextColor3 = shared.honx['ESP']['Color']
    label.TextStrokeTransparency = 0
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.TextScaled = false
    label.TextSize = 12
    label.Font = Enum.Font.SourceSansBold
    label.Parent = billboard

    return billboard
end

local function createHitboxPart(player)
    if not player or not player.Character then
        return nil
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        return nil
    end

    local part = Instance.new('Part')
    part.Name = 'HONX_Hitbox'
    part.Anchored = false
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = true
    part.CastShadow = false
    part.Transparency = 1
    part.Massless = true
    part.Size = getgenv().HitboxSize
    part.CFrame = targetPart.CFrame
    part.Parent = player.Character

    local weld = Instance.new('WeldConstraint')
    weld.Name = 'HONX_HitboxWeld'
    weld.Part0 = part
    weld.Part1 = targetPart
    weld.Parent = part

    return part
end

local function destroyHitboxPart(player)
    local hitbox = hitboxParts[player]
    if hitbox and hitbox.Parent then
        hitbox:Destroy()
    end
    hitboxParts[player] = nil
end

local function updateHitboxPart(player)
    if not getgenv().Enabled then
        destroyHitboxPart(player)
        return
    end

    if not isValidTarget(player) or player == localPlayer or not player.Character then
        destroyHitboxPart(player)
        return
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        destroyHitboxPart(player)
        return
    end

    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
    if shared.honx['ESP']['Distance'] and distance > shared.honx['ESP']['Distance'] then
        destroyHitboxPart(player)
        return
    end

    local hitbox = hitboxParts[player]
    if not hitbox or not hitbox.Parent then
        hitbox = createHitboxPart(player)
        hitboxParts[player] = hitbox
    end
    if hitbox then
        hitbox.Size = getgenv().HitboxSize
    end
end

local function destroyEspGui(player)
    local gui = espGuis[player]
    if gui and gui.Parent then
        gui:Destroy()
    end
    espGuis[player] = nil
end

local function createTracerLine(player)
    if not drawingAvailable then
        return nil
    end

    local line = Drawing.new('Line')
    line.Visible = false
    line.Transparency = shared.honx['ESP']['Tracer']['Transparency'] or 1
    line.Color = shared.honx['ESP']['Tracer']['Color'] or Color3.new(1, 0.4, 0.4)
    line.Thickness = shared.honx['ESP']['Tracer']['Thickness'] or 0.5
    return line
end

local function destroyTracerLine(player)
    local line = tracerLines[player]
    if line then
        if type(line.Remove) == 'function' then
            line:Remove()
        else
            line.Visible = false
        end
    end
    tracerLines[player] = nil
end

local function updateTracerLine(player)
    if not shared.honx['ESP']['Tracer'] or not shared.honx['ESP']['Tracer']['Enabled'] then
        destroyTracerLine(player)
        return
    end
    if not drawingAvailable or not isValidTarget(player) or player == localPlayer or not player.Character then
        destroyTracerLine(player)
        return
    end

    local targetPart = getTargetPart(player.Character, 'Head') or getRootPart(player.Character)
    if not targetPart then
        destroyTracerLine(player)
        return
    end

    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
    if shared.honx['ESP']['Distance'] and distance > shared.honx['ESP']['Distance'] then
        destroyTracerLine(player)
        return
    end

    local viewportSize = camera.ViewportSize
    local targetScreenPoint, onScreen = camera:WorldToViewportPoint(targetPart.Position)
    if shared.honx['ESP']['Tracer']['Hide When Offscreen'] and not onScreen then
        destroyTracerLine(player)
        return
    end

    local tracer = tracerLines[player]
    if not tracer then
        tracer = createTracerLine(player)
        if not tracer then
            return
        end
        tracerLines[player] = tracer
    end

    tracer.Color = shared.honx['ESP']['Tracer']['Color'] or tracer.Color
    tracer.Thickness = shared.honx['ESP']['Tracer']['Thickness'] or 0.5
    tracer.Transparency = shared.honx['ESP']['Tracer']['Transparency'] or tracer.Transparency
    local startPoint = Vector2.new(viewportSize.X / 2, viewportSize.Y / 2)
    if mouse and type(mouse.X) == 'number' and type(mouse.Y) == 'number' then
        startPoint = Vector2.new(mouse.X, mouse.Y)
    end
    tracer.From = startPoint
    tracer.To = Vector2.new(targetScreenPoint.X, targetScreenPoint.Y)
    tracer.Visible = true
end

local function refreshTracers()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            updateTracerLine(player)
        end
    end
end

local function isPlayerUnderMouse(player)
    if not mouse or not mouse.Target or not player or not player.Character then
        return false
    end
    return mouse.Target:IsDescendantOf(player.Character)
end

local function updateEspGui(player)
    if not shared.honx['ESP'] or not shared.honx['ESP']['Enabled'] then
        destroyEspGui(player)
        return
    end

    if not isValidTarget(player) or player == localPlayer then
        destroyEspGui(player)
        return
    end

    local character = player.Character
    if not character then
        destroyEspGui(player)
        return
    end

    local targetPart = getTargetPart(character, 'Head') or getRootPart(character)
    if not targetPart then
        destroyEspGui(player)
        return
    end

    local distance = (camera.CFrame.Position - targetPart.Position).Magnitude
    if shared.honx['ESP']['Distance'] and distance > shared.honx['ESP']['Distance'] then
        destroyEspGui(player)
        return
    end

    local gui = espGuis[player]
    if not gui or not gui.Parent then
        gui = createEspGui(player)
        espGuis[player] = gui
    end
    if not gui then
        return
    end

    gui.Adornee = targetPart
    local label = gui:FindFirstChild('EspLabel')
    if label then
        label.Text = player.Name
        label.TextColor3 = isPlayerUnderMouse(player) and Color3.new(1, 0, 0) or (shared.honx['ESP']['Color'] or Color3.new(1, 0, 0))
        label.TextTransparency = shared.honx['ESP']['Transparency'] and 0.5 or 0
    end
end

local function refreshEsp()
    if not shared.honx['ESP'] or not shared.honx['ESP']['Enabled'] then
        for player in pairs(espGuis) do
            destroyEspGui(player)
        end
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                updateEspGui(player)
            end
        end
    end

    if getgenv().Enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                updateHitboxPart(player)
            end
        end
    else
        for player in pairs(hitboxParts) do
            destroyHitboxPart(player)
        end
    end
end

local function createStatusGui()
    if statusGui and statusGui.Parent then
        return
    end
    local playerGui = localPlayer and localPlayer:FindFirstChildOfClass('PlayerGui')
    if not playerGui then
        return
    end

    local existingGui = nil
    for _, child in ipairs(playerGui:GetChildren()) do
        if child.Name == 'HONX_StatusGui' and child:IsA('ScreenGui') then
            if not existingGui then
                existingGui = child
            else
                child:Destroy()
            end
        end
    end

    if existingGui then
        statusGui = existingGui
        statusList = statusGui:FindFirstChild('HONX_StatusList')
        if statusList then
            return
        end
    end

    statusGui = Instance.new('ScreenGui')
    statusGui.Name = 'HONX_StatusGui'
    statusGui.ResetOnSpawn = false
    statusGui.Parent = playerGui

    local frame = Instance.new('Frame')
    frame.Name = 'HONX_StatusFrame'
    frame.Size = UDim2.new(0, 160, 0, 0)
    frame.Position = UDim2.new(0, 10, 0, 10)
    frame.AutomaticSize = Enum.AutomaticSize.Y
    frame.BackgroundTransparency = 1
    frame.BackgroundColor3 = Color3.new(0.05, 0.05, 0.05)
    frame.BorderSizePixel = 0
    frame.ZIndex = 10
    frame.ClipsDescendants = true
    frame.Parent = statusGui

    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local dragStart
    local dragStartPos
    local dragging = false

    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            dragStartPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and dragging and dragStartPos then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                dragStartPos.X.Scale,
                dragStartPos.X.Offset + delta.X,
                dragStartPos.Y.Scale,
                dragStartPos.Y.Offset + delta.Y
            )
        end
    end)

    local titleLabel = Instance.new('TextLabel')
    titleLabel.Name = 'HONX_TitleLabel'
    titleLabel.Size = UDim2.new(1, -10, 0, 18)
    titleLabel.Position = UDim2.new(0, 5, 0, 5)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = 'HONX'
    titleLabel.TextColor3 = Color3.new(0.8, 0.95, 1)
    titleLabel.TextScaled = false
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.SourceSansSemibold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = frame

    statusList = Instance.new('Frame')
    statusList.Name = 'HONX_StatusList'
    statusList.Size = UDim2.new(1, -10, 0, 0)
    statusList.Position = UDim2.new(0, 5, 0, 28)
    statusList.AutomaticSize = Enum.AutomaticSize.Y
    statusList.BackgroundTransparency = 1
    statusList.Parent = frame

    local layout = Instance.new('UIListLayout')
    layout.Parent = statusList
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 4)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

local function createStatusLine(text, color, order)
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(1, 0, 0, 18)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color
    label.RichText = true
    label.TextScaled = false
    label.TextSize = 14
    label.Font = Enum.Font.SourceSansSemibold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = order
    label.Parent = statusList
    return label
end

local function updateStatusGui()
    if not statusGui or not statusGui.Parent then
        createStatusGui()
    end
    if not statusGui or not statusGui.Parent or not statusList or not statusList.Parent then
        return
    end

    for _, child in ipairs(statusList:GetChildren()) do
        if child:IsA('TextLabel') then
            child:Destroy()
        end
    end

    local function formatFeature(name)
        local labels = {
            ['Aim Assist'] = 'Lock',
            ['Silent Aim'] = 'Assist',
            ['Trigger Bot'] = 'Auto Shoot',
            ['Tracer'] = 'Line',
            ['Stretch Res'] = 'Resolution',
            ['Fly'] = 'Levitate',
            ['Speed'] = 'Speed',
            ['Jump'] = 'Jump',
        }
        return (labels[name] or name) .. ' (On)'
    end

    local function getPlayerHealthArmor()
        local player = localPlayer
        if not player or not player.Character then
            return 0, 0, nil
        end

        local humanoid = player.Character:FindFirstChildOfClass('Humanoid')
        local currentHealth = 0
        local maxHealth = 0
        if humanoid then
            currentHealth = humanoid.Health or 0
            maxHealth = humanoid.MaxHealth or 0
        end

        local armor
        local armorObject = player.Character:FindFirstChild('Armor')
        if armorObject and (armorObject:IsA('NumberValue') or armorObject:IsA('IntValue')) then
            armor = armorObject.Value
        elseif player.GetAttribute and player:GetAttribute('Armor') ~= nil then
            armor = player:GetAttribute('Armor')
        elseif player.Character.GetAttribute and player.Character:GetAttribute('Armor') ~= nil then
            armor = player.Character:GetAttribute('Armor')
        end

        return math.floor(currentHealth), math.floor(maxHealth), armor
    end

    local function getAimbotStatusText()
        if not (shared.honx['Aim Assist']['Enabled'] and (aimEnabled or isWeaponEquipped())) then
            return nil
        end
        local targetCharacter = selectedAimbotTarget
        if targetCharacter then
            local targetPlayer = getPlayerFromCharacter(targetCharacter)
            if targetPlayer then
                return 'Targeting (' .. targetPlayer.Name .. ')'
            end
        end
        return formatFeature('Aim Assist')
    end

    if healthDisplayEnabled then
        local currentHealth, maxHealth, armor = getPlayerHealthArmor()
        if maxHealth <= 0 then
            maxHealth = 100
        end
        local healthText = 'Health <font color="#00FF00">' .. tostring(currentHealth) .. '</font>'
            .. '<font color="#FFFFFF">/</font>'
            .. '<font color="#0000FF">' .. tostring(maxHealth) .. '</font>'
        if armor ~= nil then
            healthText = healthText .. ' Armor ' .. tostring(math.floor(armor))
        end
        createStatusLine(healthText, Color3.new(1, 1, 1), 0)
    end

    local triggerPlayerName = nil
    if shared.honx['Trigger Bot']['Enabled'] and triggerEnabled then
        local targetCharacter = getClosestTarget(shared.honx['Trigger Bot'])
        if targetCharacter then
            local targetPlayer = getPlayerFromCharacter(targetCharacter)
            if targetPlayer then
                triggerPlayerName = targetPlayer.Name
            end
        end
    end

    local features = {
        { name = getAimbotStatusText(), enabled = shared.honx['Aim Assist']['Enabled'] and (aimEnabled or isWeaponEquipped()) },
        { name = formatFeature('Silent Aim'), enabled = shared.honx['Silent Aim']['Enabled'] and silentEnabled },
        { name = triggerPlayerName and ('Auto Shoot (' .. triggerPlayerName .. ')') or formatFeature('Trigger Bot'), enabled = shared.honx['Trigger Bot']['Enabled'] and (triggerEnabled or isWeaponEquipped()) },
        { name = formatFeature('Tracer'), enabled = shared.honx['ESP']['Tracer'] and shared.honx['ESP']['Tracer']['Enabled'] },
        { name = formatFeature('Stretch Res'), enabled = shared.honx['Stretch Resolution'] and shared.honx['Stretch Resolution']['Enabled'] },
        { name = formatFeature('Fly'), enabled = shared.honx['Local Player']['Fly'] and shared.honx['Local Player']['Fly']['Enabled'] and flyEnabled },
        { name = formatFeature('Speed'), enabled = shared.honx['Local Player']['Speed']['Enabled'] and walkSpeedEnabled },
        { name = formatFeature('Jump'), enabled = shared.honx['Local Player']['Jump']['Enabled'] and jumpPowerEnabled },
    }

    local order = 1
    local activeCount = 0
    for _, feature in ipairs(features) do
        if feature.enabled and feature.name then
            createStatusLine(feature.name, Color3.new(0.8, 0.95, 1), order)
            order = order + 1
            activeCount = activeCount + 1
        end
    end

    if activeCount == 0 then
        createStatusLine('No active features', Color3.new(1, 1, 1), order)
    end
end

Players.PlayerRemoving:Connect(function(player)
    destroyEspGui(player)
    destroyHitboxPart(player)
    destroyTracerLine(player)
    if player == localPlayer and statusGui and statusGui.Parent then
        statusGui:Destroy()
        statusGui = nil
    end
end)

local function normalizeKeyName(input)
    if not input or not input.KeyCode then
        return ''
    end
    return tostring(input.KeyCode.Name):upper()
end

local function normalizeKeyBind(keybind)
    if not keybind then
        return ''
    end
    local keyName = tostring(keybind):upper()
    if keyName == "'" or keyName == '"' then
        return 'QUOTE'
    end
    if keyName == 'APOSTROPHE' then
        return 'QUOTE'
    end
    return keyName
end

local function updateKeyState(input, isDown)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    local keyName = normalizeKeyName(input)
    if shared.honx['Aim Assist']['Method'] == 'Hold' and keyName == normalizeKeyBind(shared.honx['Aim Assist']['Keybind']) then
        aimEnabled = isDown
    end
    if shared.honx['Silent Aim']['Method'] == 'Hold' and keyName == normalizeKeyBind(shared.honx['Silent Aim']['Keybind']) then
        silentEnabled = isDown
    end
    if shared.honx['Trigger Bot']['Method'] == 'Hold' and keyName == normalizeKeyBind(shared.honx['Trigger Bot']['Keybind']) then
        triggerEnabled = isDown
    end
end

local function handleToggleInput(input)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then
        return
    end

    local keyName = normalizeKeyName(input)
    if shared.honx['Aim Assist']['Method'] == 'Toggle' and keyName == normalizeKeyBind(shared.honx['Aim Assist']['Keybind']) then
        if aimEnabled then
            aimEnabled = false
            selectedAimbotTarget = nil
        else
            selectedAimbotTarget = getClosestTarget(shared.honx['Aim Assist'])
            aimEnabled = selectedAimbotTarget ~= nil
        end
    end
    if shared.honx['Silent Aim']['Method'] == 'Toggle' and keyName == normalizeKeyBind(shared.honx['Silent Aim']['Keybind']) then
        silentEnabled = not silentEnabled
    end
    if shared.honx['Trigger Bot']['Method'] == 'Toggle' and keyName == normalizeKeyBind(shared.honx['Trigger Bot']['Keybind']) then
        triggerEnabled = not triggerEnabled
    end

    if shared.honx['Local Player']['Fly'] and shared.honx['Local Player']['Fly']['Enabled'] and shared.honx['Local Player']['Fly']['Keybind'] ~= '' and keyName == normalizeKeyBind(shared.honx['Local Player']['Fly']['Keybind']) then
        flyEnabled = not flyEnabled
    end

    if shared.honx['Health Display'] and shared.honx['Health Display']['Keybind'] ~= '' and keyName == normalizeKeyBind(shared.honx['Health Display']['Keybind']) then
        healthDisplayEnabled = not healthDisplayEnabled
    end

    if shared.honx['Local Player']['Speed'] and shared.honx['Local Player']['Speed']['Keybind'] ~= '' and keyName == normalizeKeyBind(shared.honx['Local Player']['Speed']['Keybind']) then
        walkSpeedEnabled = not walkSpeedEnabled
    end
    if shared.honx['Local Player']['Jump'] and shared.honx['Local Player']['Jump']['Keybind'] ~= '' and keyName == normalizeKeyBind(shared.honx['Local Player']['Jump']['Keybind']) then
        jumpPowerEnabled = not jumpPowerEnabled
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = true
    end

    handleToggleInput(input)
    updateKeyState(input, true)
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        mouseDown = false
    end
    updateKeyState(input, false)
end)

hookMouse()

RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastHeavyUpdate >= heavyUpdateInterval then
        applyGunModifications()
        applyRapidFire()
        applyInfiniteAmmo()
    end

    if getgenv().Enabled then
        applyToAllPlayers()
    end

    refreshTracers()
    updateStatusGui()
    applyGunSettings()
    applyMovementModifiers()
    handleFly()
    applyStretchRes()
    autoFire()

    if shared.honx['Trigger Bot']['Enabled'] and triggerEnabled then
        local targetCharacter = getClosestTarget(shared.honx['Trigger Bot'])
        if targetCharacter then
            local tool = getEquippedTool()
            if tool then
                pcall(function()
                    tool:Activate()
                end)
            end
        end
    end

    if shared.honx['Aim Assist']['Enabled'] and aimEnabled then
        local targetCharacter = selectedAimbotTarget
        if not targetCharacter or not isValidTarget(getPlayerFromCharacter(targetCharacter) or nil) then
            aimEnabled = false
            selectedAimbotTarget = nil
        else
            local targetPart = getAimbotTorsoPart(targetCharacter)
            if targetPart then
                aimAt(targetPart)
            else
                aimEnabled = false
                selectedAimbotTarget = nil
            end
        end
    end
end)

-- ============================================
-- INITIALIZE
-- ============================================
refreshEsp()
print("HONX Hub loaded successfully!")