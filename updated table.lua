-- ============================================
-- SAVED HOTKEYS (Persistent)
-- ============================================
shared.Saved = shared.Saved or {
    ['General'] = {
        ['Hotkeys'] = {
            ['Aim Bot'] = 'Q',
            ['Walk Speed'] = 'G',
            ['Silent Aim'] = 'O',
            ['Double Tap'] = 'E',
            ['Trigger Bot'] = 'X',
            ['Trigger Bot Target'] = 'C',
            ['Silent Aim Target'] = 'Q',
            ['Hit Part Override'] = 'F',
            ['Inventory Sorter'] = 'R',
            ['Jump Power'] = 'Y',
        },
        ['Show Hotkeys'] = true,
    },
}

-- ============================================
-- HELPER FUNCTIONS
-- ============================================
local function getSavedHotkey(name, default)
    if shared.Saved and shared.Saved.General and shared.Saved.General.Hotkeys and shared.Saved.General.Hotkeys[name] then
        return tostring(shared.Saved.General.Hotkeys[name]):upper()
    end
    return tostring(default or ''):upper()
end

-- ============================================
-- MERGE SAVED HOTKEYS WITH CONFIG
-- ============================================
shared.honx['Miscellaneous']['Keybinds']['Aim Bot'] = getSavedHotkey('Aim Bot', shared.honx['Miscellaneous']['Keybinds']['Aim Bot'])
shared.honx['Miscellaneous']['Keybinds']['Walk Speed'] = getSavedHotkey('Walk Speed', shared.honx['Miscellaneous']['Keybinds']['Walk Speed'])
shared.honx['Miscellaneous']['Keybinds']['Silent Aim'] = getSavedHotkey('Silent Aim', shared.honx['Miscellaneous']['Keybinds']['Silent Aim'])
shared.honx['Miscellaneous']['Keybinds']['Double Tap'] = getSavedHotkey('Double Tap', shared.honx['Miscellaneous']['Keybinds']['Double Tap'])
shared.honx['Miscellaneous']['Keybinds']['Trigger Bot'] = getSavedHotkey('Trigger Bot', shared.honx['Miscellaneous']['Keybinds']['Trigger Bot'])
shared.honx['Miscellaneous']['Keybinds']['Jump Power'] = getSavedHotkey('Jump Power', shared.honx['Miscellaneous']['Keybinds']['Jump Power'])

shared.honx['Silent Aim']['Keybind'] = shared.honx['Miscellaneous']['Keybinds']['Silent Aim']
shared.honx['Trigger Bot']['Keybind'] = shared.honx['Miscellaneous']['Keybinds']['Trigger Bot']
shared.honx['Aim Assist']['Keybind'] = shared.honx['Miscellaneous']['Keybinds']['Aim Bot']
shared.honx['Local Player']['Speed']['Keybind'] = shared.honx['Miscellaneous']['Keybinds']['Walk Speed']
shared.honx['Local Player']['Jump']['Keybind'] = shared.honx['Miscellaneous']['Keybinds']['Jump Power']

-- ============================================
-- AUTHENTICATION
-- ============================================
shared['Auth_Key'] = shared.honx['Key']

-- ============================================
-- SCRIPT VARIABLES
-- ============================================
getgenv().HitboxSize = Vector3.new(shared.honx['Hitbox Expander']['Size'], shared.honx['Hitbox Expander']['Size'], shared.honx['Hitbox Expander']['Size'])
getgenv().TargetPart = shared.honx['Hitbox Expander']['Target Part']
getgenv().Enabled = shared.honx['Hitbox Expander']['Enabled']

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
            obj:SetAttribute('Cli