local distance_text = table.deepcopy(data.raw['flying-text']['flying-text'])
distance_text.name = 'RailTools_distance-text'
distance_text.speed = 0
distance_text.text_alignment = 'center'

data:extend {
    distance_text,
    {
        type = "simple-entity",
        name = "RailTools_bad-signal-indicator",
        flags = { "not-on-map", "not-blueprintable", "not-deconstructable", "not-flammable" },
        render_layer = "selection-box",
        picture = {
            width = 64,
            height = 64,
            scale = 0.5,
            filename = "__core__/graphics/arrows/underground-lines-remove.png",
        },
        collision_box = nil,
        selectable_in_game = false,
        tile_width = 1,
        tile_height = 1,
    },
    {
        type = "container",
        name = "RailTools_dummy-item-storage",
        --icon = "__base__/graphics/icons/wooden-chest.png",
        --icon_size = 32,
        --flags = { "placeable-neutral", "player-creation" },
        --minable = { mining_time = 1, result = "wooden-chest" },
        --max_health = 100,
        --corpse = "small-remnants",
        collision_box = { { 0, 0 }, { 0, 0 } },
        selection_box = { { 0, 0 }, { 0, 0 } },
        inventory_size = 1,
        --open_sound = { filename = "__base__/sound/wooden-chest-open.ogg" },
        --close_sound = { filename = "__base__/sound/wooden-chest-close.ogg" },
        --vehicle_impact_sound = { filename = "__base__/sound/car-wood-impact.ogg", volume = 1.0 },
        picture = {
            filename = "__base__/graphics/entity/wooden-chest/wooden-chest.png",
            priority = "extra-high",
            width = 46,
            height = 33,
            shift = { 0.25, 0.015625 }
        },
        --circuit_wire_connection_point = circuit_connector_definitions["chest"].points,
        --circuit_connector_sprites = circuit_connector_definitions["chest"].sprites,
        --circuit_wire_max_distance = default_circuit_wire_max_distance
    },
}
