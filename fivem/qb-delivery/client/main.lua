local QBCore = exports['qb-core']:GetCoreObject()

local PlayerJob = {}
local onRoute = false
local routeFinished = false
local currentDrop = nil      -- { step, total, label, coords }
local workVan = nil
local workPlate = nil
local dropBlip = nil
local depotBlip = nil
local carrying = false
local packageObj = nil
local busy = false           -- prevents double-pressing E while a callback is pending

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------
local function notify(msg, nType)
    QBCore.Functions.Notify(msg, nType or 'primary')
end

local function showHelp(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, true, -1)
end

local function drawMarker(coords, r, g, b)
    DrawMarker(2, coords.x, coords.y, coords.z + 0.2, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0,
        0.3, 0.3, 0.3, r, g, b, 180, true, true, 2, false, nil, nil, false)
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or GetHashKey(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local timeout = GetGameTimer() + 5000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then return false end
        Wait(10)
    end
    return true
end

local function canWork()
    if not Config.RequireJob then return true end
    return PlayerJob.name == Config.JobName
end

local function removeDropBlip()
    if dropBlip and DoesBlipExist(dropBlip) then RemoveBlip(dropBlip) end
    dropBlip = nil
end

local function setDropBlip(drop)
    removeDropBlip()
    dropBlip = AddBlipForCoord(drop.coords.x, drop.coords.y, drop.coords.z)
    SetBlipSprite(dropBlip, 501)
    SetBlipColour(dropBlip, 5)
    SetBlipRoute(dropBlip, true)
    SetBlipRouteColour(dropBlip, 5)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Delivery: ' .. drop.label)
    EndTextCommandSetBlipName(dropBlip)
end

local function setDepotRoute(enabled)
    if depotBlip and DoesBlipExist(depotBlip) then
        SetBlipRoute(depotBlip, enabled)
    end
end

local function dropPackage()
    if packageObj and DoesEntityExist(packageObj) then
        DetachEntity(packageObj, true, true)
        DeleteEntity(packageObj)
    end
    packageObj = nil
    carrying = false
    ClearPedTasks(PlayerPedId())
end

local function pickUpPackage()
    local ped = PlayerPedId()
    local hash = loadModel(Config.PackageProp)
    if not hash or not loadAnimDict(Config.CarryAnim.dict) then return end

    local pos = GetEntityCoords(ped)
    packageObj = CreateObject(hash, pos.x, pos.y, pos.z + 0.2, true, true, false)
    AttachEntityToEntity(packageObj, ped, GetPedBoneIndex(ped, 60309),
        0.025, 0.08, 0.255, -145.0, 290.0, 0.0, true, true, false, true, 1, true)
    TaskPlayAnim(ped, Config.CarryAnim.dict, Config.CarryAnim.name, 8.0, -8.0, -1, 49, 0, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    carrying = true
end

local function deleteVan()
    if workVan and DoesEntityExist(workVan) then
        SetEntityAsMissionEntity(workVan, true, true)
        DeleteVehicle(workVan)
    end
    workVan = nil
    workPlate = nil
end

local function resetState()
    dropPackage()
    removeDropBlip()
    setDepotRoute(false)
    deleteVan()
    onRoute = false
    routeFinished = false
    currentDrop = nil
end

local function vanRearCoords()
    return GetOffsetFromEntityInWorldCoords(workVan, 0.0, -3.2, 0.0)
end

---------------------------------------------------------------------
-- Van spawn
---------------------------------------------------------------------
local function spawnVan(plate)
    local spawn = Config.Depot.vehicleSpawn
    if IsAnyVehicleNearPoint(spawn.x, spawn.y, spawn.z, 3.0) then
        notify(Config.Text.spawn_blocked, 'error')
        return false
    end

    local hash = loadModel(Config.VehicleModel)
    if not hash then
        print('[qb-delivery] invalid Config.VehicleModel: ' .. tostring(Config.VehicleModel))
        return false
    end

    local veh = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDirtLevel(veh, 0.0)

    if Config.FuelResource and GetResourceState(Config.FuelResource) == 'started' then
        exports[Config.FuelResource]:SetFuel(veh, 100.0)
    end

    -- qb-vehiclekeys: give the player the keys for this plate
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))

    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    workVan = veh
    workPlate = plate
    return true
end

---------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------
local function startRoute()
    if busy then return end
    if not canWork() then return notify(Config.Text.wrong_job, 'error') end
    busy = true

    QBCore.Functions.TriggerCallback('qb-delivery:server:startRoute', function(ok, data)
        busy = false
        if not ok then return end

        if not spawnVan(data.plate) then
            -- Could not spawn: tell the server so the route is cleared.
            TriggerServerEvent('qb-delivery:server:cancel')
            return
        end

        onRoute = true
        routeFinished = false
        currentDrop = data.drop
        setDropBlip(currentDrop)
        notify(Config.Text.next_drop:format(currentDrop.label, currentDrop.step, currentDrop.total))
    end)
end

local function deliver()
    if busy then return end
    busy = true
    QBCore.Functions.TriggerCallback('qb-delivery:server:deliver', function(ok, data)
        busy = false
        if not ok then return end

        dropPackage()
        if data.finished then
            routeFinished = true
            currentDrop = nil
            removeDropBlip()
            setDepotRoute(true)
        else
            currentDrop = data.drop
            setDropBlip(currentDrop)
            notify(Config.Text.next_drop:format(currentDrop.label, currentDrop.step, currentDrop.total))
        end
    end)
