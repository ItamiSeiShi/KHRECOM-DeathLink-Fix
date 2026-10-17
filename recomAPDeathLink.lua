LUAGUI_NAME = "recomAPDeathLink"
LUAGUI_AUTH = "Local DeathLink repair"
LUAGUI_DESC = "DeathLink receive; send natural deaths on Continue"

-- Steam build: native defeat entry 1F17F0, controller request 210DC0.
-- The controller request was verified live on 2026-10-17. No executable writes.
local actor_address = 0x87B390
local save_address = 0x87CBF8
local time_address = 0x87B0E0
local enabled = false
local bridge_path
local death_latched = false
local suppress_retry = false
local actor_gap_started
local last_incoming = 0
local pending_confirmation
local error_reported = false

local function pointer(address, absolute)
    local value = GetPointer(address, 0, absolute or false)
    if value == nil or value < 0x10000 then return nil end
    return value
end

local function read_file(name)
    local file = io.open(bridge_path .. name, "r")
    if file == nil then return nil end
    local value = file:read("*a")
    file:close()
    return value
end

local function subscribed()
    local value = read_file("dlstate.cfg")
    if value == nil then return false end
    local flag, timestamp = value:match("^(%d+)%s+(%d+)")
    timestamp = tonumber(timestamp)
    local now = os.time()
    return flag == "1" and timestamp ~= nil and now >= timestamp and now - timestamp <= 5
end

local function state()
    local actor = pointer(actor_address)
    if actor == nil then return nil, "actor_gap" end
    local save = pointer(save_address)
    local root = pointer(time_address)
    if save == nil or root == nil then return nil end
    local timer = pointer(root + 8, true)
    if timer == nil or ReadInt(timer + 0x300, true) <= 5 then return nil end
    local health = ReadInt(actor + 0x42C, true)
    local maximum = ReadInt(actor + 0x430, true)
    local mode = ReadInt(actor + 0x390, true)
    if maximum <= 0 or maximum > 560 or health < 0 or health > maximum then return nil end
    if maximum ~= ReadInt(save + 4, true) then return nil end
    if ReadInt(actor + 0x444, true) ~= ReadInt(save + 0x1C, true) then return nil end
    if mode ~= 0 and mode ~= 1 then return nil end
    return {actor = actor, health = health, mode = mode,
            action = ReadInt(actor + 0x40C, true),
            substate = ReadInt(actor + 0x414, true),
            defeated = ReadInt(actor + 0x7B0, true) ~= 0}
end

local function bit_set(value, bit)
    return math.floor(value / bit) % 2 == 1
end

local function set_bit(value, bit, on)
    if on and not bit_set(value, bit) then return value + bit end
    if not on and bit_set(value, bit) then return value - bit end
    return value
end

local function controller(current)
    local value = pointer(current.actor + 0x3B8, true)
    if value == nil then return nil end
    -- Verified vtables differ by 0x1F80 on this build; comparison survives ASLR.
    local actor_vtable = pointer(current.actor, true)
    local controller_vtable = pointer(value, true)
    if actor_vtable == nil or controller_vtable == nil or actor_vtable - controller_vtable ~= 0x1F80 then return nil end
    local primary = pointer(value + 0x60, true)
    local secondary = pointer(value + 0x68, true)
    if primary ~= current.actor and secondary ~= current.actor then return nil end
    if ReadInt(value + 0x8C, true) ~= 0 then return nil end
    return value, secondary == current.actor
end

local function request_defeat(current, value, secondary)
    -- Same scalar writes as the successful paused-combat controller test.
    local flags = set_bit(ReadInt(value + 0x88, true), 4, true)
    flags = set_bit(flags, 8, not bit_set(ReadInt(current.actor + 0x420, true), 0x20000))
    flags = set_bit(flags, 0x400, secondary)
    WriteInt(current.actor + 0x42C, 0, true)
    WriteInt(current.actor + 0x7B0, 1, true)
    WriteInt(current.actor + 0x408, current.action, true)
    WriteInt(current.actor + 0x410, 0, true)
    WriteInt(current.actor + 0x414, 0, true)
    local actor_flags = set_bit(ReadInt(current.actor + 0x418, true), 1, true)
    actor_flags = set_bit(actor_flags, 0x1000, true)
    WriteInt(current.actor + 0x418, actor_flags, true)
    WriteInt(current.actor + 0x424, set_bit(ReadInt(current.actor + 0x424, true), 0x10000, false), true)
    WriteInt(current.actor + 0x428, set_bit(ReadInt(current.actor + 0x428, true), 8, false), true)
    WriteInt(current.actor + 0x7B4, 1, true)
    WriteInt(current.actor + 0x40C, 29, true)
    WriteInt(value + 0x88, flags, true)
    WriteInt(value + 0x90, 50, true)
    WriteInt(value + 0x8C, 7, true) -- Publish the request last.
