LUAGUI_NAME = "recomAP"
LUAGUI_AUTH = "Gicu"
LUAGUI_DESC = "RE: Chain of Memories AP Integration"

game_version = 1 --1 for EGS 2 for Steam

if os.getenv('LOCALAPPDATA') ~= nil then
    client_communication_path = os.getenv('LOCALAPPDATA') .. "\\KHRECOM\\"
else
    client_communication_path = os.getenv('HOME') .. "/KHRECOM/"
    ok, err, code = os.rename(client_communication_path, client_communication_path)
    if not ok and code ~= 13 then
        os.execute("mkdir " .. path)
    end
end

function decimalToHex(num)
    if num == 0 then
        return '0'
    end
    local neg = false
    if num < 0 then
        neg = true
        num = num * -1
    end
    local hexstr = "0123456789ABCDEF"
    local result = ""
    while num > 0 do
        local n = math.fmod(num, 16)
        result = string.sub(hexstr, n + 1, n + 1) .. result
        num = math.floor(num / 16)
    end
    if neg then
        result = '-' .. result
    end
    return result
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, tonumber(str))
    end
    return t
end

function toBits(num)
    -- returns a table of bits, least significant first.
    local t={} -- will contain the bits
    while num>0 do
        rest=math.fmod(num,2)
        t[#t+1]=rest
        num=(num-rest)/2
    end
    return t
end

function slurp(path)
    local f = io.open(path)
    local s = f:read("*a")
    f:close()
    return s
end

world_order = {2,3,4,5,6,7,8,9,10}
attack_power = 10
canExecute = false
frame_count = 1
card_set_data = {{0,1,2,3,4,5,6,7,8,9},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{},{}}
card_set_data_reset_value = 2
card_set_data_read = false
card_set_data_fixed = false
item_index = 0
battle_cards_array = {}
enemy_cards_array = {}
world_assignment_array = {}
gold_map_cards_array = {}
key_to_rewards_found = {}
friends_array = {}
sleights_array = {}
card_sets_received = {}
friend_count = 0
victory = false

function get_journal_array()
    journal_pointer_address = {0x87C608, 0x87CC08}
    journal_pointer_offset = 0x11B
    journal_pointer = GetPointer(journal_pointer_address[game_version], journal_pointer_offset)
    return ReadArray(journal_pointer, 108, true)
end

function get_heartless_array()
    journal_heartless_pointer_address = {0x87C608, 0x87CC08}
    journal_heartless_pointer_offset = 0x1F4
    journal_heartless_pointer = GetPointer(journal_heartless_pointer_address[game_version], journal_heartless_pointer_offset)
    return ReadArray(journal_heartless_pointer, 62, true)
end

function get_room_array()
    room_array_pointer_address = {0x87C598, 0x87CB98}
    room_array_pointer_offset = 0x18
    room_array_pointer = GetPointer(room_array_pointer_address[game_version], room_array_pointer_offset)
    room_array = ReadArray(room_array_pointer, 39, true)
    return room_array
end

function get_current_floor()
    current_floor_address = {0x87B244, 0x87B844}
    return ReadByte(current_floor_address[game_version])
end

function get_time_played()
    time_played_pointer_address = {0x87AAE0, 0x87B0E0}
    time_played_pointer_offset_1 = 0x8
    time_played_pointer_offset_2 = 0x300
    time_played_pointer_1 = GetPointer(time_played_pointer_address[game_version], time_played_pointer_offset_1)
    time_played_pointer_2 = GetPointer(time_played_pointer_1, time_played_pointer_offset_2, true)
    time_played = ReadInt(time_played_pointer_2, true)
    return time_played
end

function get_empty_battle_cards_array()
    card_array = {}
    i = 1
    while i <= 870 do
        card_array[i] = 0
        i = i + 1
    end
    return card_array
end

function get_empty_enemy_cards_array()
    enemy_cards_array = {}
    i = 1
    while i <= 57 do
        enemy_cards_array[i] = 0
        i = i + 1
    end
    return enemy_cards_array
end

function get_empty_world_assignment_array()
    world_assignment_array = {1,1,1,1,1,1,1,1,1,1,1,1,1}
    return world_assignment_array
end

function get_empty_friends_array()
    friends_array = {0,0,0,0,0,0,0,0}
    return friends_array
end

function get_empty_sleights_array()
    sleights_array = {}
    for i=1,84 do
        sleights_array[i] = 0
    end
    return sleights_array
end

function get_calculated_cutscene_array()
    journal_array_pointer_address = {0x87C608, 0x87CC08}
    world_jounal_entry_array_offset = 0x68
    dp_pointer_address = {0x87C5F8, 0x87CBF8}
    dp_pointer_offset = 0x14
    journal_array_pointer = GetPointer(journal_array_pointer_address[game_version])
    world_journal_entry_array = ReadArray(journal_array_pointer + world_jounal_entry_array_offset, 13, true)
    dp_pointer = GetPointer(dp_pointer_address[game_version])
    dp = ReadByte(dp_pointer + dp_pointer_offset, true)
    for world_num, journal_byte in pairs(world_journal_entry_array) do
        if journal_byte > 0 then
            world_journal_entry_array[world_num] = 0
            dp = dp + 1
        end
    end
    
    WriteArray(journal_array_pointer + world_jounal_entry_array_offset, world_journal_entry_array, true)
    WriteByte(dp_pointer + dp_pointer_offset, dp, true)
    
    cutscene_array = {0x01, 0x00, 0x02, 0x00, 0x03, 0x00, 0x04, 0x00, 0x05, 0x00, 0x06, 0x00, 0x07, 0x00, 0x08, 0x00, 0x09, 0x00, 0x0A, 0x00, 0x0B, 0x00, 0x0C, 0x00, 0x0D, 0x00, 0x0E, 0x00, 0x0F, 
                0x00, 0x10, 0x00, 0x11, 0x00, 0x12, 0x00, 0x13, 0x00, 0x14, 0x00, 0x15, 0x00, 0x16, 0x00, 0x17, 0x00, 0x18, 0x00}
    if dp == 0 then --1F Exit Hall: Axel I
        cutscene_array[3] = 0xD2
        cutscene_array[4] = 0x07
    elseif dp == 1 then --6F Exit Hall: Larxene I
        cutscene_array[23] = 0xDC
        cutscene_array[24] = 0x07
    elseif dp == 2 then --7F Exit Hall: Riku I
        cutscene_array[27] = 0xDE
        cutscene_array[28] = 0x07
    elseif dp == 3 then --8F Exit Hall: Riku II
        cutscene_array[31] = 0xE0
        cutscene_array[32] = 0x07
    elseif dp == 4 then --10F Exit Hall: Vexen I
        cutscene_array[39] = 0xE4
        cutscene_array[40] = 0x07
    elseif dp == 5 then --11F Exit Hall: Riku III
        cutscene_array[43] = 0xE6
        cutscene_array[44] = 0x07
    elseif dp == 6 then --Fix?
        cutscene_array[45] = 0xE7
        cutscene_array[46] = 0x07
    elseif dp == 7 then --12F Exit Hall: Riku IV
        cutscene_array[47] = 0xE8
        cutscene_array[48] = 0x07
    elseif dp > 7 and get_journal_array()[107] == 0 then --12F Exit Hall: Larxene II
        cutscene_array[47] = 0xE1
        cutscene_array[48] = 0x00
    end
    current_room_address = {0x87B260, 0x87B860}
    world_pointer_address = {0x87C608, 0x87CC08}
    world_pointer_offset = -0xFC8
    world_pointer = GetPointer(world_pointer_address[game_version])
    if ReadShort(current_room_address[game_version]) == 0x17 and ReadShort(world_pointer + world_pointer_offset, true) == 0x0 and cutscene_array[45] == 0xE7 then
        dp = dp + 1
        WriteByte(dp_pointer + dp_pointer_offset, dp, true)
    end
    return cutscene_array
end

function get_world_assignments_array()
    world_assignment_array_pointer_address = {0x87C598, 0x87CB98}
    world_assignment_array_pointer_offset = 0x48
    world_assignment_array_pointer = GetPointer(world_assignment_array_pointer_address[game_version], world_assignment_array_pointer_offset)
    return ReadArray(world_assignment_array_pointer, 13, true)
end

function get_friend_cards_array()
    friend_pointer_address = {0x87C608, 0x87CC08}
    friend_pointer_offset = 0x147
    friend_pointer = GetPointer(friend_pointer_address[game_version], friend_pointer_offset)
    friend_cards_array = ReadArray(friend_pointer, 8, true)
    return friend_cards_array
end

function get_rewards_bounties_array()
    rewards_bounties_array_pointer_address = {0x87C5D0, 0x87CBD0}
    rewards_bounties_array_pointer_offset = 0xE1
    rewards_bounties_array_pointer = GetPointer(rewards_bounties_array_pointer_address[game_version], rewards_bounties_array_pointer_offset)
    rewards_bounties_array = ReadArray(rewards_bounties_array_pointer, 46, true)
    return rewards_bounties_array
end

function get_minigames_array()
    minigames_array_pointer_address = {0x87C608, 0x87CC08}
    minigames_array_pointer_offset = 0x1EE
    mingames_array_pointer = GetPointer(minigames_array_pointer_address[game_version], minigames_array_pointer_offset)
    mingames_array = ReadArray(mingames_array_pointer, 6, true)
    return minigames_array
end

function get_extra_checks()
    ids = {}
    journal_array = get_journal_array()
    if journal_array[24] > 0 then --Fire
        ids[#ids+1] = 2692010
        ids[#ids+1] = 2692017
    end
    if journal_array[25] > 0 then --Blizzard
        ids[#ids+1] = 2692011
        ids[#ids+1] = 2692018
    end
    if journal_array[26] > 0 then --Thunder
        ids[#ids+1] = 2692012
        ids[#ids+1] = 2692019
    end
    if journal_array[27] > 0 then --Cure
        ids[#ids+1] = 2692013
        ids[#ids+1] = 2692020
    end
    if journal_array[28] > 0 then --Gravity
        ids[#ids+1] = 2692014
        ids[#ids+1] = 2692021
    end
    if journal_array[29] > 0 then --Stop
        ids[#ids+1] = 2692015
        ids[#ids+1] = 2692022
    end
    if journal_array[30] > 0 then --Aero
        ids[#ids+1] = 2692016
        ids[#ids+1] = 2692023
    end
    if journal_array[31] > 0 then --Simba
        ids[#ids+1] = 2692049
        ids[#ids+1] = 2692050
    end
    if journal_array[32] > 0 then --Genie
        ids[#ids+1] = 2692058
        ids[#ids+1] = 2692059
    end
    if journal_array[33] > 0 then --Bambi
        ids[#ids+1] = 2692053
        ids[#ids+1] = 2692054
    end
    if journal_array[34] > 0 then --Dumbo
        ids[#ids+1] = 2692051
        ids[#ids+1] = 2692052
    end
    if journal_array[35] > 0 then --Tinker Bell
        ids[#ids+1] = 2692060
        ids[#ids+1] = 2692061
    end
    if journal_array[36] > 0 then --Mushu
        ids[#ids+1] = 2692056
        ids[#ids+1] = 2692057
    end
    if journal_array[37] > 0 then --Cloud
        ids[#ids+1] = 2692062
        ids[#ids+1] = 2692063
    end
    
    rewards_bounties_array = get_rewards_bounties_array()
    if rewards_bounties_array[2] > 0 then --Warp
        ids[#ids+1] = 2692041
    end
    if rewards_bounties_array[4] > 0 then --Synchro
        ids[#ids+1] = 2692045
    end
    if rewards_bounties_array[5] > 0 then --Aqua Splash
        ids[#ids+1] = 2692034
    end
    if rewards_bounties_array[6] > 0 then --Bind
        ids[#ids+1] = 2692042
    end
    if rewards_bounties_array[7] > 0 then --Quake
        ids[#ids+1] = 2692039
    end
    if rewards_bounties_array[8] > 0 then --Thunder Raid
        ids[#ids+1] = 2692026
    end
    if rewards_bounties_array[11] > 0 then --Stardust Blitz
        ids[#ids+1] = 2692067
    end
    if rewards_bounties_array[36] > 0 then --Blizzard Raid
        ids[#ids+1] = 2692025
    end
    if rewards_bounties_array[38] > 0 then --Fire Raid
        ids[#ids+1] = 2692024
    end
    if rewards_bounties_array[39] > 0 then --Gifted Miracle
        ids[#ids+1] = 2692046
    end
    if rewards_bounties_array[40] > 0 then --Shock Impact
        ids[#ids+1] = 2692037
    end
    if rewards_bounties_array[40] > 1 then --Homing Blizzara
        ids[#ids+1] = 2692033
    end
    if rewards_bounties_array[41] > 0 then --Teleport
        ids[#ids+1] = 2692047
    end
    if rewards_bounties_array[42] > 0 then --Reflect Raid
        ids[#ids+1] = 2692027
    end
    if rewards_bounties_array[44] > 0 then --Warpinator
        ids[#ids+1] = 2692040
    end
    if rewards_bounties_array[45] > 0 then --Judgement
        ids[#ids+1] = 2692028
    end
    if rewards_bounties_array[46] > 0 then --Raging Storm
        ids[#ids+1] = 2692030
    end
    
    friend_cards_array = get_friend_cards_array()
    if friend_cards_array[1] > 0 then --Donald
        ids[#ids+1] = 2692065
        ids[#ids+1] = 2692066
    end
    if friend_cards_array[2] > 0 then --Goofy
        ids[#ids+1] = 2692068
        ids[#ids+1] = 2692069
        ids[#ids+1] = 2692070
        ids[#ids+1] = 2692071
    end
    if friend_cards_array[3] > 0 then --Aladdin
        ids[#ids+1] = 2692072
        ids[#ids+1] = 2692073
    end
    if friend_cards_array[4] > 0 then --Ariel
        ids[#ids+1] = 2692076
        ids[#ids+1] = 2692077
    end
    if friend_cards_array[5] > 0 then --Jack
        ids[#ids+1] = 2692044
        ids[#ids+1] = 2692074
        ids[#ids+1] = 2692075
    end
    if friend_cards_array[6] > 0 then --Peter Pan
        ids[#ids+1] = 2692078
        ids[#ids+1] = 2692079
    end
    if friend_cards_array[7] > 0 then --Beast
        ids[#ids+1] = 2692080
        ids[#ids+1] = 2692081
    end
    if friend_cards_array[8] > 0 then --Pluto
        ids[#ids+1] = 2692082
        ids[#ids+1] = 2692083
    end
    
    minigames_array = get_minigames_array()
    if mingames_array[1] > 0 then --Firaga Burst
        ids[#ids+1] = 2692029
    end
    if mingames_array[4] > 0 then --Idyll Romp
        ids[#ids+1] = 2692055
    end
    if mingames_array[5] > 0 then --Cross-Slash +
        ids[#ids+1] = 2692064
    end
    
    soras_level = get_soras_level()
    if soras_level >= 2 then --Sliding Dash
        ids[#ids+1] = 2692001
    end
    if soras_level >= 7 then --Stun Impact
        ids[#ids+1] = 2692003
    end
    if soras_level >= 12 then --Strike Raid
        ids[#ids+1] = 2692005
    end
    if soras_level >= 17 then --Blitz
        ids[#ids+1] = 2692002
    end
    if soras_level >= 22 then --Zantetsuken
        ids[#ids+1] = 2692004
    end
    if soras_level >= 27 then --Sonic Blade
        ids[#ids+1] = 2692006
    end
    if soras_level >= 32 then --Lethal Frame
        ids[#ids+1] = 2692036
    end
    if soras_level >= 37 then --Tornado
        ids[#ids+1] = 2692038
    end
    if soras_level >= 42 then --Ars Arcanum
        ids[#ids+1] = 2692007
    end
    if soras_level >= 47 then --Holy
        ids[#ids+1] = 2692048
    end
    if soras_level >= 52 then --Raganarok
        ids[#ids+1] = 2692008
    end
    if soras_level >= 57 then --Mega Flare
        ids[#ids+1] = 2692031
    end
    
    if world_assignment_array[13] > 1 then --Trinity Limit
        ids[#ids+1] = 2692009
    end
    
    if piglet_found() then
        ids[#ids+1] = 2692043
    end
    
    return ids
end

function get_soras_level()
    soras_level_pointer_address = {0x87C5F8, 0x87CBF8}
    soras_level_pointer_offset = 0x1C
    soras_level_pointer = GetPointer(soras_level_pointer_address[game_version], soras_level_pointer_offset)
    soras_level = ReadInt(soras_level_pointer, true)
    return soras_level
end

function get_dp_checks()
    dp_location_ids = {}
    dp_pointer_address = {0x87C5F8, 0x87CBF8}
    dp_pointer_offset = 0x14
    dp_pointer = GetPointer(dp_pointer_address[game_version])
    dp = ReadByte(dp_pointer + dp_pointer_offset, true)
    
    if dp > 3 then
        dp_location_ids[#dp_location_ids + 1] = 2692035 --Riku II Magnet Spiral
    end
    if dp > 4 then
        dp_location_ids[#dp_location_ids + 1] = 2692032 --Vexen I Freeze
    end
    return dp_location_ids
end

function set_gold_map_cards(gold_map_cards_array)
    gold_map_cards_pointer_address = {0x87A1F0, 0x87A7F0}
    gold_map_cards_pointer_offset = 0x2
    gold_map_cards_pointer = GetPointer(gold_map_cards_pointer_address[game_version], gold_map_cards_pointer_offset)
    WriteArray(gold_map_cards_pointer, gold_map_cards_array, true)
end

function set_battle_cards(battle_cards_array)
    cards_pointer_address = {0x87C5F8, 0x87CBF8}
    card_pointer_offset = -0xD74
    cards_pointer = GetPointer(cards_pointer_address[game_version], card_pointer_offset)
    WriteArray(cards_pointer, battle_cards_array, true)
end

function set_enemy_cards(enemy_cards_array)
    enemy_cards_pointer_address = {0x87C5F8, 0x87CBF8}
    enemy_cards_pointer_offset = -0x914
    enemy_cards_pointer = GetPointer(enemy_cards_pointer_address[game_version], enemy_cards_pointer_offset)
    WriteArray(enemy_cards_pointer, enemy_cards_array, true)
end

function set_world_assignment(world_assignment_array)
    world_assignment_pointer_address = {0x87C598, 0x87CB98}
    world_assignment_pointer_offset = 0x48
    world_assignment_pointer = GetPointer(world_assignment_pointer_address[game_version], world_assignment_pointer_offset)
    current_world_assignments = ReadArray(world_assignment_pointer, #world_assignment_array, true)
    copy_world_assignment_array = {}
    for k,v in pairs(world_assignment_array) do
        copy_world_assignment_array[k] = v
    end
    current_floor = get_current_floor()
    copy_world_assignment_array[current_floor] = current_world_assignments[current_floor]
    WriteArray(world_assignment_pointer, copy_world_assignment_array, true)
end

function set_map_cards()
    map_cards_pointer_address = {0x87C5F8, 0x87CBF8}
    map_cards_pointer_offset = -0xA0E
    map_cards_pointer = GetPointer(map_cards_pointer_address[game_version], map_cards_pointer_offset)
    map_cards_array = {}
    i = 1
    while i <= 24*10 do
        if i <= 220 then
            map_cards_array[i] = 9
        else
            map_cards_array[i] = 0
        end
        i = i + 1
    end
    WriteArray(map_cards_pointer, map_cards_array, true)
end

function set_initial_battle_cards()
    for k,v in pairs(card_set_data[1]) do
        add_battle_card(1, v)
    end
end

function set_cutscene_array(cutscene_array)
    cutscene_array_pointer_address = {0x87C5D0, 0x87CBD0}
    cutscene_array_pointer_offset = 0x272
    cutscene_array_pointer = GetPointer(cutscene_array_pointer_address[game_version], cutscene_array_pointer_offset)
    WriteArray(cutscene_array_pointer, cutscene_array, true)
end

function set_initial_deck()
    initial_deck_array = {}
    i = 0
    if not card_set_data_read then
        initial_deck_array[1] = 1
        initial_deck_array[2] = 0
        initial_deck_array[3] = 1
        initial_deck_array[4] = 17
        initial_deck_array[5] = 1
        initial_deck_array[6] = 0
        initial_deck_array[7] = 2
        initial_deck_array[8] = 17
        initial_deck_array[9] = 1
        initial_deck_array[10] = 0
        initial_deck_array[11] = 3
        initial_deck_array[12] = 17
        i = 3
    else
        for k,v in pairs(card_set_data[1]) do
            initial_deck_array[((k-1)*4)+1] = 1
            if v < 10 then
                initial_deck_array[((k-1)*4)+2] = 0
            else
                initial_deck_array[((k-1)*4)+2] = 1
            end
            initial_deck_array[((k-1)*4)+3] = (v%10)
            initial_deck_array[((k-1)*4)+4] = 17
            i = i + 1
        end
    end
    while i < 99 do
        initial_deck_array[(i*4)+1] = 0
        initial_deck_array[(i*4)+2] = 0
        initial_deck_array[(i*4)+3] = 0
        initial_deck_array[(i*4)+4] = 0
        i = i + 1
    end
    deck_pointer_address = {0x87C5F8, 0x87CBF8}
    deck_pointer_offset = -0x8D8
    deck_pointer = GetPointer(deck_pointer_address[game_version], deck_pointer_offset)
    WriteArray(deck_pointer, initial_deck_array, true)
end

function set_sleights(sleights_array)
    sleights_bytes_array = {}
    i = 1
    while i <= 84 do
        sleights_byte = 0
        if sleights_array[i+0] == 1 then
            sleights_byte = sleights_byte + 2
        end
        if sleights_array[i+1] == 1 then
            sleights_byte = sleights_byte + 8
        end
        if sleights_array[i+2] == 1 then
            sleights_byte = sleights_byte + 32
        end
        if sleights_array[i+3] == 1 then
            sleights_byte = sleights_byte + 128
        end
        sleights_bytes_array[#sleights_bytes_array+1] = sleights_byte
        i = i + 4
    end
    
    sleights_pointer_address = {0x87C608, 0x87CC08}
    sleights_pointer_offset = 0x1
    sleights_pointer = GetPointer(sleights_pointer_address[game_version], sleights_pointer_offset)
    WriteArray(sleights_pointer, sleights_bytes_array, true)
end

function set_level_up_sleights()
    level_up_sleight_table_address = {0x10EBE2, 0x10EF72}
    WriteByte(level_up_sleight_table_address[game_version], 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x02, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x07, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x09, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x0E, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x10, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x15, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x17, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x1C, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x1E, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x23, 0x65)
    WriteByte(level_up_sleight_table_address[game_version]+0x25, 0x65)
end

function set_attack_power()
    if attack_power ~= 10 then
        attack_power_pointer_address = {0x87AD90, 0x87B390}
        attack_power_pointer_offset = 0x43C
        attack_power_pointer = GetPointer(attack_power_pointer_address[game_version], attack_power_pointer_offset)
        if ReadInt(attack_power_pointer, true) == 10 then
            WriteInt(attack_power_pointer, attack_power, true)
        end
    end
end

function set_friend_cards_on_deck_3()
    deck_3_cards_pointer_address = {0x87C5F8, 0x87CBF8}
    deck_3_cards_pointer_offset = -0x5C0
    deck_3_cards_pointer = GetPointer(deck_3_cards_pointer_address[game_version], deck_3_cards_pointer_offset)
    deck_3_array = {}
    friends_card_values = {49, 50, 51, 52, 55, 54, 53, 57}
    for k,v in pairs(friends_array) do
        deck_3_array[((k-1)*4)+1] = friends_card_values[k]
        deck_3_array[((k-1)*4)+2] = 0
        deck_3_array[((k-1)*4)+3] = 1
        if v > 0 then
            deck_3_array[((k-1)*4)+4] = 68
        else
            deck_3_array[((k-1)*4)+4] = 119
        end
    end
    WriteArray(deck_3_cards_pointer, deck_3_array, true)
end

function set_friends()
    friend_pointer_address = {0x87AAE0, 0x87B0E0}
    friend_pointer_offset_1 = 0x8
    friend_pointer_offset_2 = 0x300
    friend_pointer_1 = GetPointer(friend_pointer_address[game_version], friend_pointer_offset_1)
    friend_pointer_2 = GetPointer(friend_pointer_1, friend_pointer_offset_2, true)
    WriteByte(friend_pointer_2 - 0x278, 0xFF, true)
end

function set_blizzard()
    blizzard_journal_pointer_address = {0x87C608, 0x87CC08}
    blizzard_journal_pointer_offset = 0x133
    blizzard_journal_pointer = GetPointer(blizzard_journal_pointer_address[game_version], blizzard_journal_pointer_offset)
    WriteByte(blizzard_journal_pointer, 0x1, true)
end

function add_battle_card(battle_card_index, battle_card_value)
    index = ((battle_card_index-1) * 10) + 1
    index = index + battle_card_value % 10
    if battle_card_index > 80 and battle_card_value > 9 then
        battle_card_value = battle_card_value % 10
    end
    premium_offset = 0xF0
    if battle_card_index > 24 then
        premium_offset = 0xA0
    end
    if index <= 870 then
        if battle_card_value >= 0 and battle_card_value < 10 then
            battle_cards_array[index] = battle_cards_array[index] + 1
        elseif battle_card_value >= 10 and battle_card_value < 20  and battle_card_index < 81 then
            battle_cards_array[index + premium_offset] = battle_cards_array[index + premium_offset] + 1
        end
    end
end

function calculate_cards_to_add(battle_card_index, sets_received)
    index = ((sets_received - 1)%(card_set_data_reset_value-1))+1
    values = card_set_data[index]
    for index,battle_card_value in pairs(values) do
        add_battle_card(battle_card_index, battle_card_value)
    end
end

function read_world_order()
    if file_exists(client_communication_path .. "worldorder.cfg") then
        file = io.open(client_communication_path .. "worldorder.cfg", "r")
        io.input(file)
        world_order = split(io.read(),",")
        io.close(file)
    else
        world_order = {2,3,4,5,6,7,8,9,10}
    end
end

function read_attack_power()
    if file_exists(client_communication_path .. "attackpower.cfg") then
        file = io.open(client_communication_path .. "attackpower.cfg", "r")
        io.input(file)
        attack_power = tonumber(io.read())
        io.close(file)
    else
        attack_power = 10
    end
end

function read_set_data()
    if file_exists(client_communication_path .. "setdata.cfg") and not card_set_data_read then
        card_set_data_string = slurp(client_communication_path .. "setdata.cfg")
        result = {}
        i = 1
        for line in string.gmatch(card_set_data_string .. "\n", "(.-)\n") do
            card_set_data[i] = split(line,",")
            i = i + 1
        end
        for k,v in pairs(card_set_data) do
            for ik,iv in pairs(v) do
                card_set_data[k][ik] = tonumber(iv)
            end
        end
        final_line_number = 21
        while card_set_data[final_line_number-1][1] == nil do
            final_line_number = final_line_number - 1
        end
        card_set_data_reset_value = final_line_number
        card_set_data_read = true
    end
end

function final_marluxia_slain()
    world_address = {0x87B262, 0x87B862}
    room_address = {0x87B260, 0x87B860}
    if ReadByte(world_address[game_version]) == 0x0D and ReadArray(room_address[game_version],2)[1] == 0xD4 and ReadArray(room_address[game_version],2)[2] == 0x07 then
        return true
    end
    return false
end

function piglet_found()
    piglet_found_byte_pointer_address = {0x87C608, 0x87CC08}
    piglet_found_byte_pointer_offset = 0xB7
    piglet_found_byte_pointer = GetPointer(piglet_found_byte_pointer_address[game_version], piglet_found_byte_pointer_offset)
    if ReadByte(piglet_found_byte_pointer, true) > 0 then 
        return true
    else
        return false
    end
end

function receive_items()
    current_floor = get_current_floor()
    set_map_cards()
    
    if item_index == 0 then 
        set_initial_battle_cards()
        item_index = item_index + 1
    end
    
    while file_exists(client_communication_path .. "AP_" .. tostring(item_index) .. ".item") do
        file = io.open(client_communication_path .. "AP_" .. tostring(item_index) .. ".item", "r")
        io.input(file)
        received_item_id = tonumber(io.read())
        io.close(file)
        if received_item_id > 2681000 and received_item_id < 2681200 then
            card_index = received_item_id % 2681000
            if card_sets_received[card_index] == nil then
                card_sets_received[card_index] = 1
            else
                card_sets_received[card_index] = card_sets_received[card_index] + 1
            end
            calculate_cards_to_add(card_index, card_sets_received[card_index])
        elseif received_item_id > 2681200 and received_item_id < 2682000 then
            enemy_card_index = received_item_id % 2681200
            enemy_cards_array[enemy_card_index] = enemy_cards_array[enemy_card_index] + 1
        elseif received_item_id > 2682000 and received_item_id < 2683000 then
            sleights_index = received_item_id % 2682000
            sleights_array[sleights_index] = 1
        elseif received_item_id > 2683000 and received_item_id < 2683300 then
            world_id = received_item_id % 2683000
            if world_id > 1 and world_id < 11 then
                world_assignment_array[world_order[world_id-1]] = world_id
            else
                world_assignment_array[world_id] = world_id
            end
        elseif received_item_id > 2683300 and received_item_id < 2684000 then
            world_id = received_item_id % 2683300
            key_to_rewards_found[#key_to_rewards_found+1] = world_id
        elseif received_item_id > 2685000 and received_item_id < 2686000 then
            friend_id = received_item_id % 2685000
            if friends_array[friend_id] ~= 1 then
                friend_count = friend_count + 1
                friends_array[friend_id] = 1
            end
        elseif received_item_id == 2680000 then
            victory = true
        end
        item_index = item_index + 1
    end
    if friend_count >= 8 and get_journal_array()[107] > 0 then --if all friends are found and you have beaten Larxene II
        world_assignment_array[13] = 0xD
    else
        world_assignment_array[13] = 0x1
    end
    if current_floor == 1 or world_assignment_array[current_floor] ~= 1 then
        gold_map_cards_array[1] = 1
        gold_map_cards_array[2] = 1
        gold_map_cards_array[3] = 1
        gold_map_cards_array[4] = 0
    else
        gold_map_cards_array[1] = 0
        gold_map_cards_array[2] = 0
        gold_map_cards_array[3] = 0
        gold_map_cards_array[4] = 0
    end
    for key_index,key_world_id in pairs(key_to_rewards_found) do
        if ((current_floor == key_world_id and (current_floor < 2 or current_floor > 10)) or (current_floor == world_order[key_world_id-1])) and (current_floor == 1 or world_assignment_array[current_floor] ~= 1) then
            gold_map_cards_array[4] = 1
        end
    end
    
    set_battle_cards(battle_cards_array)
    set_enemy_cards(enemy_cards_array)
    set_sleights(sleights_array)
    set_gold_map_cards(gold_map_cards_array)
    set_world_assignment(world_assignment_array)
    set_friend_cards_on_deck_3()
end

function send_checks()
    if get_time_played() > 0 then
        journal_array = get_journal_array()
        for k,v in pairs(journal_array) do
            if v > 0 then
                location_id = 2690000 + k
                if not file_exists(client_communication_path .. "send" .. tostring(location_id)) then
                    file = io.open(client_communication_path .. "send" .. tostring(location_id), "w")
                    io.output(file)
                    io.write("")
                    io.close(file)
                end
            end
        end
        room_array = get_room_array()
        for k,v in pairs(room_array) do
            if v > 0 then
                floor_num = math.floor((k-1)/3)+1
                world_id = world_assignment_array[floor_num]
                room_num = ((k-1)%3)+1
                location_id = 2691000 + (world_id * 10) + room_num
                if not file_exists(client_communication_path .. "send" .. tostring(location_id)) then
                    file = io.open(client_communication_path .. "send" .. tostring(location_id), "w")
                    io.output(file)
                    io.write("")
                    io.close(file)
                end
            end
        end
        heartless_array = get_heartless_array()
        j = 1
        while j < #heartless_array do
            heartless_id = math.floor((j+1)/2)
            num_defeated = heartless_array[j] + (heartless_array[j+1] * 256)
            if num_defeated >= 1 then
                location_id = 2691200 + heartless_id
                if not file_exists(client_communication_path .. "send" .. tostring(location_id)) then
                    file = io.open(client_communication_path .. "send" .. tostring(location_id), "w")
                    io.output(file)
                    io.write("")
                    io.close(file)
                end
            end
            if num_defeated >= 2 then
                location_id = 2691300 + heartless_id
                if not file_exists(client_communication_path .. "send" .. tostring(location_id)) then
                    file = io.open(client_communication_path .. "send" .. tostring(location_id), "w")
                    io.output(file)
                    io.write("")
                    io.close(file)
                end
            end
            if num_defeated >= 3 then
                location_id = 2691400 + heartless_id
                if not file_exists(client_communication_path .. "send" .. tostring(location_id)) then
                    file = io.open(client_communication_path .. "send" .. tostring(location_id), "w")
                    io.output(file)
                    io.write("")
                    io.close(file)
                end
            end
            j = j + 2
        end
        
        extra_checks = get_extra_checks()
        for k,v in pairs(extra_checks) do
            if not file_exists(client_communication_path .. "send" .. tostring(v)) then
                file = io.open(client_communication_path .. "send" .. tostring(v), "w")
                io.output(file)
                io.write("")
                io.close(file)
            end
        end
        dp_checks = get_dp_checks()
        for k,v in pairs(dp_checks) do
            if not file_exists(client_communication_path .. "send" .. tostring(v)) then
                file = io.open(client_communication_path .. "send" .. tostring(v), "w")
                io.output(file)
                io.write("")
                io.close(file)
            end
        end
        
        if final_marluxia_slain() then
            if not file_exists(client_communication_path .. "send2699999") then
                file = io.open(client_communication_path .. "send2699999", "w")
                io.output(file)
                io.write("")
                io.close(file)
            end
        end
        
        if victory then
            if not file_exists(client_communication_path .. "victory") then
                file = io.open(client_communication_path .. "victory", "w")
                io.output(file)
                io.write("")
                io.close(file)
            end
        end
        
    end
    
end

function initialize()
    read_set_data()
    battle_cards_array = get_empty_battle_cards_array()
    enemy_cards_array = get_empty_enemy_cards_array()
    world_assignment_array = get_empty_world_assignment_array()
    friends_array = get_empty_friends_array()
    sleights_array = get_empty_sleights_array()
    card_sets_received = {}
    friend_count = 0
    item_index = 0
    victory = false
end

function fix_card_set_data()
    while card_set_data[1][1] == nil do
        table.remove(card_set_data, 1)
    end
    if card_set_data[1][1] == nil then
        card_set_data[1] = {0,1,2,3,4,5,6,7,8,9}
    end
    i = 20
    while i >= 1 do
        if card_set_data[i] == nil then
            card_set_data[i] = {}
            card_set_data_reset_value = i
        elseif card_set_data[i][1] == nil then
            card_set_data_reset_value = i
        end
        i = i - 1
    end
    card_set_data_fixed = true
end

function _OnInit()
    if GAME_ID == 0x9E3134F5 and ENGINE_TYPE == "BACKEND" then
        canExecute = true
        if ReadByte(0x4E6C80) == 15 or ReadByte(0x4E6AC0) == 242 then
            ConsolePrint("Epic Games Version Detected")
            game_version = 1
        elseif ReadByte(0x4E7040) == 15 or ReadByte(0x4E6DC0) == 77 then
            ConsolePrint("Steam Version Detected")
            game_version = 2
        end
    else
        ConsolePrint("RE:CoM not detected, not running script")
    end
    if canExecute then
        initialize()
    end
end
function _OnFrame()
    if canExecute then
        if frame_count % 120 == 0 then
            set_blizzard()
            set_level_up_sleights()
            read_world_order()
            read_attack_power()
            read_set_data()
            set_attack_power()
            set_friends()
            if card_set_data_read and not card_set_data_fixed then
                fix_card_set_data()
            end
            if get_time_played() > 5 then
                set_cutscene_array(get_calculated_cutscene_array())
                receive_items()
                send_checks()
            else
                initialize()
                set_initial_deck()
            end
        end
        frame_count = frame_count + 1
    end
end