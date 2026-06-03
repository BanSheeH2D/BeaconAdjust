-- Inteligentna funkcja szukająca słowa w nazwie jakości
local function get_extra_slots(q_name)
    local q = string.lower(q_name)
    if q:find("singularity") then return 18 end
    if q:find("celestial") then return 9 end
    if q:find("mythic") then return 7 end
    if q:find("legendary") then return 5 end
    if q:find("epic") then return 3 end
    if q:find("rare") then return 2 end
    if q:find("uncommon") then return 1 end
    return 0
end

if data.raw["beacon"] then
    local pct_steps = {25, 50, 75, 100, 125, 150, 175, 200}

    for name, proto in pairs(data.raw["beacon"]) do
        if not name:find("^brc%-") then
            -- KROK 1: Tworzymy "listę zaproszonych" - wszystkie warianty tego beacona
            local pastable_list = {name}
            
            for _, pct in ipairs(pct_steps) do
                for q_name, _ in pairs(data.raw["quality"]) do
                    if not (pct == 100 and q_name == "normal") then
                        table.insert(pastable_list, "brc-" .. name .. "-" .. pct .. "-" .. q_name)
                    end
                end
            end
            
            -- Przypisujemy listę do bazowego beacona
            proto.additional_pastable_entities = pastable_list
            if not proto.fast_replaceable_group then proto.fast_replaceable_group = "beacon" end
            
            -- KROK 2: Tworzymy warianty moda
            for _, pct in ipairs(pct_steps) do
                for q_name, _ in pairs(data.raw["quality"]) do
                    if not (pct == 100 and q_name == "normal") then
                        local b = table.deepcopy(proto)
                        b.name = "brc-" .. name .. "-" .. pct .. "-" .. q_name
                        b.localised_name = {"entity-name." .. name}
                        
                        local m = pct / 100
                        b.supply_area_distance = math.max(1, math.floor((proto.supply_area_distance or 3) * m))
                        b.distribution_effectivity = (proto.distribution_effectivity or 0.5) / m
                        
                        b.module_slots = (proto.module_slots or 2) + get_extra_slots(q_name)
                        
                        b.flags = {"placeable-player", "player-creation", "not-on-map"}
                        b.minable = {mining_time = (proto.minable and proto.minable.mining_time) or 0.1, result = name}
                        b.placeable_by = {item = name, count = 1}
                        
                        -- FIX: To omija blokadę silnika gry i pozwala na kopiowanie Shift+Klik!
                        b.additional_pastable_entities = pastable_list
                        b.fast_replaceable_group = proto.fast_replaceable_group
                        
                        data:extend({b})
                    end
                end
            end
        end
    end
end