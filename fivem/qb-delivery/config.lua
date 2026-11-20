Config = {}

-- Print extra information to the F8 / server console.
Config.Debug = false

---------------------------------------------------------------------
-- Who can work
---------------------------------------------------------------------
-- false = anyone can start a route.
-- true  = the player's QBCore job name must equal Config.JobName.
Config.RequireJob = false
Config.JobName = 'delivery' -- add this job to qb-core/shared/jobs.lua if RequireJob = true

---------------------------------------------------------------------
-- Depot (where routes start and the van is returned)
-- Coordinates are in the vanilla GTA V map (GoPostal, Downtown Vinewood).
-- Use /qbdelivery_coords in-game (Config.Debug = true) to grab your own.
---------------------------------------------------------------------
Config.Depot = {
    coords = vector3(78.79, 111.83, 81.17),   -- the marker you walk up to
    vehicleSpawn = vector4(69.14, 120.81, 79.13, 160.0),
    blip = { sprite = 478, color = 5, scale = 0.8, label = 'Delivery Depot' },
}

Config.InteractDistance = 2.0   -- metres to show the "Press E" prompt
Config.DrawDistance = 25.0      -- metres to start drawing markers

---------------------------------------------------------------------
-- Vehicle (base-game models only, no addon / paid assets)
---------------------------------------------------------------------
Config.VehicleModel = 'speedo'  -- vanilla van. 'boxville2' (GoPostal) also works.
Config.PlatePrefix = 'DLV'      -- plate becomes e.g. DLV12345 (max 8 chars total)
Config.FuelResource = 'LegacyFuel' -- set to false if you don't use a fuel script

-- Refundable deposit charged when the van is taken out. 0 = disabled.
Config.Deposit = 250
Config.DepositAccount = 'bank'

---------------------------------------------------------------------
-- Route + pay
---------------------------------------------------------------------
Config.DeliveriesPerRoute = 4
Config.PayAccount = 'cash'
Config.PayBase = 120            -- flat pay per package
Config.PayPerMeter = 0.06       -- extra pay per metre between depot and drop-off
Config.PayMax = 600             -- cap per package
Config.RouteBonus = 200         -- paid when the van is returned after finishing every drop

-- Anti-abuse (checked on the SERVER)
Config.DropRadius = 6.0         -- player must be this close to the door (server check)
Config.VanMaxDistance = 40.0    -- van must be this close to the drop (client check)
Config.MinSecondsPerDrop = 20   -- fastest allowed time between two drops
Config.CooldownSeconds = 60     -- wait after finishing / cancelling before a new route

-- Package prop (base-game prop) and carry animation (base-game anim dict)
Config.PackageProp = 'hei_prop_heist_box'
Config.CarryAnim = { dict = 'anim@heists@box_carry@', name = 'idle' }

---------------------------------------------------------------------
-- Drop-off points (vanilla map, front doors / porches)
-- Add as many as you like; a route picks random unique ones.
---------------------------------------------------------------------
Config.DropOffs = {
    { label = 'Forum Drive',        coords = vector3(-14.21, -1441.88, 31.10) },
    { label = 'Grove Street',       coords = vector3(126.73, -1929.98, 21.38) },
    { label = 'Vespucci Canals',    coords = vector3(-1083.41, -1261.71, 5.59) },
    { label = 'Mirror Park',        coords = vector3(1060.47, -378.35, 68.23) },
    { label = 'Rockford Hills',     coords = vector3(-817.86, 177.93, 72.22) },
    { label = 'Vinewood Hills',     coords = vector3(-174.33, 502.42, 137.42) },
    { label = 'El Burro Heights',   coords = vector3(1257.47, -1761.36, 49.66) },
    { label = 'Little Seoul',       coords = vector3(-668.36, -971.81, 22.34) },
    { label = 'Morningwood',        coords = vector3(-1371.42, -365.17, 36.65) },
    { label = 'West Vinewood',      coords = vector3(-597.54, 279.71, 82.08) },
}

---------------------------------------------------------------------
-- Text
---------------------------------------------------------------------
Config.Text = {
    start_prompt      = 'Press ~INPUT_CONTEXT~ to start a delivery route',
    return_prompt     = 'Press ~INPUT_CONTEXT~ to return the van',
    take_prompt       = 'Press ~INPUT_CONTEXT~ to take a package',
    deliver_prompt    = 'Press ~INPUT_CONTEXT~ to deliver the package',
    wrong_job         = 'You are not employed as a courier.',
    already_working   = 'You already have an active route.',
    cooldown          = 'Take a break. You can start a new route in %d seconds.',
    no_money          = 'You need $%d in your %s for the van deposit.',
    spawn_blocked     = 'The van parking spot is blocked.',
    route_started     = 'Route started: %d packages. Deposit of $%d taken.',
    next_drop         = 'Next drop: %s (%d/%d)',
    van_too_far       = 'Your van is too far away.',
    paid              = 'Package delivered! You earned $%d.',
    route_done        = 'All packages delivered. Return the van to the depot.',
    returned          = 'Van returned. Deposit refunded: $%d. Bonus: $%d.',
    cancelled         = 'Route cancelled. Your deposit was not refunded.',
    not_in_van        = 'You need to be in your work van.',
    too_fast          = 'Slow down, that delivery was suspiciously fast.',
    not_at_drop       = 'You are not at the drop-off point.',
    no_route          = 'You do not have an active route.',
}
