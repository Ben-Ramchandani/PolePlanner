function table.contains(array, element)
    for k, e in pairs(array) do
        if e == element then
            return k
        end
    end
    return false
end

function table.array_clone(org)
    return {table.unpack(org)}
end

function table.clone(org)
    local copy = {}
    for k, v in pairs(org) do
        copy[k] = v
    end
    return copy
end

function table.map(t, func)
    local new_table = {}
    for i, v in ipairs(t) do
        table.insert(new_table, func(v))
    end
    return new_table
end

function math.clamp(x, a, b)
    if x < a then
        return a
    elseif x > b then
        return b
    else
        return x
    end
end

function table.combine(a, b)
    if not a then return b elseif not b then return a else
        for k, v in pairs(b) do
            a[k] = v
        end
    end
    return a
end

function find_collision_bounding_box(entities)
    local top = math.huge
    local left = math.huge
    local right = -math.huge
    local bottom = -math.huge
    
    for k, entity in pairs(entities) do
        if entity.valid then
            if entity.bounding_box then
                local collision_box = entity.bounding_box
                top = math.min(top, collision_box.left_top.y)
                left = math.min(left, collision_box.left_top.x)
                bottom = math.max(bottom, collision_box.right_bottom.y)
                right = math.max(right, collision_box.right_bottom.x)
            else
                top = math.min(top, entity.position.y)
                left = math.min(left, entity.position.x)
                bottom = math.max(bottom, entity.position.y)
                right = math.max(right, entity.position.x)
            end
        end
    end
    return {left_top = {x = math.floor(left), y = math.floor(top)}, right_bottom = {x = math.ceil(right), y = math.ceil(bottom)}}
end

function make_area(left, top, right, bottom)
    return {left_top = {x = left, y = top}, right_bottom = {x = right, y = bottom}}
end
