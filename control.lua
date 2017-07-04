require("on_init")
require("util")
require("config")

function can_place_pole(state, position)
    position = abs_position(state, position)
    local left = position.x + state.conf.prototype.collision_box.left_top.x
    local right = position.x + state.conf.prototype.collision_box.right_bottom.x
    local top = position.y + state.conf.prototype.collision_box.left_top.y
    local bottom = position.y + state.conf.prototype.collision_box.right_bottom.y
    for i = math.floor(left), math.ceil(right - 1) do
        for j = math.floor(top), math.ceil(bottom - 1) do
            local tile_prototype = state.surface.get_tile(i, j).prototype
            if tile_prototype.collision_mask and tile_prototype.collision_mask["water-tile"] then
                return false
            end
        end
    end
    local entities = state.surface.find_entities_filtered({area = {{left, top}, {right, bottom}}})
    for i, entity in ipairs(entities) do
        local prototype = entity.prototype
        if entity.name == "entity-ghost" and entity.ghost_type ~= "tile" then
            prototype = entity.ghost_prototype
        end
        if not entity.to_be_deconstructed(state.force) and prototype.collision_box and prototype.collision_mask and prototype.collision_mask["object-layer"] and entity.name ~= "player" and entity.type ~= car then
            return false
        end
    end
    return true
end

function place_blueprint(surface, data)
    data.inner_name = data.name
    data.name = "entity-ghost"
    data.expires = false
    surface.create_entity(data)
end

function abs_position(state, position)
    return {x = position.x + state.left + state.conf.offset, y = position.y + state.top + state.conf.offset}
end

function rel_position(state, position)
    return {x = position.x - state.left - state.conf.offset, y = position.y - state.top - state.conf.offset}
end

function rel_position_true(state, position)
    return {x = position.x - state.left, y = position.y - state.top}
end

function place_pole_enitity_counts(state, position)
    for i, wrapper in ipairs(state.area[position.x][position.y].reachable_entities) do
        if wrapper.unpowered then
            wrapper.unpowered = nil
            state.entity_count = state.entity_count - 1
        end
    end
end


function place_pole_collision_adjustment(state, position)
    for i = math.max(state.conf.collision_left + position.x, 1),math.min(state.conf.collision_right + position.x, state.width) do
        for j = math.max(state.conf.collision_top + position.y, 1),math.min(state.conf.collision_bottom + position.y, state.height) do
            state.area[i][j] = false
        end
    end
end

function reachability_any_pole(state, rel_position, wire_distance)
    local left = math.floor(math.max(rel_position.x - wire_distance, 1))
    local top = math.floor(math.max(rel_position.y - wire_distance, 1))
    local right = math.ceil(math.min(rel_position.x + wire_distance, state.width))
    local bottom = math.ceil(math.min(rel_position.y + wire_distance, state.height))
    for i=left,right do
        for j=top,bottom do
            if state.area[i][j] and distance(rel_position.x, rel_position.y, i, j) <= wire_distance then
                state.area[i][j].reachable = true
            end
        end
    end
end


function place_pole_reachability(state, position)
    reachability_any_pole(state, position, state.conf.wire_distance)
end

function place_pole(state, position)
    local data = {name = state.conf.pole, position = abs_position(state, position), force = state.force}
    
    place_blueprint(state.surface, data)

    place_pole_enitity_counts(state, position)
    place_pole_collision_adjustment(state, position)
    place_pole_reachability(state, position)

    table.insert(state.pole_positions, position)
    return true
end

function connected(pole_position, pole_radius, entity_bounding_box)
    return entity_bounding_box.left_top.x < pole_position.x + pole_radius
        and entity_bounding_box.right_bottom.x > pole_position.x - pole_radius
        and entity_bounding_box.left_top.y < pole_position.y + pole_radius
        and entity_bounding_box.right_bottom.y > pole_position.y - pole_radius
end

function set_up_area(state)
    if state.count <= state.width then
        table.insert(state.area, {})
        local i = state.count
        for j=1,state.height do
            table.insert(state.area[i], {reachable_entities = {}})
        end
        return true
    else
        return false
    end
end

