local QBCore = exports['qb-core']:GetCoreObject()

-- Active routes, keyed by server id (source).
-- { citizenid, plate, route = { dropIndex, ... }, step, deposit, lastActionAt }
local ActiveRoutes = {}

-- Cooldowns keyed by citizenid so relogging does not reset them.
local Cooldowns = {}

local function debugPrint(...)
    if Config.Debug then
        print('[qb-delivery]', ...)
    end
end

local function notify(src, msg, nType)
    TriggerClientEvent('QBCore:Notify', src, msg, nType or 'primary')
end

local function trim(s)
    return (s or ''):match('^%s*(.-)%s*$')
end

local function playerCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

-- Random, unique drop-off indices.
local function buildRoute(count)
    local pool = {}
    for i = 1, #Config.DropOffs do pool[i] = i end
    for i = #pool, 2, -1 do
        local j = math.random(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    local route = {}
    for i = 1, math.min(count, #pool) do route[i] = pool[i] end
    return route
end

local function payForDrop(dropIndex)
    local drop = Config.DropOffs[dropIndex]
    local distance = #(Config.Depot.coords - drop.coords)
    local pay = Config.PayBase + math.floor(distance * Config.PayPerMeter)
    return math.min(pay, Config.PayMax)
end

local function dropPayload(route, step)
    local idx = route.route[step]
    local drop = Config.DropOffs[idx]
    return {
        step = step,
        total = #route.route,
        label = drop.label,
        coords = drop.coords,
    }
end

local function setCooldown(citizenid)
    Cooldowns[citizenid] = os.time() + Config.CooldownSeconds
end

---------------------------------------------------------------------
-- Start a route
---------------------------------------------------------------------
QBCore.Functions.CreateCallback('qb-delivery:server:startRoute', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return cb(false) end

    local citizenid = Player.PlayerData.citizenid

    if Config.RequireJob and Player.PlayerData.job.name ~= Config.JobName then
        notify(src, Config.Text.wrong_job, 'error')
        return cb(false)
    end

    if ActiveRoutes[src] then
        notify(src, Config.Text.already_working, 'error')
        return cb(false)
    end

    local cd = Cooldowns[citizenid]
    if cd and cd > os.time() then
        notify(src, Config.Text.cooldown:format(cd - os.time()), 'error')
        return cb(false)
    end

    local coords = playerCoords(src)
    if not coords or #(coords - Config.Depot.coords) > 10.0 then
        return cb(false)
    end

    if Config.Deposit > 0 then
        local balance = Player.PlayerData.money[Config.DepositAccount] or 0
        if balance < Config.Deposit
            or not Player.Functions.RemoveMoney(Config.DepositAccount, Config.Deposit, 'delivery-van-deposit') then
            notify(src, Config.Text.no_money:format(Config.Deposit, Config.DepositAccount), 'error')
            return cb(false)
        end
    end

    local plate = (Config.PlatePrefix .. tostring(math.random(10000, 99999))):sub(1, 8)
    local route = {
        citizenid = citizenid,
        plate = plate,
        route = buildRoute(Config.DeliveriesPerRoute),
        step = 1,
        deposit = Config.Deposit,
        lastActionAt = os.time(),
    }
    ActiveRoutes[src] = route

    debugPrint(('started route for %s (%d drops, plate %s)'):format(citizenid, #route.route, plate))
    notify(src, Config.Text.route_started:format(#route.route, Config.Deposit), 'success')

    cb(true, { plate = plate, drop = dropPayload(route, 1) })
end)

---------------------------------------------------------------------
-- Deliver the current package
---------------------------------------------------------------------
QBCore.Functions.CreateCallback('qb-delivery:server:deliver', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local route = ActiveRoutes[src]
    if not Player or not route then
        notify(src, Config.Text.no_route, 'error')
        return cb(false)
    end

    if route.step > #route.route then
        return cb(false)
    end

    local drop = Config.DropOffs[route.route[route.step]]
    local coords = playerCoords(src)
    if not coords or #(coords - drop.coords) > Config.DropRadius then
        notify(src, Config.Text.not_at_drop, 'error')
        return cb(false)
    end

    if os.time() - route.lastActionAt < Config.MinSecondsPerDrop then
        notify(src, Config.Text.too_fast, 'error')
        return cb(false)
    end

    local pay = payForDrop(route.route[route.step])
    Player.Functions.AddMoney(Config.PayAccount, pay, 'delivery-job-drop')
    notify(src, Config.Text.paid:format(pay), 'success')

    route.step = route.step + 1
    route.lastActionAt = os.time()
    debugPrint(('%s delivered drop %d, paid %d'):format(route.citizenid, route.step - 1, pay))

    if route.step > #route.route then
        notify(src, Config.Text.route_done, 'primary')
        return cb(true, { finished = true })
    end

    cb(true, { finished = false, drop = dropPayload(route, route.step) })
end)

---------------------------------------------------------------------
-- Return the van
---------------------------------------------------------------------
QBCore.Functions.CreateCallback('qb-delivery:server:returnVan', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local route = ActiveRoutes[src]
    if not Player or not route then
        notify(src, Config.Text.no_route, 'error')
        return cb(false)
    end

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or trim(GetVehicleNumberPlateText(veh)) ~= route.plate then
        notify(src, Config.Text.not_in_van, 'error')
        return cb(false)
    end

    if #(GetEntityCoords(ped) - Config.Depot.coords) > 30.0 then
        return cb(false)
    end

    local refund = route.deposit
    local bonus = (route.step > #route.route) and Config.RouteBonus or 0

    if refund > 0 then
        Player.Functions.AddMoney(Config.DepositAccount, refund, 'delivery-van-deposit-refund')
    end
    if bonus > 0 then
        Player.Functions.AddMoney(Config.PayAccount, bonus, 'delivery-route-bonus')
    end

    notify(src, Config.Text.returned:format(refund, bonus), 'success')
    setCooldown(route.citizenid)
    ActiveRoutes[src] = nil
    debugPrint(('%s returned van (refund %d, bonus %d)'):format(route.citizenid, refund, bonus))

    cb(true)
end)

---------------------------------------------------------------------
-- Cancel / cleanup
---------------------------------------------------------------------
RegisterNetEvent('qb-delivery:server:cancel', function()
    local src = source
    local route = ActiveRoutes[src]
    if not route then return end
    setCooldown(route.citizenid)
    ActiveRoutes[src] = nil
    notify(src, Config.Text.cancelled, 'error')
    debugPrint(('%s cancelled route'):format(route.citizenid))
end)

AddEventHandler('playerDropped', function()
    local src = source
    local route = ActiveRoutes[src]
    if route then
        setCooldown(route.citizenid)
        ActiveRoutes[src] = nil
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    math.randomseed(os.time())
end)
