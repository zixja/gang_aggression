--[[
╔══════════════════════════════════════════════════════════════╗
║            gang_aggression — client/main.lua                 ║
║                    v3.0.0  (full rewrite)                    ║
║                                                              ║
║  Standalone. No framework imports required.                  ║
║  Compatible with: QBCore · QBox · ESX · Vanilla FiveM        ║
╚══════════════════════════════════════════════════════════════╝

  ARCHITECTURE
  ────────────
  The script is split into clearly separated layers:

    1.  Startup     — hash tables built once, framework detected
    2.  Predicates  — pure boolean checks (no side-effects)
    3.  Iterators   — thin wrappers over native ped-find APIs
    4.  Territories — zone membership test
    5.  Alliances   — ally relationship test
    6.  Combat      — ped attribute setup + task assignment
    7.  Engagement  — alertPed / alertWithBackup orchestration
    8.  Main loop   — tick, aim check, proximity check, cleanup
    9.  State reset — death / character-swap hooks

  PERFORMANCE NOTES
  ─────────────────
  • Early-exit if player is unarmed → zero ped iteration cost.
  • FindFirstPed/FindNextPed iterator avoids GetGamePool table alloc.
  • Model hashes pre-built at startup → O(1) gang membership check.
  • alertedPeds table deduplicates TaskCombatPed calls per ped.
  • Stale entry cleanup runs every 15 s on a lazy timer.
]]

-- ═══════════════════════════════════════════════════════════════
-- 1. STARTUP — hash tables
-- ═══════════════════════════════════════════════════════════════

-- gangHashes[modelHash] = true
local gangHashes = {}

-- allianceMap[modelHash] = groupId (integer index into Config.Alliances)
local allianceMap = {}

