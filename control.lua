librail = require("librail")
local rail_data = librail.rail_data


script.on_init(function()
    global.temporary_tiles = {}
end)


local function selected_signal(entity, player)
    local signal, distance, signals, data

    for _, rail in pairs(librail.find_rail_for_signal(entity)) do
        game.print(string.format("rail length=%s   signal stop=%s  start=%s", rail.rail_data.length, rail.signal.stops, rail.signal.starts))
    end

    for text, direction in pairs({ next = false, prev = true }) do
        signal, distance = librail.find_nearest_signal_from_signal(entity, direction)
        if signal then
            game.print(string.format("%s nearest signal %d in %.1f", text, signal.entity.unit_number, distance))
        end
        signals = librail.find_signals_in_branch_from_signal(entity, direction)
        for unit_number, x in pairs(signals) do
            data, distance = unpack(x)
            game.print(string.format("Signal #%s at distance %s", unit_number, distance))
        end
    end
end


local function selected_rail(entity, player)
    if not (entity and librail.rail_data[entity.type] and rail_data[entity.name][entity.direction]) then return end

    local surface = player.surface
    local origin = entity.position
    local offsets
    local pos
    local temp = {
        surface_index = surface.index,
        tiles = {}
    }
    global.temporary_tiles[player.index] = temp

    local tiles = {}

    log(serpent.block(rail_data[entity.type][entity.direction]))

    for rail_direction, tile_name in pairs({[defines.rail_direction.front] = "concrete", [defines.rail_direction.back] = "hazard-concrete-left"}) do
        offsets = rail_data[entity.type][entity.direction].signals[rail_direction]
        for i = 1, #offsets do
            local position = {x=origin.x + offsets[i].x, y=origin.y + offsets[i].y}
            temp.tiles[#temp.tiles + 1] = {position=position, name=surface.get_tile(position.x,position.y).name}
            tiles[#tiles + 1] = {position=position, name=tile_name}
        end
    end
    surface.set_tiles(tiles, true)

    local n = 0
    for rail, dir, length in librail.walk_to_crossing(entity, defines.rail_direction.front) do
        n = n + 1
        log(n .. ": unit_number=" .. (rail.unit_number or 'nil') .. ", length=" .. (length or nil) .. ", dir=" .. (dir or nil))
        if n > 20 then return end
    end

    local signals = librail.find_signals(entity)
    game.print("Found " .. #signals .. " signals.")
    for i = 1, #signals do
        game.print(signals[i].entity.unit_number)
    end
end


script.on_event(defines.events.on_selected_entity_changed, function(event)
    local temp = global.temporary_tiles[event.player_index]
    if temp then
        game.surfaces[temp.surface_index].set_tiles(temp.tiles, true)
    end
    global.temporary_tiles[event.player_index] = nil
    local player = game.players[event.player_index]
    local entity = player.selected
    if entity and (entity.type == 'rail-signal' or entity.type == 'rail-chain-signal') then
        selected_signal(entity, player)
    elseif entity and (entity.type == 'straight-rail' or entity.type == 'curved-rail') then
        selected_rail(entity, player)
    end
end)


--[[
Place signal at safe distance:

length_needed = safe_distance
current_length = 0

For each track going forward:
    current_length += length

    For each reverse branch other than us:
        reverse_length = 0
        For each track in reverse branch working backwards:
            reverse_length += length
            If has_signal then
                length_needed = length_needed + current_length - reverse_length
            If reverse_length > length then break

    if length > length_needed try_to_place_signal
End
]]







