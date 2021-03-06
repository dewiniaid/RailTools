librail = require("librail")
local rail_data = librail.rail_data

script.on_init(function()
    global.playerdata = {}
end)

local lookup = {}
lookup.signalstatus = {
    good = 1,
    bad = 2,
    neutral = 3
}

lookup.signalstatuscolor = {
    [lookup.signalstatus.good]    = {r=1.0, g=1.0, b=1.0, a=1.0},
    [lookup.signalstatus.bad]     = {r=1.0, g=0.5, b=0.1, a=1.0},
    [lookup.signalstatus.neutral] = {r=1.0, g=1.0, b=0.1, a=1.0},
}

lookup.linecolor = {
    [lookup.signalstatus.good]    = { r=0.7, g=0.7, b=0.7, a=0.15 },
    [lookup.signalstatus.neutral] = { r=0.7, g=0.7, b=0.7, a=0.15 },
    [lookup.signalstatus.bad]     = { r=1.0, g=0.0, b=0.0, a=0.75 },
}

local function is_signal(entity)
    return (
        entity.type == 'rail-signal' or entity.type == 'rail-chain-signal'
        or (
            entity.type == 'entity-ghost' and (
                entity.ghost_type == 'rail-signal' or entity.ghost_type == 'chain-signal'
            )
        )
    )
end

local function is_chain_signal(entity)
    return entity.type == 'rail-chain-signal' or (entity.type == 'entity-ghost' and entity.ghost_type == 'rail-chain-signal')
end

local function is_rail_signal(entity)
    return entity.type == 'rail-signal' or (entity.type == 'entity-ghost' and entity.ghost_type == 'rail-signal')
end