CreateThread(function()
    -- Build gang model hash set
    for _, modelName in ipairs(Config.GangModels) do
        gangHashes[GetHashKey(modelName)] = true
    end

    -- Build alliance lookup (only if the system is enabled)
    if Config.EnableAlliances then
        for groupId, members in ipairs(Config.Alliances) do
            for _, gangName in ipairs(members) do
                allianceMap[GetHashKey(gangName)] = groupId
            end
        end
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- 2. FRAMEWORK DETECTION
-- ═══════════════════════════════════════════════════════════════

local detectedFramework = nil

local function detectFramework()
    if Config.Framework ~= 'auto' then
        detectedFramework = Config.Framework
    elseif GetResourceState('qb-core')    == 'started' then
        detectedFramework = 'qbcore'
    elseif GetResourceState('qbx_core')   == 'started' then
        detectedFramework = 'qbox'
    elseif GetResourceState('es_extended') == 'started' then
        detectedFramework = 'esx'
    else
        detectedFramework = 'standalone'
    end
    print(('[gang_aggression] Framework: %s'):format(detectedFramework))
end

-- ═══════════════════════════════════════════════════════════════
-- 3. PREDICATES  (pure boolean helpers, no side-effects)
-- ═══════════════════════════════════════════════════════════════

--- True when ped's model is in the gang hash set.
local function isGangPed(ped)
    return gangHashes[GetEntityModel(ped)] == true
end

--- True when the ped has any weapon selected (not unarmed).
--- IsPedArmed(ped, 6) checks all weapon categories:
---   bit 0 = melee, bit 1 = lethal melee, bit 2 = firearm (6 = all three)
local function isArmed(ped)
    return IsPedArmed(ped, 6)
end

--- True when the ped is a valid, living, non-player ped we can task.
--- NOTE: we deliberately do NOT exclude vehicle occupants — gang members
--- in cars (drive-bys, parked) are valid threats.
local function pedIsAlive(ped)
    return DoesEntityExist(ped)
       and not IsPedAPlayer(ped)
       and not IsPedDeadOrDying(ped, true)
end

--- True when ped is a valid, living, non-player gang member.
local function isValidGangPed(ped)
    return pedIsAlive(ped) and isGangPed(ped)
end

-- ═══════════════════════════════════════════════════════════════
-- 4. ITERATOR — safe FindPed wrapper
-- ═══════════════════════════════════════════════════════════════

--- Iterates every ped within [radius] metres of [origin] that passes
--- [filterFn], and calls [callbackFn] on each one.
---
--- Guarantees EndFindPed is always called even if callbackFn errors,
--- preventing handle leaks. Errors inside callbacks are caught and
--- printed so one bad ped never breaks the whole loop.
---
--- @param origin     vector3
--- @param radius     number
--- @param filterFn   function(ped) → bool
--- @param callbackFn function(ped)
local function forEachPedInRadius(origin, radius, filterFn, callbackFn)
    local handle, ped = FindFirstPed()
    local found = true
    while found do
        if filterFn(ped) and #(origin - GetEntityCoords(ped)) <= radius then
            local ok, err = pcall(callbackFn, ped)
            if not ok then
                print(('[gang_aggression] Callback error: %s'):format(tostring(err)))
            end
        end
        found, ped = FindNextPed(handle)
    end
    EndFindPed(handle)
end

-- ═══════════════════════════════════════════════════════════════
-- 5. TERRITORIES
-- ═══════════════════════════════════════════════════════════════

--- Returns true if [coords] is inside any configured territory zone,
--- or if the territory system is disabled (everywhere is valid).
local function isInAnyTerritory(coords)
    if not Config.EnableTerritories then return true end
    for _, zone in ipairs(Config.Territories) do
        if #(coords - zone.coords) <= zone.radius then
            return true
        end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════
-- 6. ALLIANCES
-- ═══════════════════════════════════════════════════════════════

--- Returns true if [pedA] and [pedB] share the same alliance group.
--- Used to decide whether backup recruitment should include [candidate].
local function areAllied(pedA, pedB)
    if not Config.EnableAlliances then return false end
    local gA = allianceMap[GetEntityModel(pedA)]
    local gB = allianceMap[GetEntityModel(pedB)]
    return gA ~= nil and gA == gB
end

-- ═══════════════════════════════════════════════════════════════
-- 7. COMBAT — attributes and task assignment
-- ═══════════════════════════════════════════════════════════════

--- Applies aggressive combat attributes to a ped.
--- Called once the first time a ped is alerted (not on every retask).
local function setAggressiveCombatStyle(ped)
    -- Remove all flee tendencies
    SetPedFleeAttributes(ped, 0, false)

    -- Lock into fight mode permanently
    SetPedCombatAttributes(ped, 5,  true)   -- BF_AlwaysFight
    SetPedCombatAttributes(ped, 46, true)   -- BF_CanFightArmedPedsWhenNotArmed
    SetPedCombatAttributes(ped, 52, true)   -- BF_IgnoreTrafficWhenDriving
    SetPedCombatAttributes(ped, 2,  true)   -- BF_CanInvestigateDeadPeds

    if Config.PedsUseCover then
        SetPedCombatAttributes(ped, 3, true) -- BF_UseCover
    end

    SetPedCombatRange(ped, 2)               -- Far range
    SetPedCombatMovement(ped, Config.PedsChasePlayer and 2 or 1)
    --  2 = Charge / pursue,  1 = Stationary / hold position
end

-- ═══════════════════════════════════════════════════════════════
-- 8. ENGAGEMENT — alerting and backup orchestration
-- ═══════════════════════════════════════════════════════════════

-- alertedPeds[pedHandle] = gameTimer value when last alerted.
-- Survives between ticks. Cleared on death / character-swap.
local alertedPeds = {}

--- Attempts to alert a single ped to attack [target].
---
--- Respects the retask cooldown for already-alerted peds.
--- For backup peds, enforces the per-engagement backup cap via
--- the mutable [backupSlots] table: { used = N, cap = M }.
---
--- @param ped        entity  — ped to alert
--- @param target     entity  — who they should fight (the player)
--- @param isBackup   bool    — whether this is a backup recruit
--- @param backupSlots table  — { used = int, cap = int } shared per engagement
--- @return bool              — true if the ped was successfully alerted
local function alertPed(ped, target, isBackup, backupSlots)
    local now = GetGameTimer()

    -- Retask cooldown: skip if already fighting and cooldown not elapsed
    local lastAlert = alertedPeds[ped]
    if lastAlert and (now - lastAlert) < Config.RetaskCooldown then
        return false
    end

    -- Backup cap: reject if at limit
    if isBackup then
        if backupSlots.cap > 0 and backupSlots.used >= backupSlots.cap then
            return false
        end
        backupSlots.used = backupSlots.used + 1
    end

    -- First-time alert: apply combat attributes
    -- On retask (lastAlert ~= nil) attributes are already set, skip.
    if not lastAlert then
        setAggressiveCombatStyle(ped)
    end

    alertedPeds[ped] = now
    TaskCombatPed(ped, target, 0, 16)
    return true
end

--- Alerts [primaryPed] and then recruits eligible nearby peds as backup.
---
--- A ped is eligible for backup when:
---   • It exists, is alive, and is a gang member
---   • It is not the primary ped itself
---   • Alliance system: if enabled, backup ped must be allied with primaryPed
---     (peds from different gangs fight independently; only allies rally)
---   • Backup cap has not been reached for this engagement
---
--- The backupSlots table is freshly created per call, so caps are enforced
--- per-engagement rather than per-tick (fixing the original global counter bug).
---
--- @param primaryPed entity  — the ped the player directly threatened
--- @param playerPed  entity  — local player ped (combat target)
local function alertWithBackup(primaryPed, playerPed)
    -- Fresh cap counter per engagement — not a global, not a per-tick reset.
    local backupSlots = {
        used = 0,
        cap  = math.max(0, Config.MaxBackupPeds),
    }

    alertPed(primaryPed, playerPed, false, backupSlots)

    if not Config.EnableBackup then return end

    local origin = GetEntityCoords(primaryPed)

    forEachPedInRadius(origin, Config.BackupRadius, isValidGangPed, function(nearby)
        -- Skip the ped that triggered this engagement
        if nearby == primaryPed then return end

        -- Alliance gate: only allied peds rally to back up the primary.
        -- Non-allied gang peds will engage independently if they spot
        -- the player themselves (e.g. through proximity scan).
        if Config.EnableAlliances and not areAllied(nearby, primaryPed) then
            return
        end

        alertPed(nearby, playerPed, true, backupSlots)
    end)
end

-- ═══════════════════════════════════════════════════════════════
-- 9. MAIN LOOP
-- ═══════════════════════════════════════════════════════════════

local lastCleanup = 0

CreateThread(function()
    detectFramework()

    while true do
        Wait(Config.TickRate)

        -- ── Periodic stale-entry cleanup ──────────────────────
        -- Runs every 15 s regardless of armed state so dead / despawned
        -- peds don't accumulate forever in alertedPeds.
        local now    = GetGameTimer()
        local player = PlayerPedId()

        if now - lastCleanup > 15000 then
            lastCleanup = now
            for handle in pairs(alertedPeds) do
                if not DoesEntityExist(handle) or IsPedDeadOrDying(handle, true) then
                    alertedPeds[handle] = nil
                end
            end
        end

        -- ── Early exit: unarmed player ────────────────────────
        -- No ped scanning, no coordinates call — minimum possible cost.
        if not isArmed(player) then goto continue end

        local playerCoords = GetEntityCoords(player)

        -- ── Early exit: outside all territories ───────────────
        if not isInAnyTerritory(playerCoords) then goto continue end

        -- ── Aim check ─────────────────────────────────────────
        -- GetEntityPlayerIsFreeAimingAt returns ONE entity handle (not
        -- a bool + entity — that was the original bug). 0 means no target.
        local aimedEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
        local aimedIsGang = false

        if aimedEntity ~= 0
        and DoesEntityExist(aimedEntity)
        and not IsPedAPlayer(aimedEntity)
        and isGangPed(aimedEntity)
        and pedIsAlive(aimedEntity)
        then
            aimedIsGang = true
            alertWithBackup(aimedEntity, player)
        end

        -- ── Proximity check ───────────────────────────────────
        -- Uses DetectionRadius as the iterator boundary (outer cull), then
        -- checks ProximityThreatRadius as the actual aggression threshold.
        -- This keeps the FindPed loop tight while still ignoring distant peds.
        if Config.AggressOnWeaponDraw then
            forEachPedInRadius(playerCoords, Config.DetectionRadius, isValidGangPed, function(ped)
                -- Inner threshold: only react within ProximityThreatRadius
                if #(playerCoords - GetEntityCoords(ped)) > Config.ProximityThreatRadius then
                    return
                end
                -- Skip the aimed ped — already handled above.
                -- Without this guard, alertWithBackup would run twice on
                -- that ped: once from aim check, once from proximity scan.
                if aimedIsGang and ped == aimedEntity then return end

                alertWithBackup(ped, player)
            end)
        end

        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════
-- 10. STATE RESET — death, respawn, character swap
-- ═══════════════════════════════════════════════════════════════
-- Each framework fires different events. We hook all of them so the
-- correct one fires regardless of which framework is running.
-- Events from absent frameworks simply never fire — no harm done.

local function resetState()
    alertedPeds = {}
    print('[gang_aggression] State reset.')
end

-- Vanilla FiveM / shared
AddEventHandler('baseevents:onPlayerDied',                    resetState)

-- QBCore
AddEventHandler('QBCore:Client:OnPlayerLoaded',               resetState)
AddEventHandler('QBCore:Client:OnPlayerUnload',               resetState)

-- QBox
AddEventHandler('qb-multicharacter:client:onSelectCharacter', resetState)
AddEventHandler('qbx_core:playerLoggedOut',                   resetState)

-- ESX
AddEventHandler('esx:playerLoaded',                           resetState)
AddEventHandler('esx:onPlayerLogout',                         resetState)