end

local function send_retry()
    local file = io.open(bridge_path .. "dlsend" .. os.date("!%Y%m%d%H%M%S"), "w")
    if file == nil then return false end
    file:close()
    ConsolePrint("DeathLink: Continue selected; sending Sora's death")
    return true
end

local function acknowledge(timestamp)
    -- A newer incoming event may have replaced the single bridge marker.
    if tonumber(read_file("dlreceive")) == timestamp then os.remove(bridge_path .. "dlreceive") end
end

local function reset_latch()
    death_latched = false
    suppress_retry = false
    actor_gap_started = nil
    pending_confirmation = nil
end

local function tick()
    if not subscribed() then
        death_latched = false
        actor_gap_started = nil
        -- Retain linked-death suppression if DeathLink is toggled while dead.
        if suppress_retry then
            local current = state()
            if current ~= nil and not current.defeated and current.action ~= 29 then reset_latch() end
        end
        return
    end
    local current, missing_reason = state()
    if current == nil then
        if (death_latched or suppress_retry) and missing_reason == "actor_gap" then
            actor_gap_started = actor_gap_started or os.time()
            if os.time() - actor_gap_started <= 2 then return end
        end
        reset_latch()
        return
    end
    if actor_gap_started ~= nil and os.time() - actor_gap_started > 2 then reset_latch() end
    actor_gap_started = nil

    if current.defeated and current.action == 29 and current.substate == 1 then
        death_latched = true
        if pending_confirmation ~= nil then
            acknowledge(pending_confirmation)
            pending_confirmation = nil
            ConsolePrint("DeathLink: incoming death confirmed at game over")
        end
    elseif death_latched and not current.defeated and current.health > 0 and current.action ~= 29 then
        if suppress_retry then
            ConsolePrint("DeathLink: linked death completed; outgoing echo suppressed")
            reset_latch()
        elseif send_retry() then
            reset_latch()
        end
    end

    local text = read_file("dlreceive")
    if text == nil then return end
    local timestamp = tonumber(text)
    if timestamp == nil or timestamp ~= timestamp or timestamp == math.huge or timestamp == -math.huge or timestamp <= 0 then
        os.remove(bridge_path .. "dlreceive")
        ConsolePrint("DeathLink: ignored invalid incoming marker")
        return
    end
    if timestamp <= last_incoming then
        if timestamp ~= pending_confirmation then acknowledge(timestamp) end
        return
    end
    local age = os.time() - timestamp
    if age > 120 or age < -5 then
        acknowledge(timestamp)
        ConsolePrint("DeathLink: ignored expired or future incoming marker")
        return
    end
    if current.defeated or current.action == 29 then
        last_incoming = timestamp
        acknowledge(timestamp)
        return
    end
    -- Queue during cutscenes, initialization and busy controller transitions.
    if current.health <= 0 or suppress_retry then return end
    if current.action ~= 2 and current.action ~= 3 and current.action ~= 4 and current.action ~= 12 then return end
    local value, secondary = controller(current)
    if value == nil then return end
    suppress_retry = true
    pending_confirmation = timestamp
    last_incoming = timestamp
    request_defeat(current, value, secondary)
    ConsolePrint("DeathLink: incoming death requested through the game-over controller")
end

function _OnInit()
    enabled = GAME_ID == 0x9E3134F5 and ENGINE_TYPE == "BACKEND"
        and ReadByte(0x4E7040) == 15 and ReadByte(0x4E6DC0) == 77
    local local_app_data = os.getenv("LOCALAPPDATA")
    if local_app_data == nil then enabled = false end
    if enabled then
        bridge_path = local_app_data .. "\\KHRECOM\\"
        ConsolePrint("DeathLink: Steam bridge loaded; receive enabled; natural deaths send on Continue")
    else
        ConsolePrint("DeathLink: unsupported game/build; bridge disabled")
    end
end

function _OnFrame()
    if not enabled then return end
    local ok, message = pcall(tick)
    if not ok and not error_reported then
        ConsolePrint("DeathLink: bridge error: " .. tostring(message))
        error_reported = true
    elseif ok then
        error_reported = false
    end
end
