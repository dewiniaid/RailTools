librail = require("librail")
local rail_data = librail.rail_data


script.on_init(function()
    global.temporary_tiles = {}

end)


local function selected_signal(entity, player)
    local rails = librail.find_rail_for_signal(entity)
    local rd, d, signal, distance, distance_mod
    for i = 1, #rails do
        rd, chirality = rails[i].rail_direction, rails[i].rail_data.chirality
        log(string.format("Adjacent rail %d: stops=%d starts=%d chi=%s", rails[i].entity.unit_number, rails[i].signal.stops, rails[i].signal.starts, rails[i].rail_data.chirality and 'true' or 'false'))
        distance_mod = rails[i].rail_data.length - rails[i].signal.starts
        log(string.format("Forward distance mod: %d", distance_mod))
        for next_rail in librail.each_connected_rail(rails[i].entity, rd) do
            log("Next rail: unit_number=" ..next_rail.unit_number .." chirality=" .. (librail.get_rail_data(next_rail).chirality and 'true' or 'false'))
            d = librail.chiral_directions[chirality == librail.get_rail_data(next_rail).chirality][rd]
            signal, distance = find_nearest_signal(next_rail, d, d, 100)
            if signal then
                game.print(string.format("Next nearest signal (from %d): %d in %d", next_rail.unit_number, signal.entity.unit_number, distance+distance_mod))
            end
        end
        distance_mod = rails[i].signal.stops
        log(string.format("Reverse distance mod: %d", distance_mod))
        for next_rail in librail.each_connected_rail(rails[i].entity, librail.opposite_direction[rd]) do
            log("Next rail: unit_number=" ..next_rail.unit_number .." chirality=" .. (librail.get_rail_data(next_rail).chirality and 'true' or 'false'))
            d = librail.chiral_directions[chirality == librail.get_rail_data(next_rail).chirality][rd]
            signal, distance = find_nearest_signal(next_rail, librail.opposite_direction[d], d, 100)
            if signal then
                game.print(string.format("Prev nearest signal (from %d): %d in %d", next_rail.unit_number, signal.entity.unit_number, distance+distance_mod))
            end
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
            table.insert(temp.tiles, {position=position, name=surface.get_tile(position.x,position.y).name})
            table.insert(tiles, {position=position, name=tile_name})
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

function find_nearest_signal(rail, rail_direction, signal_direction, max_distance)
    local signals_reversed = rail_direction ~= signal_direction

    local visited = {
        [defines.rail_direction.front] = {},
        [defines.rail_direction.back] = {},
    }  -- [direction][unit_number] -> distance
    local frontier = {}  -- {{rail, direction, data, distance}}
    local unvisited = {{rail, rail_direction, librail.get_rail_data(rail), 0}}   -- same format as frontier

    local closest_signal, closest_distance

    local temp
    local unit_number
    local data, distance
    local next_data, next_direction
    local signals

    while unvisited[1] do
        frontier, unvisited = unvisited, frontier
        for i = 1, #frontier do
            --log(serpent.block(frontier[i]))
            rail, rail_direction, data, distance = unpack(frontier[i])
            unit_number = rail.unit_number
            log(string.format("[%d] rail_direction=%s  distance=%s  unit_number=%s chirality=%s",
                    i,
                    rail_direction or 'nil',
                    distance or 'nil',
                    unit_number or 'nil',
                    data.chirality and 'true' or 'false'
            ))
            frontier[i] = nil

            if (closest_distance and closest_distance < distance) then
                log("worse than closest, skipping to next.")
                goto next_frontier
            end
            temp = visited[rail_direction][unit_number]
            if temp and temp < distance then
                log("already crawled with shorter distance, skipping to next.")
                goto next_frontier
            end
            visited[rail_direction][unit_number] = distance

            signals = librail.find_signals(rail, signals_reversed and librail.opposite_direction[rail_direction] or rail_direction)
            if signals[1] then
                for j = 1, #signals do
                    log(string.format("signal %d stops=%d starts=%d", j, signals[j].stops, signals[j].starts))

                    --temp = distance + ((signals_reversed and (data.length - signals[j].stops)) or signals[j].starts)

                    if signals_reversed then
                        -- Going backwards, so concerned with where this signal 'starts'
                        temp = distance + (data.length - signals[j].starts)
                        log(string.format("signal %d starts=%d temp=%d", j, signals[j].starts, temp))
                    else
                        -- Going forward, so concerned with where trains stop
                        temp = distance + signals[j].stops
                        log(string.format("signal %d stops=%d temp=%d", j, signals[j].stops, temp))
                    end

                    if not closest_distance or temp < closest_distance then
                        closest_signal = signals[j]
                        closest_distance = temp
                        log("NEW WINNER, distance=" .. closest_distance)
                    end
                end
                -- If we have a signal here, nothing past this point is going to be closer... not this route anyways.
                log("Found signals, skipping to next.")
                goto next_frontier
            end

            -- No signals, so connected rails to the next frontier.
            distance = distance + data.length
            if distance > max_distance then
                log("distance > max, skipping to next.")
                goto next_frontier
            end
            for next_rail in librail.each_connected_rail(rail, rail_direction) do
                next_data = librail.get_rail_data(next_rail)
                next_direction = librail.chiral_directions[next_data.chirality == data.chirality][rail_direction]
                temp = visited[next_direction][next_rail.unit_number]
                if temp and temp < distance then goto next_frontier end
                table.insert(unvisited, {next_rail, next_direction, next_data, distance})
            end
            ::next_frontier::
        end
    end

    log("closest_distance=" .. (closest_distance or 'nil'))

    return closest_signal, closest_distance
end








-- If player is holding a chain signal, use chain signals, otherwise use rail.

-- First, work backwards:
--

-- Follow forward until branch