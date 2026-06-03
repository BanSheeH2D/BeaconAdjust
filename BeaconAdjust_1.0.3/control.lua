local pct_steps = {25, 50, 75, 100, 125, 150, 175, 200}

script.on_init(function() 
    storage.open = {} 
    storage.pending_swaps = {}
end)

local function get_name_data(name)
    local base, pct, qual = name:match("^brc%-(.+)%-(%d+)%-(.+)$")
    return base, tonumber(pct), qual
end

local function swap_beacon(player, entity, new_pct)
    local base, _, qual = get_name_data(entity.name)
    base = base or entity.name
    qual = qual or entity.quality.name
    
    local new_name = (new_pct == 100 and qual == "normal") and base or ("brc-" .. base .. "-" .. new_pct .. "-" .. qual)
    
    if entity.name == new_name or not prototypes.entity[new_name] then return entity end

    local inv = entity.get_module_inventory()
    local modules = {}
    if inv then
        for i = 1, #inv do
            if inv[i].valid_for_read then table.insert(modules, {name = inv[i].name, count = inv[i].count, quality = inv[i].quality}) end
        end
    end

    local old_health = entity.health
    local old_last_user = entity.last_user

    local new_ent = entity.surface.create_entity({
        name = new_name, 
        position = entity.position, 
        direction = entity.direction, 
        force = entity.force, 
        quality = qual
    })
    
    if not new_ent then return entity end

    if old_health then new_ent.health = old_health end
    new_ent.last_user = old_last_user

    local new_inv = new_ent.get_module_inventory()
    if new_inv then
        for _, m in ipairs(modules) do new_inv.insert(m) end
    end
    
    entity.destroy()
    return new_ent
end

local build_events = {
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.on_space_platform_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive
}

script.on_event(build_events, function(event)
    local entity = event.entity or event.destination
    if not (entity and entity.valid and entity.type == "beacon") then return end
    
    local _, encoded_pct, encoded_qual = get_name_data(entity.name)
    local actual_qual = entity.quality.name
    
    if not entity.name:match("^brc%-") and actual_qual ~= "normal" then
        swap_beacon(nil, entity, 100)
    elseif entity.name:match("^brc%-") and encoded_qual ~= actual_qual then
        swap_beacon(nil, entity, encoded_pct or 100)
    end
end)

script.on_configuration_changed(function()
    storage.open = storage.open or {}
    storage.pending_swaps = storage.pending_swaps or {}
    for _, surface in pairs(game.surfaces) do
        for _, e in pairs(surface.find_entities_filtered{type = "beacon"}) do
            if e.valid and not e.name:match("^brc%-") and e.quality.name ~= "normal" then
                swap_beacon(nil, e, 100)
            end
        end
    end
end)

script.on_event(defines.events.on_gui_opened, function(event)
    if not (event.entity and event.entity.type == "beacon") then return end
    local player = game.get_player(event.player_index)
    
    if player.gui.relative["brc_window"] then player.gui.relative["brc_window"].destroy() end
    
    local window = player.gui.relative.add{
        type = "frame", name = "brc_window", 
        anchor = {gui = defines.relative_gui_type.beacon_gui, position = defines.relative_gui_position.right},
        caption = {"brc-gui.window-title"}
    }
    
    local flow = window.add{type = "flow", direction = "vertical"}
    local slider_flow = flow.add{type = "flow", direction = "horizontal"}
    
    local slider = slider_flow.add{type = "slider", name = "brc_slider", minimum_value = 1, maximum_value = #pct_steps, discrete_slider = true}
    
    local _, pct, _ = get_name_data(event.entity.name)
    local current_pct = pct or 100
    for i, v in ipairs(pct_steps) do if v == current_pct then slider.slider_value = i end end
    
    flow.add{type = "label", name = "brc_label", caption = {"brc-gui.current-range", current_pct}}
    
    storage.open = storage.open or {}
    storage.pending_swaps = storage.pending_swaps or {}
    
    storage.open[event.player_index] = event.entity
    storage.pending_swaps[event.player_index] = nil
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
    if event.element.name ~= "brc_slider" then return end
    
    local new_pct = pct_steps[event.element.slider_value]
    
    local label = event.element.parent.parent.brc_label
    label.caption = {"brc-gui.range-after-close", new_pct}
    
    storage.pending_swaps = storage.pending_swaps or {}
    storage.pending_swaps[event.player_index] = new_pct
end)

script.on_event(defines.events.on_gui_closed, function(event)
    storage.open = storage.open or {}
    storage.pending_swaps = storage.pending_swaps or {}
    
    local player = game.get_player(event.player_index)
    local entity = storage.open[event.player_index]
    local pending_pct = storage.pending_swaps[event.player_index]
    
    if entity and entity.valid and pending_pct then
        swap_beacon(player, entity, pending_pct)
    end
    
    if player and player.gui.relative["brc_window"] then player.gui.relative["brc_window"].destroy() end
    
    storage.open[event.player_index] = nil
    storage.pending_swaps[event.player_index] = nil
end)

-- Kopiowanie ustawień (Shift + Prawy Click -> Shift + Lewy Click)
script.on_event(defines.events.on_entity_settings_pasted, function(event)
    local src = event.source
    local dest = event.destination
    
    if not (src and src.valid and src.type == "beacon") then return end
    if not (dest and dest.valid and dest.type == "beacon") then return end
    
    local _, src_pct, _ = get_name_data(src.name)
    local target_pct = src_pct or 100
    
    local _, dest_pct, _ = get_name_data(dest.name)
    local current_dest_pct = dest_pct or 100
    
    if target_pct ~= current_dest_pct then
        local player = event.player_index and game.get_player(event.player_index)
        swap_beacon(player, dest, target_pct)
    end
end)