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
-- Determines which framework events to hook for death/load resets.
-- Options: 'auto' | 'qbcore' | 'qbox' | 'esx' | 'standalone'
-- 'auto' will detect whichever framework is running at runtime.
Config.Framework = 'auto'

-- ─────────────────────────────────────────────────────────────
-- PERFORMANCE
-- ─────────────────────────────────────────────────────────────

-- How often (ms) the main threat loop runs.
-- 500  = very responsive, slightly more CPU
-- 750  = recommended balance  ← default
-- 1000 = light on CPU, small delay in reaction
Config.TickRate = 750

-- ─────────────────────────────────────────────────────────────
-- DETECTION
-- ─────────────────────────────────────────────────────────────

-- Outer radius (metres). Peds beyond this distance are completely ignored.
Config.DetectionRadius = 30.0

-- Inner radius (metres). An armed player within this range of a gang ped
-- triggers proximity aggression, even without aiming at them.
Config.ProximityThreatRadius = 10.0

-- If true, drawing a weapon alone (without aiming) inside ProximityThreatRadius
-- is enough to trigger aggression. If false, the player must aim at the ped.
Config.AggressOnWeaponDraw = true

-- ─────────────────────────────────────────────────────────────
-- BACKUP SYSTEM
-- ─────────────────────────────────────────────────────────────

-- When a ped is alerted, should nearby gang peds also join the fight?
Config.EnableBackup = true

-- Radius (metres) around the first alerted ped that pulls in backup members.
Config.BackupRadius = 25.0

-- Maximum number of backup peds that will join any single engagement.
-- Set to 0 for unlimited.
Config.MaxBackupPeds = 4

-- ─────────────────────────────────────────────────────────────
-- COMBAT BEHAVIOUR
-- ─────────────────────────────────────────────────────────────

-- Milliseconds before an already-alerted ped can be re-tasked.
-- Prevents TaskCombatPed spam and animation jitter.
Config.RetaskCooldown = 8000

-- If true, alerted peds will chase the player if they try to flee.
Config.PedsChasePlayer = true

-- If true, alerted peds will attempt to take cover during combat.
Config.PedsUseCover = true

-- ─────────────────────────────────────────────────────────────
-- TERRITORY ZONES  (future / DIY)
-- ─────────────────────────────────────────────────────────────
-- Set Config.EnableTerritories = true and define zones below to
-- restrict aggression to specific map areas.
-- Each zone: { label, gang (optional), coords {x,y,z}, radius }

Config.EnableTerritories = false

Config.Territories = {
    -- Example — Chamberlain Hills (Families turf)
    -- { label = 'Chamberlain Hills', gang = 'families', coords = vector3(-6.51, -1574.05, 29.29), radius = 200.0 },

    -- Example — Strawberry (Ballas turf)
    -- { label = 'Strawberry', gang = 'ballas', coords = vector3(-222.56, -1716.58, 29.11), radius = 150.0 },
}

-- ─────────────────────────────────────────────────────────────
-- ALLIANCE SYSTEM  (future / DIY)
-- ─────────────────────────────────────────────────────────────
-- Gang peds in the same alliance group will NOT attack each other.
-- Assign gang names to groups — peds in the same group are allies.

Config.EnableAlliances = false

Config.Alliances = {
    -- Example: Vagos and Marabunta are allied
    -- { 'vagos', 'marabunta' },

    -- Example: Families and Ballas are NOT allied (leave in separate groups or omit)
}

-- ─────────────────────────────────────────────────────────────
-- GANG PED MODELS
-- Add or remove any GTA ped model names you want treated as gang members.
-- The script converts strings to hashes at startup — no runtime cost.
-- ─────────────────────────────────────────────────────────────

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

    -- ── Vagos / Marabunta Grande ──────────────────────────────
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

    -- ── Add custom server ped models below ───────────────────
    -- 'my_custom_gang_ped_01',
    -- 'my_custom_gang_ped_02',
}
