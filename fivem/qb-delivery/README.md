# qb-delivery

A simple package delivery job for **QBCore** FiveM servers.

Pick up a van at the depot, drive to a set of random addresses, carry each
package from the back of the van to the door, then bring the van back for
your deposit and a route bonus.

The resource uses only **base-game GTA V content** (the `speedo` van,
the `hei_prop_heist_box` prop, a vanilla animation and vanilla map
coordinates). It has no addon models, no paid or escrowed scripts, no UI
libraries and no third-party assets.

## Features

- Depot blip and marker. Press **E** to start a route.
- Refundable van deposit (configurable, can be turned off).
- Random, non-repeating drop-offs with a GPS route.
- Take the package from the rear of the van and carry it to the door, with a
  carry animation and prop. You can't sprint, jump or drive while carrying.
- Pay per package scales with distance from the depot, up to a cap.
- A bonus when you return the van after finishing every drop.
- Optional job lock (`Config.RequireJob`).
- The server checks every payout:
  - The route state lives on the server. The client never sends an amount.
  - The server checks the player's position against the current drop-off
    (OneSync).
  - Drops have a minimum time between them, so teleport farming doesn't pay.
  - A van can only be returned if the player is sitting in the vehicle whose
    plate the server generated.
  - A cooldown after each route is tied to the citizen ID, so relogging
    doesn't reset it.
- Cleans up the van, prop and blips when you cancel, relog or the resource
  stops.

## Requirements

