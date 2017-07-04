PB_CONF = {
    pole = "medium-electric-pole",
    --pole = "substation",
    run_over_multiple_ticks = true
}

function set_up_config(conf)
    local prototype = game.entity_prototypes[conf.pole]
    conf.wire_distance = prototype.max_wire_distance
    conf.supply_distance = prototype.supply_area_distance
    conf.prototype = prototype
    local size = math.ceil(prototype.collision_box.right_bottom.x - prototype.collision_box.left_top.x)
    if not (size == math.ceil(prototype.collision_box.right_bottom.y - prototype.collision_box.left_top.y)
            and prototype.collision_box.right_bottom.x == - prototype.collision_box.left_top.x
            and prototype.collision_box.right_bottom.y == - prototype.collision_box.left_top.y) then
        game.print("PoleBuilder: Electric pole is not square, this may cause problems.")
    end
    if size % 2 == 1 then
        conf.offset = 0.5
        conf.collision_left = math.floor(prototype.collision_box.left_top.x + 0.5)
        conf.collision_top = math.floor(prototype.collision_box.left_top.y + 0.5)
        conf.collision_right = math.ceil(prototype.collision_box.right_bottom.x - 0.5)
        conf.collision_bottom = math.ceil(prototype.collision_box.right_bottom.y - 0.5)
    else
        conf.offset = 0
        conf.collision_left = math.floor(prototype.collision_box.left_top.x)
        conf.collision_top = math.floor(prototype.collision_box.left_top.y)
        conf.collision_right = math.ceil(prototype.collision_box.right_bottom.x)
        conf.collision_bottom = math.ceil(prototype.collision_box.right_bottom.y)
        game.print(conf.collision_right)
    end

    return conf
end


function get_config(player)
    global.PB_CONF = global.PB_CONF or PB_CONF
    global.PB_CONF_overrides = global.PB_CONF_overrides or {}
    local conf = table.combine(table.clone(global.PB_CONF), global.PB_CONF_overrides[player.index])
    return set_up_config(conf)
end

function set_config(player, new_conf) -- Override the configuration file on a per save basis.
    if new_conf and type(new_conf) == "table" then
        global.PB_CONF_overrides[player.index] = table.combine(new_conf, global.PB_CONF_overrides[player.index])
    end
end

function set_config_global(new_conf)
    if new_conf and type(new_conf) == "table" then
        global.PB_CONF = table.combine(new_conf, global.PB_CONF)
    end
end

function reset_all()
    global.PB_CONF_overrides = {}
end

remote.add_interface("PoleBuilder", {config = set_config_global, reset = reset_all})


function init_config()
    if not (global.PB_CONF and game.entity_prototypes[global.PB_CONF.pole]) then
        global.PB_CONF = PB_CONF
    end

    if global.PB_CONF_overrides then
        for k, v in pairs(global.PB_CONF_overrides) do
            if v.pole and not game.entity_prototypes[v.pole] then
                global.PB_CONF_overrides[k] = {}
            end
        end
    else
         global.OB_CONF_overrides = {}
    end
end

table.insert(ON_INIT, init_config)