local function on_selected_signal(entity, player)
    local train_length = player.mod_settings["RailTools_train-length"].value
    local max_distance = settings.global["RailTools_max-search-distance"].value
    if train_length > max_distance then
        train_length = max_distance
    end

    local signalstatus = lookup.signalstatus
    local signalstatuscolor = lookup.signalstatuscolor
    local linecolor = lookup.linecolor

    local function has_chain_signals(t)
        for _, v in pairs(t) do
            if is_chain_signal(v.entity) then return true end
        end
        return false
    end

    local args = {signal=entity, max_distance=max_distance, signal_types=librail.signal_entity_types_with_ghosts}
    local ahead = librail.find_signals_in_branch_from_signal(args)
    args.backwards = true
    local behind = librail.find_signals_in_branch_from_signal(args)
    args.backwards = false

    local nearest_behind, nearest_ahead
    local global_status = signalstatus.good
    local nearest, t
    local signals = {}

    for i = 1, 2 do
        nearest = nil
        for unit_number, signal in pairs(i == 1 and ahead or behind) do
            signal.status = signalstatus.neutral
            signals[unit_number] = signal
            if not nearest or nearest.distance > signal.distance then
                nearest = signal
            end
        end
        if i == 1 then nearest_ahead = nearest else nearest_behind = nearest end
    end

    if is_chain_signal(entity) then
        -- Chain signal lookahead

        -- If all ahead signals are rail signals, we can skip a redundant search.
        local rail_signals_ahead = ahead
        if has_chain_signals(ahead) then
            args.signal_types = {"rail-signal", "entity-ghost"}
            rail_signals_ahead = librail.find_signals_in_branch_from_signal(args)
        end

        for n, origin in pairs(rail_signals_ahead) do
            -- [CHAIN]---....---rail---rail
            -- Find all rail signals ahead of us.  Then check the distance between them and their next signal(s)
            origin.status = signalstatus.good
            signals[n] = origin
            args.signal = origin.entity
            for n, dest in pairs(
                    librail.find_signals_in_branch_from_signal(args)
            ) do
                if not signals[n] then
                    dest.is_added_distance = true
                    signals[n] = dest
                end
                if dest.distance < train_length then
                    signals[n].status = signalstatus.bad
                    origin.status = signalstatus.bad
                    global_status = signalstatus.bad
                elseif signals[n] and signals[n].status ~= signalstatus.bad then
                    signals[n].status = signalstatus.good
                end
            end
        end
    elseif has_chain_signals(behind) then   -- and is a rail signal.
        -- chain---[RAIL]---any
        -- Rail signals lookahead is only needed if chain signals are behind this block.
        -- Since there are chain signals behind us, check all signals ahead of us to make sure they're far enough away.
        local newstatus = signalstatus.good
        for n, signal in pairs(ahead) do
            if signal.distance < train_length then
                newstatus = signalstatus.bad
                signals[n].status = signalstatus.bad
                global_status = signalstatus.bad
            else
                signals[n].status = signalstatus.good
            end
        end
        for n, signal in pairs(behind) do
            if signals[n].status ~= signalstatus.bad and is_chain_signal(signal.entity) then
                signals[n].status = newstatus
            end
        end
    end

    -- Regardless of what kind of signal we are, we need to do lookbehind -- and potentially another lookbehind.
    -- chain---rail---[ANY]
    args.halt = true
    args.keep = function(signal) return is_chain_signal(signal.entity) end
    args.backwards = true

    for n, signal in pairs(behind) do
        if signal.distance < train_length and is_rail_signal(signal.entity) then
            args.signal = signal.entity
            local chains = librail.find_signals_in_branch_from_signal(args)
            if next(chains) then
                signals[n].status = signalstatus.bad
                global_status = signalstatus.bad
                for n, signal in pairs(chains) do
                    if signals[n] then
                        signals[n].signalstatus = bad
                    else
                        signal.is_added_distance = true
                        signal.status = signalstatus.bad
                        signals[n] = signal
                    end
                end
            end
        end
    end

    local render_players = {player}
    local text_string = {"", nil}
    local text_args = {
        text = text_string,
        target_offset={0, 0.5},  -- Offset by 0.5 Y
        players=render_players,  -- Render to current player
        alignment='center',
        scale_with_zoom=true,    -- No tiny text for zoomed out rail construction
        surface=player.surface
    }

    local fmt, ent
    local hovering_renders = {}

    if next(signals) then
        local box_args = {
            sprite="RailTools_bad-signal-sprite",
            surface=player.surface,
            players=render_players,
        }
        --
        --local line_args = {
        --    surface=player.surface,
        --    players=render_players,
        --    from=entity,
        --    width=1
        --}
        --
        --local circle_args = {
        --    surface=player.surface,
        --    players=render_players,
        --    radius=0.25,
        --    filled=true
        --}


        for _, signal in pairs(signals) do
            if signal.status == signalstatus.bad then
                box_args.target = signal.entity
                hovering_renders[#hovering_renders + 1] = rendering.draw_sprite(box_args)
            end
            fmt = signal.is_added_distance and "(+%d (%d))" or "%d (%d)"
            text_string[2] = string.format(fmt, signal.distance, (1 + signal.distance) / 7)
            text_args.target = signal.entity
            text_args.color = signalstatuscolor[signal.status]
            hovering_renders[#hovering_renders + 1] = rendering.draw_text(text_args)

            --line_args.color = linecolor[signal.status]
            --line_args.to = signal.entity
            --circle_args.color = linecolor[signal.status]
            --circle_args.target = signal.entity
            --
            --hovering_renders[#hovering_renders + 1] = rendering.draw_line(line_args)
            --hovering_renders[#hovering_renders + 1] = rendering.draw_circle(circle_args)
        end
    end

    if nearest_behind or nearest_ahead then
        text_args.color = signalstatuscolor[global_status]
        text_args.target = entity
        if nearest_behind then
            text_string[2] = string.format("P: %d (%d)", nearest_behind.distance, (nearest_behind.distance + 1) / 7)
            --ent = entity.surface.create_entity(text)
            --ent.active = false
            hovering_renders[#hovering_renders + 1] = rendering.draw_text(text_args)
            text_args.target_offset[2] = text_args.target_offset[2] + 0.5
        end
        if nearest_ahead then
            text_string[2]  = string.format("N: %d (%d)", nearest_ahead.distance, (nearest_ahead.distance + 1) / 7)
            --ent = entity.surface.create_entity(text)
            --ent.active = false
            hovering_renders[#hovering_renders + 1] = ent
        end
    end
    if not global.playerdata[player.index] then
        global.playerdata[player.index] = {}
    end
    global.playerdata[player.index].hovering_renders = hovering_renders
end

local function clear_hovers(player_index)
    local pdata = global.playerdata and global.playerdata[player_index]
    if not pdata then
        return
    end
    local hovers = pdata.hovering_renders
    if hovers then
        for i = 1, #hovers do
            rendering.destroy(hovers[i])
        end
        pdata.hovering_renders = nil
    end
end

function on_selected_entity_changed(player)
    clear_hovers(player.index)

    local entity = player.selected
    if entity and is_signal(entity) then
        if not global.playerdata then
            global.playerdata = {}
        end
        on_selected_signal(entity, game.players[player.index])
    end
end

script.on_event(defines.events.on_selected_entity_changed, function(event)
    on_selected_entity_changed(game.players[event.player_index])
end)

script.on_event({defines.events.on_player_left_game, defines.events.on_player_removed}, function(event)
    if global.playerdata then
        clear_hovers(event.player_index)
        global.playerdata[event.player_index] = nil
    end
end)


local function create_temporary_blueprint(surface)
    local entity = surface.create_entity{ name='RailTools_dummy-item-storage', position={ x=0, y=0}}
    local inventory = entity.get_inventory(defines.inventory.chest)
    local item = inventory[1]
    item.set_stack("blueprint")

    return {
        entity = entity,
        item = item,
        destroy = entity.destroy,
    }
end

local place_signal

do
    local build_check_args = {
        build_check_type = defines.build_check_type.ghost_place,
        forced = true,
        position = { x = 0, y = 0 }
    }
    local bp_build_args = {
        force_build=true,
        skip_fog_of_war=true,
        direction=0
    }

    function place_signal(args)
        local name = args.name or 'rail-signal'
        local player = args.player
        local rail = args.rail
        local rail_direction = args.rail_direction
        local index = args.index
        local blueprint = args.blueprint
        local surface = rail.surface
        local entity
        local force = player.force
        local data = args.data or librail.get_rail_data(rail)
        local signal_offset = data.signals[rail_direction][index]
        if not signal_offset then return nil end
        local origin = rail.position
        local opposite_signal_offset
        if args.bidirectional then
            opposite_signal_offset = librail.opposite_signal_offsets[signal_offset.d]
        end

        local function can_place()
            if surface.can_place_entity(args) then
                return not librail.is_signal_blocked(surface, args.position, args.direction)
            end
            entity = surface.find_entity(name, args.position)
            if not entity then
                entity = surface.find_entity('entity-ghost', args.position)
                if not entity or entity.ghost_name ~= name then return end
            end
            -- TODO: Check for ghosts
            return (
                    entity.direction == args.direction and entity.force == force
                    and entity.position.x == args.position.x and entity.position.y == args.position.y
            )
        end

        args = build_check_args
        args.force = force
        args.name = name
        args.position.x = origin.x + signal_offset.x
        args.position.y = origin.y + signal_offset.y
        args.direction = signal_offset.d
        --log("Attempting placement at " .. serpent.line(args.position))
        if not can_place() then return end

        if opposite_signal_offset then
            args.position.x = args.position.x + opposite_signal_offset.x
            args.position.y = args.position.y + opposite_signal_offset.y
            args.direction = opposite_signal_offset.d
            if not can_place() then return nil end
        end

        local need_to_destroy_blueprint = false
        if not blueprint then
            blueprint = create_temporary_blueprint(surface)
            need_to_destroy_blueprint = true
        end

        local bp_entities = {{ entity_number=1, name=name, direction=signal_offset.d, position={ x=0, y=0 }}}
        bp_build_args.surface = surface
        bp_build_args.force = force
        bp_build_args.position = {x=origin.x + signal_offset.x, y=origin.y+signal_offset.y}
        blueprint.item.set_blueprint_entities(bp_entities)
        blueprint.item.build_blueprint(bp_build_args)

        if opposite_signal_offset then
            bp_entities[1].direction = opposite_signal_offset.d
            blueprint.item.set_blueprint_entities(bp_entities)
            bp_build_args.position.x = bp_build_args.position.x + opposite_signal_offset.x
            bp_build_args.position.y = bp_build_args.position.y + opposite_signal_offset.y
            blueprint.item.build_blueprint(bp_build_args)
        end
        if need_to_destroy_blueprint then blueprint.destroy() end
        return signal_offset
    end


    function place_signal_at_distance(player, origin_signal, train_length, max_distance)
        local origin_rails = librail.find_rail_for_signal(origin_signal)
        if #origin_rails == 0 then return end

        local blueprint = create_temporary_blueprint(player.surface)
        local place_args = {player=player, name='rail-signal', blueprint=blueprint}

        local origin_rail, distance, data
        local unvisited = {}
        local next_data, next_direction, next_rail

        local signal_types = librail.signal_entity_types_with_ghosts

        for i = 1, #origin_rails do
            origin_rail = origin_rails[i]
            data = origin_rail.rail_data
            distance = origin_rail.rail_data.length - origin_rail.signal.starts   -- Distance travelled by the end of this rail.
            if distance > train_length then  -- Signal spacing is set low enough and train is in a curve...
                place_args.rail = origin_rail.entity
                place_args.data = origin_rail.rail_data
                place_args.rail_direction = origin_rail.rail_direction
                place_args.index = 2    -- FIXME: Relies on certain assumptions that are *currently* true but may not always be.
                if place_signal(place_args) then
                    return
                end
            end
            -- Initial rail(s) to visit.
            for next_rail in librail.each_connected_rail(origin_rail.entity, origin_rail.rail_direction) do
                next_data = librail.get_rail_data(next_rail)
                next_direction = librail.chiral_directions[next_data.chirality == data.chirality][origin_rail.rail_direction]
                unvisited[#unvisited + 1] = {next_rail, next_direction, next_data, distance, train_length}
            end

        end

        local function visitor(rail, rail_direction, data, distance, target_distance)
            local signal = librail.get_first_signal(rail, rail_direction, data, signal_types)
            for index, offset in pairs(data.signals[rail_direction]) do
                if (not signal) or index < signal.index then
                    --log("visit unit=" .. rail.unit_number .. "; distance=" .. distance + offset.stops .. "; target=" .. target_distance)
                    if distance + offset.stops >= target_distance then
                        --find_nearest_signal_args.rail = rail
                        --find_nearest_signal_args.rail_direction = librail.opposite_direction[rail_direction]
                        --find_nearest_signal_args.signal_direction = rail_direction
                        --find_nearest_signal_args.added_distance = offset.stops
                        --local temp = librail.find_nearest_signal(find_nearest_signal_args)
                        --if temp then
                        --    log("Unit number: " .. temp.entity.unit_number .. "; distance=" .. temp.distance .. "; target=" .. target_distance)
                        --end
                        --log("Offset stops: " .. offset.stops .. ", starts: " .. offset.starts .. "; index=" .. index)
                        --if not temp or temp.distance >= train_length then
                        --log("placing signal.")
                        place_args.rail = rail
                        place_args.index = index
                        place_args.rail_direction = rail_direction
                        place_args.data = data
                        if place_signal(place_args) then
                            --log("signal placement succeeded.")
                            return true
                        end
                        --else
                        --    target_distance = target_distance + (train_length - temp.distance)
                        --end
                    end
                end
            end
            if signal then return true end
            return false, target_distance
        end

        librail.visit_rails{
            max_distance=max_distance,
            added_distance=distance,
            visit=visitor,
            unvisited=unvisited,
            signal_types=signal_types
        }
        blueprint.destroy()
    end


    function place_signals_until_branch(player, origin_signal, target_distance, max_distance, max_placed_signals)
        local origin_rails = librail.find_rail_for_signal(origin_signal)
        if #origin_rails ~= 1 then return end
        local bidirectional = librail.opposite_signal(origin_signal) and true or false

        local blueprint = create_temporary_blueprint(player.surface)
        local place_args = {
            player=player, blueprint=blueprint, name=bidirectional and 'rail-chain-signal' or 'rail-signal',
            bidirectional=bidirectional,
        }
        local offset
        local signals_placed = 0

        local origin_rail = origin_rails[1]
        local data = origin_rail.rail_data
        local distance = origin_rail.rail_data.length - origin_rail.signal.starts   -- Distance travelled by the end of this rail.
        if distance > target_distance then
            place_args.rail = origin_rail.entity
            place_args.data = origin_rail.rail_data
            place_args.rail_direction = origin_rail.rail_direction
            place_args.index = 2    -- FIXME: Relies on certain assumptions that are *currently* true but may not always be.
            offset = place_signal(place_args)
            if offset then
                signals_placed = signals_placed + 1
                distance = data.length - offset.starts
            end
        end

        local signal
        local iterator = librail.walk_to_crossing(origin_rail.entity, origin_rail.rail_direction)
        iterator()  -- Discard first

        for rail, rail_direction, _, data in iterator do
            --log(rail.unit_number)
            signal = librail.get_first_signal(rail, rail_direction, data)
            for index, offset in pairs(data.signals[rail_direction]) do
                --log("visit unit=" .. rail.unit_number .. "; distance=" .. distance + offset.stops .. "; target=" .. target_distance .. "; rd=" .. rail_direction .. "; chi=" .. data.chirality)
                if (not signal) or index < signal.index then
                    if distance + offset.stops >= target_distance then
                        --log("placing signal.")
                        place_args.rail = rail
                        place_args.index = index
                        place_args.rail_direction = rail_direction
                        place_args.data = data
                        offset = place_signal(place_args)
                        if offset then
                            signals_placed = signals_placed + 1
                            distance = -offset.starts

                            if signals_placed >= max_placed_signals then
                                player.print({"RailTools.too_many_signals_error", max_placed_signals})
                                goto done
                            end
                        end
                    end
                else
                    --log("Interupted by signal.")
                    --log(serpent.block(signal))
                    goto done
                end
            end
            distance = distance + data.length
            if distance > max_distance then
                player.print({"RailTools.max_distance_error"})
                goto done
            end
        end

        ::done::
        blueprint.destroy()
    end


    script.on_event("RailTools_place-end-of-block-signal", function(event)
        local player = game.players[event.player_index]

        if player.selected and is_rail_signal(player.selected) then
            local train_length = player.mod_settings["RailTools_train-length"].value
            local max_distance = settings.global["RailTools_max-search-distance"].value
            if train_length > max_distance then
                player.print({"RailTools.train_length_too_big_error"})
                train_length = max_distance
            end
            place_signal_at_distance(player, player.selected, train_length, max_distance)
            on_selected_entity_changed(player)
        end
    end)


    script.on_event("RailTools_signal-to-end-of-line", function(event)
        local player = game.players[event.player_index]

        if player.selected and is_signal(player.selected) then
            local train_length = player.mod_settings["RailTools_autoplace-interval"].value
            local max_distance = settings.global["RailTools_max-search-distance"].value
            if train_length > max_distance then
                player.print({"RailTools.autoplace_interval_too_big_error"})
                train_length = max_distance
            end
            if is_chain_signal(player.selected) and not librail.opposite_signal(player.selected) then return end
            place_signals_until_branch(
                    player, player.selected, train_length, max_distance,
                    settings.global["RailTools_max-placed-signals"].value
            )
            on_selected_entity_changed(player)
        end
    end)
end