| Dependency | Notes |
|---|---|
| [qb-core](https://github.com/qbcore-framework/qb-core) | Required |
| OneSync | Required. The server reads player and vehicle positions. It is on by default in txAdmin/recipe servers. |
| [qb-vehiclekeys](https://github.com/qbcore-framework/qb-vehiclekeys) | Optional. Gives you keys to the van. |
| LegacyFuel | Optional. Fills the tank. Set `Config.FuelResource = false` if you don't use it. |

## Installation

1. Copy the `qb-delivery` folder into your server's `resources` directory,
   for example `resources/[local]/qb-delivery`.
2. Add it to `server.cfg` **after** qb-core:
   ```cfg
   ensure qb-core
   # ...your other qb resources...
   ensure qb-delivery
   ```
3. (Optional) To lock the job to employees, set `Config.RequireJob = true` and
   add a job to `qb-core/shared/jobs.lua`:
   ```lua
   ['delivery'] = {
       label = 'Courier',
       defaultDuty = true,
       offDutyPay = false,
       grades = {
           ['0'] = { name = 'Driver', payment = 50 },
       },
   },
   ```
4. Restart the server, or run `refresh` then `ensure qb-delivery` in the
   server console.

## How to play

1. Go to the **Delivery Depot** blip (GoPostal, Downtown Vinewood by default).
2. Stand on the yellow marker and press **E**. The deposit is taken and you are
   put in the van.
3. Follow the GPS to the drop-off. Park nearby (within 40 m), get out, walk to
   the back of the van and press **E** to take a package.
4. Carry it to the green marker at the door and press **E** to deliver. You are
   paid straight away.
5. After the last drop, drive back to the depot. While in the van near the
   depot, press **E** to return it. You get your deposit back plus the route
   bonus.

`/canceldelivery` cancels the route at any time. The van is removed and the
deposit is kept.

## Configuration

Everything is in `config.lua`:

| Option | What it does |
|---|---|
| `Config.Depot` | Depot marker, van spawn point (`vector4` with heading) and blip |
| `Config.VehicleModel` | Any **base-game** vehicle spawn name (`speedo`, `boxville2`, `pony`, ...) |
| `Config.Deposit` / `DepositAccount` | Refundable deposit (`0` disables it) |
| `Config.DeliveriesPerRoute` | Number of drops per route |
| `Config.PayBase`, `PayPerMeter`, `PayMax`, `RouteBonus`, `PayAccount` | Pay settings |
| `Config.DropRadius`, `VanMaxDistance`, `MinSecondsPerDrop`, `CooldownSeconds` | Anti-abuse settings |
| `Config.DropOffs` | List of `{ label, coords }` addresses. Add your own. |
| `Config.Text` | All player-facing strings |

If you're unsure about a coordinate, set `Config.Debug = true`, stand where you
want it and run `/qbdelivery_coords`. The position and heading are printed to
F8 and shown as a notification.

## Testing on a local server

### 1. Set up a local QBCore server (one-time)

1. Get a free **license key** at <https://portal.cfx.re> (Server Keys). For a
   local server, set the IP to `127.0.0.1`.
2. Download the latest recommended **FXServer artifact** for your OS from
   <https://runtime.fivem.net/artifacts/fivem/> (Windows: `build_server_windows`,
   Linux: `build_proxy_linux`), then extract it into a folder such as
   `C:\FXServer\server`.
3. Run `FXServer.exe` (or `./run.sh` on Linux). **txAdmin** opens in your browser.
4. In the txAdmin setup, choose **Popular Recipes → QBCore Framework**. Enter
   your license key and let it create the database. You need MariaDB or MySQL
   running locally. XAMPP or a MariaDB install with default settings works.
5. When the recipe finishes, start the server from txAdmin.

### 2. Install the resource

1. Copy `qb-delivery` into the recipe's `resources/[local]/` folder (create it
   if it doesn't exist).
2. Add `ensure qb-delivery` to the end of `server.cfg`.
3. For testing, set `Config.Debug = true` and lower `Config.MinSecondsPerDrop`
   (for example to `5`) in `config.lua`.
4. Restart the server from txAdmin, or type `ensure qb-delivery` in the live
   console.

The server console should show `Started resource qb-delivery` with no errors.

### 3. Connect and test

1. Start the FiveM client. Press **F8** and run `connect 127.0.0.1:30120`, or
   find your server under *Localhost* in the server browser.
2. Create a character.
3. Give yourself admin rights, if you haven't already. Add
   `add_principal identifier.license:<your license> group.admin` to
   `server.cfg`, or use txAdmin. Your license is listed in txAdmin → Players.
4. Give yourself money for the deposit: `/givemoney <your id> bank 1000`. Use
   `/id` to see your ID.
5. Travel to the depot with `/tpm` on a waypoint, or drive there.

### 4. Test checklist

| # | Test | Expected result |
|---|---|---|
| 1 | Walk onto the depot marker and press E | $250 removed from bank, van spawns with a `DLV#####` plate, you're in it, GPS set |
| 2 | Get out and stand on the depot marker again | No start prompt (only one route at a time; the server also rejects a second start) |
| 3 | Drive to the drop (or run `/qbdelivery_tp` while in the van) | Green marker visible |
| 4 | Walk to the van's rear and press E | Box appears in your hands, carry animation plays, sprint and jump are disabled |
| 5 | Press E at the door | Cash paid, next drop shown on GPS |
| 6 | Deliver twice within `MinSecondsPerDrop` | "Slow down..." and no pay |
| 7 | Leave the van more than 40 m away and try to deliver | "Your van is too far away" |
| 8 | Finish every drop and drive back | GPS routes you to the depot. Press E in the van to get the refund and the bonus. The van is deleted. |
| 9 | Start again right away | Cooldown message |
| 10 | Start a route, then `/canceldelivery` | Van removed, deposit kept |
| 11 | Start a route with less than $250 in the bank | "You need $250 in your bank..." |
| 12 | `restart qb-delivery` during a route | Van, prop and blips are cleaned up, no errors in F8 |
| 13 | `Config.RequireJob = true`, run `/setjob <id> unemployed 0` then try to start | "You are not employed as a courier." |

Check the server console and the **F8** client console for `SCRIPT ERROR`
lines at each step. With `Config.Debug = true`, the server also prints a line
for every start, drop, return and cancel.

### Troubleshooting

- **No marker or prompt**: make sure qb-core starts before qb-delivery and that
  you are on foot.
- **The van spawns inside something**: change `Config.Depot.vehicleSpawn`.
  Coordinates differ slightly with some MLOs (custom interiors).
- **"You are not at the drop-off point" while standing on the marker**: the
  ground height may differ on your map. Re-capture the coordinate with
  `/qbdelivery_coords`, or raise `Config.DropRadius`.
- **No keys for the van**: you are not using `qb-vehiclekeys`. Change the
  `vehiclekeys:client:SetOwner` line in `client/main.lua` to match your keys
  script.
- **`GetPlayerPed` returns 0 on the server**: OneSync is off. Turn it on in
  txAdmin → Settings → FXServer, or with `set onesync on`.

## File layout

```
qb-delivery/
├── fxmanifest.lua
├── config.lua
├── client/main.lua
├── server/main.lua
└── README.md
```

## License

MIT. Use and change it freely.
