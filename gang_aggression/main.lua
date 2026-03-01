--[[
╔══════════════════════════════════════════════════════════════╗
║            gang_aggression — client/main.lua                 ║
║                                                              ║
║  Standalone. No framework imports required.                  ║
║  Compatible with: QBCore · QBox · ESX · Vanilla FiveM        ║
╚══════════════════════════════════════════════════════════════╝

  HOW IT WORKS
  ────────────
  Every Config.TickRate ms the script:
    1. Skips all logic if the player is unarmed (zero cost).
    2. Checks if the player is free-aiming at a gang ped.
    3. Scans for gang peds within ProximityThreatRadius.
    4. Alerts any threatened peds and pulls in backup.

  Alerted peds are tracked in a table so TaskCombatPed is only
  called once per ped (+ optionally on a cooldown retask),
  preventing animation jitter and task-queue flooding.
]]

-- ──────────────────────────────────────────────────────────────
-- Constants & startup hashing
-- ──────────────────────────────────────────────────────────────

local UNARMED_HASH <const> = GetHashKey('WEAPON_UNARMED')

-- Pre-hash all gang models at resource start for O(1) lookups.
local gangHashes = {}
CreateThread(function()
    for _, name in ipairs(Config.GangModels) do
        gangHashes[GetHashKey(name)] = true
    end
end)

-- ──────────────────────────────────────────────────────────────
-- Framework detection
-- ──────────────────────────────────────────────────────────────

local Framework = nil

local function detectFramework()
    if Config.Framework ~= 'auto' then
        Framework = Config.Framework
        return
    end
    if GetResourceState('qb-core') == 'started' then
        Framework = 'qbcore'
    elseif GetResourceState('qbx_core') == 'started' then
        Framework = 'qbox'
    elseif GetResourceState('es_extended') == 'started' then
        Framework = 'esx'
    else
        Framework = 'standalone'
    end
    print(('[gang_aggression] Framework detected: %s'):format(Framework))
end

-- ──────────────────────────────────────────────────────────────
-- State
-- ──────────────────────────────────────────────────────────────

-- alertedPeds[handle] = GetGameTimer() timestamp of when they were alerted.
local alertedPeds  = {}
local backupCount  = 0          -- tracks peds added as backup this engagement
local lastCleanup  = 0

-- ──────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────

local function isGangPed(ped)
    return gangHashes[GetEntityModel(ped)] == true
end

local function isArmed(ped)
    -- Checks the currently selected weapon — covers all firearms and melee.
    return GetSelectedPedWeapon(ped) ~= UNARMED_HASH
end

local function pedIsValid(ped)
    return DoesEntityExist(ped)
        and not IsPedAPlayer(ped)
        and not IsPedDeadOrDying(ped, true)
        and not IsPedInAnyVehicle(ped, false)
end

-- Iterate nearby gang peds efficiently using the FindPed native iterator.
-- Avoids GetGamePool('CPed') which allocates a full Lua table every call.
local function forEachNearbyGangPed(origin, radius, fn)
    local handle, ped = FindFirstPed()
    local found = true
    while found do
        if pedIsValid(ped) and isGangPed(ped) then
            if #(origin - GetEntityCoords(ped)) <= radius then
                fn(ped)
            end
        end
        found, ped = FindNextPed(handle)
    end
    EndFindPed(handle)
end

-- ──────────────────────────────────────────────────────────────
-- Territory check  (only runs if Config.EnableTerritories = true)
-- ──────────────────────────────────────────────────────────────

local function isInTerritory(coords)
    if not Config.EnableTerritories then return true end  -- no zones = everywhere
    for _, zone in ipairs(Config.Territories) do
        if #(coords - zone.coords) <= zone.radius then
            return true
        end
    end
    return false
end

-- ──────────────────────────────────────────────────────────────
-- Core aggression logic
-- ──────────────────────────────────────────────────────────────

