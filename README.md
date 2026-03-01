# 🔫 gang_aggression

**Lightweight standalone FiveM resource that makes gang NPCs react with real hostility when threatened.**

Bring street-level danger to life — when a player draws a weapon near a gang member, or aims directly at one, they'll snap into combat and call for backup. No more passive bystanders while you wave a gun in their face.

---

## 🎯 Features

- **Aim detection** — Point a weapon at a gang ped and they'll immediately fight back
- **Proximity aggression** — Walk too close while armed and trigger a reaction
- **Gang backup system** — Nearby peds join the fight when one is alerted, with a configurable cap
- **Combat lock** — Peds stay in fight mode and won't snap back to passive between ticks
- **Retask cooldown** — Prevents animation jitter and task-queue flooding
- **Territory zones** — *(built-in scaffolding, enable in config)* Restrict aggression to defined map areas
- **Alliance system** — *(built-in scaffolding, enable in config)* Mark gang groups as allied so they don't fight each other
- **State reset** — Clean slate on death, respawn, and character swap across all frameworks
- **Performance friendly** — Uses `FindFirstPed` iterator instead of `GetGamePool`, skips all logic when player is unarmed
- **Zero server-side code** — Pure client script, zero network overhead
- **Fully configurable** — Tick rate, radii, backup cap, models, behaviour flags — all in `config.lua`

---

## ✅ Framework Compatibility

No framework code is imported. Works out of the box with everything.

| Framework | Status |
|-----------|:------:|
| Vanilla FiveM | ✅ |
| QBCore | ✅ |
| QBox | ✅ |
| ESX | ✅ |

The script auto-detects which framework is running at startup and hooks into the correct death/load events automatically. You can also pin it manually in `config.lua`.

---

## 📦 Installation

1. Drop the `gang_aggression` folder into your server's `resources/` directory.

2. Add the following line to your `server.cfg`:
   ```
   ensure gang_aggression
   ```

3. Restart your server, or run:
   ```
   refresh
   start gang_aggression
   ```

That's it. No SQL, no framework exports, no additional dependencies.

---

## 🔧 Configuration

Everything is in `config.lua`. No other file needs to be edited.

### Core Settings

| Option | Default | Description |
|--------|---------|-------------|
| `Config.Framework` | `'auto'` | Framework to hook for resets. `'auto'` detects at runtime. Options: `'qbcore'` `'qbox'` `'esx'` `'standalone'` |
| `Config.TickRate` | `750` | Main loop interval in ms. Lower = more responsive, slightly more CPU. |
| `Config.DetectionRadius` | `30.0` | Outer scan radius in metres. Peds beyond this are completely ignored. |
| `Config.ProximityThreatRadius` | `10.0` | Inner radius in metres. Armed player within this range triggers aggression. |
| `Config.AggressOnWeaponDraw` | `true` | If true, drawing any weapon near a gang ped triggers aggression. If false, only direct aiming does. |

### Backup System

| Option | Default | Description |
|--------|---------|-------------|
| `Config.EnableBackup` | `true` | Whether nearby gang peds join the fight when one is alerted. |
| `Config.BackupRadius` | `25.0` | Radius in metres around the alerted ped that pulls in backup. |
| `Config.MaxBackupPeds` | `4` | Max number of backup peds per engagement. Set to `0` for unlimited. |

### Combat Behaviour

| Option | Default | Description |
|--------|---------|-------------|
| `Config.RetaskCooldown` | `8000` | Ms before an alerted ped can be re-tasked. Prevents jitter. |
| `Config.PedsChasePlayer` | `true` | Whether alerted peds chase the player if they flee. |
| `Config.PedsUseCover` | `true` | Whether alerted peds attempt to take cover during combat. |

### Territory Zones *(scaffolding — enable when ready)*

Set `Config.EnableTerritories = true` and define zones in `Config.Territories`. When enabled, aggression only triggers inside defined areas. Each zone takes a label, optional gang name, `coords` vector3, and a `radius`.

```lua
Config.EnableTerritories = true

Config.Territories = {
    { label = 'Chamberlain Hills', gang = 'families', coords = vector3(-6.51, -1574.05, 29.29), radius = 200.0 },
    { label = 'Strawberry',        gang = 'ballas',   coords = vector3(-222.56, -1716.58, 29.11), radius = 150.0 },
}
```

### Alliance System *(scaffolding — enable when ready)*

Set `Config.EnableAlliances = true` and group gang names into alliance lists. Peds in the same group won't target each other.

```lua
Config.EnableAlliances = true

Config.Alliances = {
    { 'vagos', 'marabunta' },   -- these two are allies
}
```

### Adding Custom Ped Models

Append model name strings to `Config.GangModels`:

```lua
Config.GangModels = {
    -- existing entries...
    'my_custom_gang_ped_01',
    'my_custom_gang_ped_02',
}
```

---

## 📁 File Structure

```
gang_aggression/
├── fxmanifest.lua
├── config.lua
└── client/
    └── main.lua
```

---

## ⚡ Performance Notes

The main thread runs every `Config.TickRate` ms and:

- **Exits immediately** if the player is unarmed — no ped scanning at all
- Uses `FindFirstPed` / `FindNextPed` instead of `GetGamePool('CPed')`, avoiding a full Lua table allocation each tick
- Tracks alerted peds so `TaskCombatPed` is only called once per ped (plus optional retask)
- Cleans up stale entries every 15 seconds

Increasing `TickRate` to `1000` reduces CPU further with minimal difference to reaction time.

---

## 🗺️ Planned / DIY Features

- **Territory aggression** — Scaffolding is already in the config. Define zones and set `EnableTerritories = true`.
- **Alliance system** — Scaffolding is already in the config. Define ally groups and set `EnableAlliances = true`.
- **Wanted level integration** — Optionally apply a wanted level when a gang fight starts.
- **Server-side kill logging** — Track gang kills for stats or events.
- **Blip support** — Show active gang fights on the minimap.

---

## 🐛 Bug Fixes

For transparency, here are the issues that were present in the original generated script and what was done to fix them:

| # | Original Bug | Fix |
|---|-------------|-----|
| 1 | `GetEntityPlayerIsFreeAimingAt` unpacked as `(bool, entity)` — it returns **one** value. Aim detection silently never worked. | Called correctly; result validated separately |
| 2 | `GetGamePool('CPed')` rebuilt a full Lua table every tick causing micro-stutters | Replaced with `FindFirstPed` / `FindNextPed` iterator |
| 3 | `TaskCombatPed` called every 1 000 ms on the same ped with no dedup or cooldown | `alertedPeds` table + `RetaskCooldown` prevent spam |
| 4 | No combat attributes set — peds snapped back to passive behaviour between ticks | `SetPedCombatAttributes` + `SetPedFleeAttributes` lock them in fight mode |
| 5 | Only the directly threatened ped reacted; no backup | Configurable backup system with radius and ped cap |
| 6 | No state reset on death, respawn, or character swap — stale handles accumulated indefinitely | `resetState()` hooked to all framework death/load events |
| 7 | `IsPedArmed(player, 4)` only detected lethal melee — missed all firearms | Replaced with `GetSelectedPedWeapon` vs `WEAPON_UNARMED` hash |

---

## 📄 License

MIT — free to use, modify, and redistribute. Credit appreciated but not required.
