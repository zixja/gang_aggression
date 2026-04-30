# 🔫 gang_aggression

**Lightweight standalone FiveM resource that makes gang NPCs react with real hostility when threatened.**

Bring street-level danger to life — when a player draws a weapon near a gang member, or aims directly at one, they'll snap into combat and call for backup. No more passive bystanders while you wave a gun in their face.

---

## 🎯 Features

- **Aim detection** — Point a weapon at a gang ped and they immediately fight back
- **Proximity aggression** — Walk too close while armed and trigger a reaction
- **Gang backup system** — Nearby peds join the fight when one is alerted, with a configurable cap
- **Combat lock** — Peds stay in fight mode and won't snap back to passive between ticks
- **Retask cooldown** — Prevents animation jitter and task-queue flooding
- **Territory zones** — Restrict aggression to specific map areas (enable in config)
- **Alliance system** — Mark gang groups as allied so backup only rallies for friends (enable in config)
- **State reset** — Clean slate on death, respawn, and character swap across all frameworks
- **Performance friendly** — Uses `FindFirstPed` iterator, skips all logic when the player is unarmed
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

The script auto-detects which framework is running at startup and hooks the correct death/load events automatically. You can also pin it manually in `config.lua`.

---

## 📦 Installation

1. Drop the `gang_aggression` folder into your server's `resources/` directory.

2. Add to your `server.cfg`:
   ```
   ensure gang_aggression
   ```

3. Restart your server, or run:
   ```
   refresh
   start gang_aggression
   ```

No SQL. No framework exports. No additional dependencies.

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

## 🔧 Configuration

Everything lives in `config.lua`. No other file needs to be touched.

### Core Settings

| Option | Default | Description |
|--------|---------|-------------|
| `Config.Framework` | `'auto'` | Framework to hook for state resets. `'auto'` detects at runtime. Options: `'qbcore'` `'qbox'` `'esx'` `'standalone'` |
| `Config.TickRate` | `750` | Main loop interval in ms. Lower = more responsive, slightly more CPU. |
| `Config.DetectionRadius` | `30.0` | Outer scan radius in metres. Peds beyond this are never iterated. |
| `Config.ProximityThreatRadius` | `10.0` | Inner radius in metres. Armed player within this range triggers aggression without needing to aim. |
| `Config.AggressOnWeaponDraw` | `true` | If `true`, drawing any weapon inside `ProximityThreatRadius` triggers aggression. If `false`, the player must aim directly at the ped. |

### Backup System

| Option | Default | Description |
|--------|---------|-------------|
| `Config.EnableBackup` | `true` | Nearby gang peds join the fight when one is alerted. |
| `Config.BackupRadius` | `25.0` | Radius in metres around the alerted ped that recruits backup. |
| `Config.MaxBackupPeds` | `4` | Max backup peds per engagement. `0` = unlimited. |

### Combat Behaviour

| Option | Default | Description |
|--------|---------|-------------|
| `Config.RetaskCooldown` | `8000` | Ms before an alerted ped can be re-tasked. Prevents animation jitter. |
| `Config.PedsChasePlayer` | `true` | Alerted peds chase the player if they flee. |
| `Config.PedsUseCover` | `true` | Alerted peds attempt to use cover during combat. |

---

### Territory Zones

Set `Config.EnableTerritories = true` and define zones in `Config.Territories`. When enabled, aggression only triggers inside those areas.

```lua
Config.EnableTerritories = true

Config.Territories = {
    { label = 'Chamberlain Hills', coords = vector3(-6.51, -1574.05, 29.29), radius = 200.0, gang = 'families' },
    { label = 'Strawberry',        coords = vector3(-222.56, -1716.58, 29.11), radius = 150.0, gang = 'ballas'  },
}
```

Each zone takes a `label`, a `coords` vector3, a `radius` in metres, and an optional `gang` string reserved for future per-gang filtering.

---

### Alliance System

Set `Config.EnableAlliances = true` and group gang names into alliance lists. Peds in the same group will rally as backup for each other, and will never be sent to attack an ally.

