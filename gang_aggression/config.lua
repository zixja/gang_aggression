--[[
╔══════════════════════════════════════════════════════════════╗
║              gang_aggression — config.lua                    ║
║   All settings live here. No other file needs to be edited.  ║
╚══════════════════════════════════════════════════════════════╝
]]

Config = {}

-- ─────────────────────────────────────────────────────────────
-- FRAMEWORK
-- ─────────────────────────────────────────────────────────────
-- 'auto'       → detected at runtime (recommended)
-- 'qbcore'     → QBCore
-- 'qbox'       → QBox
-- 'esx'        → ESX
-- 'standalone' → vanilla FiveM / no framework
Config.Framework = 'auto'

-- ─────────────────────────────────────────────────────────────
-- PERFORMANCE
-- ─────────────────────────────────────────────────────────────

-- Main loop interval in milliseconds.
-- 500  = very responsive, slightly higher CPU usage
-- 750  = recommended balance (default)
-- 1000 = lowest CPU, minor delay in reaction
Config.TickRate = 750

-- ─────────────────────────────────────────────────────────────
-- DETECTION
-- ─────────────────────────────────────────────────────────────

-- Outer scan radius (metres). Gang peds beyond this distance are never
-- iterated. Must be >= ProximityThreatRadius.
Config.DetectionRadius = 30.0

-- Inner threat radius (metres). An armed player within this distance of a
-- gang ped triggers aggression even without aiming. Must be <= DetectionRadius.
Config.ProximityThreatRadius = 10.0

-- If true, drawing any weapon inside ProximityThreatRadius is enough to
-- trigger aggression. If false, the player must aim directly at the ped.
Config.AggressOnWeaponDraw = true

-- ─────────────────────────────────────────────────────────────
-- BACKUP SYSTEM
-- ─────────────────────────────────────────────────────────────

-- Nearby gang peds join the fight when one of them is alerted.
Config.EnableBackup = true

-- Radius (metres) around the first alerted ped that recruits backup.
Config.BackupRadius = 25.0

-- Max backup peds per engagement. 0 = unlimited. Negatives treated as 0.
Config.MaxBackupPeds = 4

-- ─────────────────────────────────────────────────────────────
-- COMBAT BEHAVIOUR
-- ─────────────────────────────────────────────────────────────

-- Milliseconds before an alerted ped can be re-tasked.
-- Prevents TaskCombatPed spam and animation jitter.
Config.RetaskCooldown = 8000

-- Alerted peds will chase the player if they flee.
Config.PedsChasePlayer = true

-- Alerted peds will attempt to use cover during combat.
Config.PedsUseCover = true

-- ─────────────────────────────────────────────────────────────
-- TERRITORY ZONES
-- ─────────────────────────────────────────────────────────────
-- When enabled, aggression only triggers inside defined map zones.
--
-- Zone fields:
--   label  (string)  — name shown in debug output
--   coords (vector3) — centre point of the zone
--   radius (float)   — zone radius in metres
--   gang   (string)  — optional, reserved for future per-gang filtering

Config.EnableTerritories = false

Config.Territories = {
    -- { label = 'Chamberlain Hills', coords = vector3(-6.51,   -1574.05, 29.29), radius = 200.0, gang = 'families' },
    -- { label = 'Strawberry',        coords = vector3(-222.56, -1716.58, 29.11), radius = 150.0, gang = 'ballas'   },
}

-- ─────────────────────────────────────────────────────────────
-- ALLIANCE SYSTEM
-- ─────────────────────────────────────────────────────────────
-- Peds in the same alliance group will call backup for each other,
-- and backup recruitment will NOT send them against their own allies.
--
-- Each entry is a table of gang name strings. Names must match the
-- model name prefix used in GangModels (e.g. 'vagos' for 'g_m_y_vagos_01').
-- The alliance group index is hashed at startup — no runtime cost.

Config.EnableAlliances = false

Config.Alliances = {
    -- { 'vagos', 'marabunta' },  -- these two back each other up
    -- { 'families' },            -- fights alone
}

-- ─────────────────────────────────────────────────────────────
-- GANG PED MODELS
-- ─────────────────────────────────────────────────────────────
-- Model name strings are hashed once at startup for O(1) lookups.
-- Add any custom ped model names at the bottom of this list.

Config.GangModels = {
    -- ── Ballas ───────────────────────────────────────────────
    'g_m_y_ballaorig_01',
    'g_m_y_ballaeast_01',
    'g_m_y_ballasout_01',

    -- ── Families ─────────────────────────────────────────────
    'g_m_y_famca_01',
    'g_m_y_famdnf_01',
    'g_m_y_famfor_01',

    -- ── Lost MC ──────────────────────────────────────────────
    'g_m_y_lost_01',
    'g_m_y_lost_02',
    'g_m_y_lost_03',

    -- ── Vagos / Marabunta Grande ─────────────────────────────
    'g_m_y_mexgoon_01',
    'g_m_y_mexgoon_02',
    'g_m_y_mexgoon_03',
    'g_m_y_mexgang_01',

    -- ── Aztecas ──────────────────────────────────────────────
    'g_m_y_azteca_01',

    -- ── Korean Mob ───────────────────────────────────────────
    'g_m_m_korboss_01',
    'g_m_y_korean_01',
    'g_m_y_korean_02',
    'g_m_y_korlieut_01',

    -- ── Chinese Mob ──────────────────────────────────────────
    'g_m_m_chiboss_01',
    'g_m_y_chicrow_01',
    'g_m_y_chinese1_01',
    'g_m_y_chinese2_01',

    -- ── Generic Street Gangs ─────────────────────────────────
    'g_m_y_hood_01',
    'g_m_y_pologang_01',
    'g_m_y_pologang_02',

    -- ── Custom models ─────────────────────────────────────────
    -- 'my_custom_gang_ped_01',
    -- 'my_custom_gang_ped_02',
}