function filter_entities(state)
    local powered_entities = {}
    for k, entity in pairs(state.entities) do
        if entity.valid and entity.prototype.electric_energy_source_prototype then
            table.insert(powered_entities, {bounding_box = entity.bounding_box})
        elseif entity.valid and entity.type == "electric-pole" and not entity.to_be_deconstructed(state.force) then
            table.insert(state.initial_poles, {prototype = entity.prototype, abs_position = entity.position})
        elseif entity.valid and entity.name == "entity-ghost" and entity.ghost_type ~= "tile" then
            if entity.ghost_prototype.electric_energy_source_prototype then
                table.insert(powered_entities, {bounding_box = entity.bounding_box})
            elseif entity.ghost_type == "electric-pole" then
                table.insert(state.initial_poles, {prototype = entity.ghost_prototype, abs_position = entity.position})
            end
        end
    end
    if #powered_entities == 0 then
        state.player.print("No entities found.")
        state.stage = 1000
    end
    state.entities = powered_entities
    state.entity_count = #powered_entities
    return false
end

function initial_poles(state)

    if state.count <= #state.initial_poles then

        local position = state.initial_poles[state.count].abs_position
        local prototype = state.initial_poles[state.count].prototype
        local x = position.x
        local y = position.y
        local i = 1
        while i <= #state.entities do
            if connected(position, prototype.supply_area_distance, state.entities[i].bounding_box) then
                table.remove(state.entities, i)
                state.entity_count = state.entity_count - 1
            else
                i = i + 1
            end
        end
        local rel_position = rel_position_true(state, position)
        reachability_any_pole(state, rel_position, math.min(prototype.max_wire_distance, state.conf.wire_distance))
        table.insert(state.pole_positions, rel_position)
        return true
    else
        if state.entity_count == 0 then
            state.player.print("All entities were already powered.")
            state.stage = 1000
        end
        return false
    end
end

function initialise_counts(state)
    if state.count <= #state.entities then
        local entity = state.entities[state.count]
        
        local left = math.clamp(math.floor(entity.bounding_box.left_top.x       - state.left    - state.conf.supply_distance - state.conf.offset + 1), 1, state.width)
        local right = math.clamp(math.ceil(entity.bounding_box.right_bottom.x   - state.left    + state.conf.supply_distance - state.conf.offset - 1), 1, state.width)
        local top = math.clamp(math.floor(entity.bounding_box.left_top.y        - state.top     - state.conf.supply_distance - state.conf.offset + 1), 1, state.height)
        local bottom = math.clamp(math.ceil(entity.bounding_box.right_bottom.y  - state.top     + state.conf.supply_distance - state.conf.offset - 1), 1, state.height)

        local wrapper = {unpowered = true}

        for i=left,right do
            for j=top,bottom do
                local pos = state.area[i][j]
                if pos then
                    table.insert(pos.reachable_entities, wrapper)
                end
            end
        end
        return true
    else
        return false
    end
end

function collision_check(state)
    if state.count <= state.width then
        for j=1,state.height do
            if not can_place_pole(state, {x = state.count, y = j}) then
                state.area[state.count][j] = false
            end
        end
        return true
    else
        return false
    end
end

function count_entities(state, reachable_entities)
    local i = 1
    local count = 0
    while i <= #reachable_entities do
        if reachable_entities[i].unpowered then
            count = count + 1
            i = i + 1
        else
            table.remove(reachable_entities, i)
        end
    end
    return count
end

function place_initial_pole(state)
    if #state.pole_positions == 0 then
        local max_position = find_best_position(state, true)
        if max_position then
            place_pole(state, max_position)
        else
            state.stage = 1000
            state.player.print("Nowhere to place pole, but " .. state.entity_count .. " entities remain unpowered.")
        end
    end
    return false
end

function distance(x1, y1, x2, y2)
    return math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2))
end

function distance_position(pos1, pos2)
    return distance(pos1.x, pos1.y, pos2.x, pos2.y)
end

function find_best_position(state, ignore_reachable)
    local max_count = 0
    local max_position = nil
    for x, v in ipairs(state.area) do
        for y, pos in ipairs(v) do
            if pos and (pos.reachable or ignore_reachable) then
                if #pos.reachable_entities > max_count then
                    local count = count_entities(state, pos.reachable_entities)
                    if count > max_count then
                        max_count = count
                        max_position = {x = x, y = y}
                    end
                end
            end
        end
    end
    return max_position
end

function find_closest_position(state, position)
    local best_dist = math.huge
    local best_position = nil
    for x, v in ipairs(state.area) do
        for y, cell in ipairs(v) do
            if cell and cell.reachable then
                local cell_pos = {x = x, y = y}
                local dist = distance_position(cell_pos, position)
                if dist < best_dist then
                    best_position = cell_pos
                    best_dist = dist
                end
            end
        end
    end
    return best_position