```lua
Config.EnableAlliances = true

Config.Alliances = {
    { 'vagos', 'marabunta' },  -- back each other up
}
```

When alliances are enabled, the backup system only recruits peds that share an alliance group with the primary alerted ped. Peds from different groups engage independently.

---

### Adding Custom Ped Models

Append model name strings to `Config.GangModels`:

```lua
Config.GangModels = {
    -- existing entries ...
    'my_custom_gang_ped_01',
    'my_custom_gang_ped_02',
}
```

All model names are hashed once at resource start — no runtime cost per tick.

---

## ⚡ Performance

The main thread runs every `Config.TickRate` ms and:

- **Exits immediately** if the player is unarmed — zero ped scanning cost
- Uses `FindFirstPed` / `FindNextPed` instead of `GetGamePool('CPed')`, avoiding a full Lua table allocation each tick
- Deduplicates `TaskCombatPed` calls via the `alertedPeds` table — each ped is only tasked once per `RetaskCooldown`
- Applies combat attributes only on the **first** alert, not on every retask
- Runs stale-entry cleanup every 15 seconds regardless of armed state

Increasing `TickRate` to `1000` reduces CPU usage further with minimal impact on reaction time.

---

## 🗺️ Planned Features

- **Wanted level integration** — Optionally apply a wanted level when a gang fight starts
- **Server-side kill logging** — Track gang kills for stats or server events
- **Blip support** — Show active gang fights on the minimap
- **Per-zone gang filtering** — Restrict territory zones to their assigned gang only

---

## 🐛 Bug Fixes (v3.0.0 vs. original)

| # | Bug | Fix |
|---|-----|-----|
| 1 | `GetEntityPlayerIsFreeAimingAt` incorrectly unpacked as `(bool, entity)` — returns **one** value. Aim detection silently never worked. | Called correctly; result validated as a single handle |
| 2 | `GetGamePool('CPed')` rebuilt a full Lua table every tick | Replaced with `FindFirstPed` / `FindNextPed` iterator |
| 3 | `TaskCombatPed` called every tick on the same ped with no deduplication | `alertedPeds` table + `RetaskCooldown` prevent spam |
| 4 | No combat attributes set — peds snapped back to passive between ticks | `SetPedCombatAttributes` + `SetPedFleeAttributes` lock them in fight mode |
| 5 | Only the directly threatened ped reacted; no backup | Configurable backup system with radius and per-engagement ped cap |
| 6 | No state reset on death/respawn/character swap — stale handles accumulated forever | `resetState()` hooked to all framework death and load events |
| 7 | `IsPedArmed(player, 4)` missed all firearms | Replaced with `IsPedArmed(ped, 6)` covering all weapon categories |
| 8 | `backupCount` was a global reset per-tick — backup cap was effectively broken when multiple peds were alerted in one tick | Replaced with a per-engagement `backupSlots` table scoped to each `alertWithBackup` call |
| 9 | Aimed ped double-alerted when also inside `ProximityThreatRadius` | Proximity scan now skips the already-handled aimed ped |
| 10 | `DetectionRadius` config value existed and was documented but never referenced in code | Now used as the outer `FindPed` iterator boundary; `ProximityThreatRadius` is the inner trigger threshold |
| 11 | Alliance system config existed but had zero implementation | Fully implemented — alliance lookup built at startup, backup recruitment gated by group membership |
| 12 | `IsPedInAnyVehicle` check excluded drive-by gang members and peds in parked cars | Removed — vehicle occupants are valid targets |
| 13 | `FindPed` handle could leak if callback threw a runtime error | Callback wrapped in `pcall`; handle always closed cleanly |
| 14 | Combat attributes re-applied on every retask, not just first alert | `setAggressiveCombatStyle` now called only when `alertedPeds[ped]` is nil |
| 15 | Stale `alertedPeds` cleanup skipped on unarmed ticks due to `goto` placement | Cleanup moved above the early-exit so it always runs |

---

## 📄 License

MIT — free to use, modify, and redistribute. Credit appreciated but not required.