local function applyAggressiveBehaviour(ped)
    -- Disable all flee behaviour
    SetPedFleeAttributes(ped, 0, false)

    -- Combat attributes
    SetPedCombatAttributes(ped, 5,  true)   -- BF_AlwaysFight
    SetPedCombatAttributes(ped, 46, true)   -- BF_CanFightArmedPedsWhenNotArmed
    SetPedCombatAttributes(ped, 52, true)   -- BF_IgnoreTrafficWhenDriving
    SetPedCombatAttributes(ped, 2,  true)   -- BF_CanInvestigateDeadPeds (stays engaged)

    if Config.PedsUseCover then
        SetPedCombatAttributes(ped, 3, true)  -- BF_UseCover
    end

    SetPedCombatRange(ped, 2)               -- Far combat range
    SetPedCombatMovement(ped,
        Config.PedsChasePlayer and 2 or 1)  -- 2 = Charge, 1 = Stationary
end

local function alertPed(ped, playerPed, isBackup)
    -- Check retask cooldown for already-alerted peds
    if alertedPeds[ped] then
        if (GetGameTimer() - alertedPeds[ped]) < Config.RetaskCooldown then
            return
        end
    end

    -- Backup cap
    if isBackup then
        if Config.MaxBackupPeds > 0 and backupCount >= Config.MaxBackupPeds then
            return
        end
        backupCount = backupCount + 1
    end

    alertedPeds[ped] = GetGameTimer()
    applyAggressiveBehaviour(ped)
    TaskCombatPed(ped, playerPed, 0, 16)
end

local function alertWithBackup(ped, playerPed)
    alertPed(ped, playerPed, false)

    if not Config.EnableBackup then return end

    local pedCoords = GetEntityCoords(ped)
    forEachNearbyGangPed(pedCoords, Config.BackupRadius, function(nearby)
        if nearby ~= ped then
            alertPed(nearby, playerPed, true)
        end
    end)
end

-- ──────────────────────────────────────────────────────────────
-- Main threat loop
-- ──────────────────────────────────────────────────────────────

CreateThread(function()
    detectFramework()

    while true do
        Wait(Config.TickRate)

        local playerPed = PlayerPedId()

        -- Early exit if player is unarmed — no scanning needed at all
        if not isArmed(playerPed) then goto continue end

        local playerCoords = GetEntityCoords(playerPed)

        -- Skip if territory system is on and player isn't in a zone
        if not isInTerritory(playerCoords) then goto continue end

        -- Reset per-tick backup counter
        backupCount = 0

        -- ── 1. Aim check ───────────────────────────────────────
        -- GetEntityPlayerIsFreeAimingAt returns a single entity handle.
        -- (Bug in original: it was incorrectly unpacked as two return values.)
        local aimedEntity = GetEntityPlayerIsFreeAimingAt(PlayerId())
        if aimedEntity ~= 0
        and DoesEntityExist(aimedEntity)
        and not IsPedAPlayer(aimedEntity)
        and isGangPed(aimedEntity)
        and pedIsValid(aimedEntity)
        then
            alertWithBackup(aimedEntity, playerPed)
        end

        -- ── 2. Proximity check ─────────────────────────────────
        if Config.AggressOnWeaponDraw then
            forEachNearbyGangPed(playerCoords, Config.ProximityThreatRadius, function(ped)
                alertWithBackup(ped, playerPed)
            end)
        end

        ::continue::

        -- ── Periodic cleanup of stale entries ──────────────────
        local now = GetGameTimer()
        if now - lastCleanup > 15000 then
            lastCleanup = now
            for handle in pairs(alertedPeds) do
                if not DoesEntityExist(handle) or IsPedDeadOrDying(handle, true) then
                    alertedPeds[handle] = nil
                end
            end
        end
    end
end)

-- ──────────────────────────────────────────────────────────────
-- State reset on death / character load
-- Hooks for every supported framework fire here.
-- If a framework isn't running, its events simply never fire.
-- ──────────────────────────────────────────────────────────────

local function resetState()
    alertedPeds = {}
    backupCount = 0
end

-- Vanilla / shared
AddEventHandler('baseevents:onPlayerDied',    resetState)

-- QBCore
AddEventHandler('QBCore:Client:OnPlayerLoaded',  resetState)
AddEventHandler('QBCore:Client:OnPlayerUnload',  resetState)

-- QBox
AddEventHandler('qb-multicharacter:client:onSelectCharacter', resetState)
AddEventHandler('qbx_core:playerLoggedOut',  resetState)

-- ESX
AddEventHandler('esx:playerLoaded',          resetState)
AddEventHandler('esx:onPlayerLogout',        resetState)