end

local function returnVan()
    if busy then return end
    busy = true
    QBCore.Functions.TriggerCallback('qb-delivery:server:returnVan', function(ok)
        busy = false
        if not ok then return end
        TaskLeaveVehicle(PlayerPedId(), workVan, 0)
        Wait(1500)
        resetState()
    end)
end

local function cancelRoute()
    if not onRoute then return notify(Config.Text.no_route, 'error') end
    TriggerServerEvent('qb-delivery:server:cancel')
    resetState()
end

---------------------------------------------------------------------
-- Depot blip
---------------------------------------------------------------------
local function createDepotBlip()
    if depotBlip and DoesBlipExist(depotBlip) then return end
    local b = Config.Depot.blip
    local c = Config.Depot.coords
    depotBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(depotBlip, b.sprite)
    SetBlipColour(depotBlip, b.color)
    SetBlipScale(depotBlip, b.scale)
    SetBlipAsShortRange(depotBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(b.label)
    EndTextCommandSetBlipName(depotBlip)
end

---------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------
CreateThread(function()
    createDepotBlip()

    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local inVeh = IsPedInAnyVehicle(ped, false)

        -- Depot: start route (on foot) or return van (in van)
        local depotDist = #(pos - Config.Depot.coords)
        if not onRoute and not inVeh and depotDist < Config.DrawDistance then
            sleep = 0
            drawMarker(Config.Depot.coords, 255, 200, 0)
            if depotDist < Config.InteractDistance then
                showHelp(Config.Text.start_prompt)
                if IsControlJustReleased(0, 38) then startRoute() end
            end
        elseif onRoute and inVeh and depotDist < 15.0
            and workVan and GetVehiclePedIsIn(ped, false) == workVan then
            sleep = 0
            showHelp(Config.Text.return_prompt)
            if IsControlJustReleased(0, 38) then returnVan() end
        end

        -- Active drop
        if onRoute and currentDrop and workVan and DoesEntityExist(workVan) then
            local dropDist = #(pos - currentDrop.coords)

            if dropDist < 100.0 then
                sleep = 0
                drawMarker(currentDrop.coords, 0, 200, 80)

                if not inVeh then
                    if not carrying then
                        -- Take a package from the back of the van
                        local rear = vanRearCoords()
                        if #(pos - rear) < 1.5 then
                            showHelp(Config.Text.take_prompt)
                            if IsControlJustReleased(0, 38) then pickUpPackage() end
                        end
                    elseif dropDist < Config.InteractDistance then
                        showHelp(Config.Text.deliver_prompt)
                        if IsControlJustReleased(0, 38) then
                            if #(GetEntityCoords(workVan) - currentDrop.coords) > Config.VanMaxDistance then
                                notify(Config.Text.van_too_far, 'error')
                            else
                                deliver()
                            end
                        end
                    end
                end
            end
        end

        -- While carrying: no sprinting, jumping, attacking or entering vehicles
        if carrying then
            sleep = 0
            DisableControlAction(0, 21, true) -- sprint
            DisableControlAction(0, 22, true) -- jump
            DisableControlAction(0, 23, true) -- enter vehicle
            DisableControlAction(0, 24, true) -- attack
            DisableControlAction(0, 25, true) -- aim
            if not IsEntityPlayingAnim(ped, Config.CarryAnim.dict, Config.CarryAnim.name, 3) then
                TaskPlayAnim(ped, Config.CarryAnim.dict, Config.CarryAnim.name, 8.0, -8.0, -1, 49, 0, false, false, false)
            end
        end

        -- Van destroyed or gone: cancel route
        if onRoute and (not workVan or not DoesEntityExist(workVan) or IsEntityDead(workVan)) then
            cancelRoute()
        end

        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- QBCore player events
---------------------------------------------------------------------
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerJob = QBCore.Functions.GetPlayerData().job or {}
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    PlayerJob = job or {}
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    if onRoute then
        TriggerServerEvent('qb-delivery:server:cancel')
    end
    resetState()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local data = QBCore.Functions.GetPlayerData()
    PlayerJob = (data and data.job) or {}
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    resetState()
    if depotBlip and DoesBlipExist(depotBlip) then RemoveBlip(depotBlip) end
end)

---------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------
RegisterCommand('canceldelivery', cancelRoute, false)

if Config.Debug then
    -- Prints your position so you can add your own depot / drop-off points.
    RegisterCommand('qbdelivery_coords', function()
        local ped = PlayerPedId()
        local c = GetEntityCoords(ped)
        local msg = ('vector3(%.2f, %.2f, %.2f)  heading %.1f'):format(c.x, c.y, c.z, GetEntityHeading(ped))
        print(msg)
        notify(msg)
    end, false)

    -- Teleports you (and your van, if you are driving it) to the current
    -- drop-off, or to the depot when the route is finished. Testing only.
    RegisterCommand('qbdelivery_tp', function()
        local ped = PlayerPedId()
        local target = currentDrop and currentDrop.coords or Config.Depot.coords
        local veh = GetVehiclePedIsIn(ped, false)
        local entity = (veh ~= 0) and veh or ped
        SetEntityCoords(entity, target.x + 4.0, target.y, target.z, false, false, false, false)
    end, false)
end