end

function find_smallest_distance(from_list, to)
    local closest_distance = math.huge
    for i, pos in ipairs(from_list) do
        local dist = distance_position(to, pos) 
        if dist < closest_distance then
            closest_distance = dist
        end
    end
    return closest_distance
end

function join_networks(state)
    if not state.best_distance then
        state.best_distance = find_smallest_distance(state.pole_positions, state.aim_for_position)
    end

    local best_position = find_closest_position(state, state.aim_for_position)
    if best_position then
        local dist = distance_position(best_position, state.aim_for_position)
        if dist < state.best_distance then
            place_pole(state, best_position)
            state.best_distance = dist
            return true
        else
            return false
        end
    else
        return false
    end

end


function place_best_pole(state)
    if state.placement_stage == "searching" then
        local max_position = find_best_position(state, false)
        if max_position then
            place_pole(state, max_position)
        else
            if state.entity_count == 0 then
                return false
            else
                state.placement_stage = "blocked"
            end
        end
    elseif state.placement_stage == "blocked" then
        local max_position = find_best_position(state, true)
        if max_position then
            state.aim_for_position = max_position
            state.placement_stage = "joining"
        else
            state.player.print("Nowhere to place pole, but " .. state.entity_count .. " entities remain unpowered.")
            return false
        end
    elseif state.placement_stage == "joining" then

        if join_networks(state) then
            if state.best_distance <= state.conf.wire_distance then
                state.best_distance = nil
                state.aim_for_position = nil
                state.placement_stage = "searching"
            end
        else
            state.player.print("Giving up on connecting poles. " .. state.entity_count .. " entities remain unpowered and the poles are not fully connected.")
            return false
        end
    end
    return true
end

stages = {set_up_area, filter_entities, initial_poles, initialise_counts, collision_check, place_initial_pole, place_best_pole}

function tick(state)

    if state.count > 1000 then
        state.player.print("Aborting in stage " .. state.stage .. ", count too high.")
        state.stage = 1000
        return
    end
    if stages[state.stage](state) then
        state.count = state.count + 1
    else
        state.stage = state.stage + 1
        state.count = 1
    end
end


function on_selected_area(event)
    local player = game.players[event.player_index]
    local force = player.force
    local surface = player.surface
    local conf = get_config(player)
    local top = math.floor(event.area.left_top.y) - 1
    local left = math.floor(event.area.left_top.x) - 1
    local bottom = math.ceil(event.area.right_bottom.y)
    local right = math.ceil(event.area.right_bottom.x)


    local state = {
        surface = surface,
        player = player,
        force = force,
        top = top,
        bottom = bottom,
        left = left,
        right = right,
        width = right - left,
        height = bottom - top,
        area = {},
        entities = event.entities,
        entity_count = nil,
        pole_positions = {},
        initial_poles = {},
        placement_stage = "searching",
        stage = 1,
        count = 1,
        conf = conf
    }

    if conf.run_over_multiple_ticks then
        register(state)
    else
        while state.stage <= #stages do
            tick(state)
        end
    end
end

--[[  On tick  ]]--

function register(state)
    if not global.PB_states then
        global.PB_states = {state}
    else
        table.insert(global.PB_states, state)
    end
    if #global.PB_states == 1 then
        script.on_event(defines.events.on_tick, on_tick)
    end
end

function on_tick(event)
    -- if(event.tick % 60 == 0) then game.print("Handler running.") end
    if #global.PB_states == 0 then
        script.on_event(defines.events.on_tick, nil)
    else
        -- Manually loop because we're removing items.
        local i = 1
        while i <= #global.PB_states do
            local state = global.PB_states[i]
            if state.stage <= #stages then
                tick(state)
                i = i + 1
            else
                table.remove(global.PB_states, i)
            end
        end
    end
end

function on_load()
    if global.PB_states and #global.PB_states > 0 then
        script.on_event(defines.events.on_tick, on_tick)
    end
end

script.on_load(on_load)

function clear_running_state()
    global.PB_states = {}
end

table.insert(ON_INIT, clear_running_state)

script.on_event(
    defines.events.on_player_selected_area,
    function(event)
        if event.item == "pole-builder" then
            on_selected_area(event)
        end
    end
)
