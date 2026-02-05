return {
  {
    type = "shortcut",
    name = "belt-draw-shortcut",
    action = "spawn-item",
    item_to_spawn = "belt-draw-preview",
    icon = "__belt-draw__/graphics/shortcut.png",
    icon_size = 128,
    small_icon = "__belt-draw__/graphics/shortcut.png",
    small_icon_size = 128,
    associated_control_input = "belt-draw-shortcut"
  },
  {
    type = "selection-tool",
    name = "belt-draw-preview",
    icon = "__belt-draw__/graphics/shortcut.png",
    icon_size = 64,
    stack_size = 1,
    subgroup = "tool",
    mouse_cursor = "arrow",
    order = "c[automated-construction]-d[belt-draw]",
    select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    alt_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    reverse_select = {
      mode = "deconstruct",
      border_color = { a = 0, r = 1 },
      cursor_box_type = "not-allowed",
    },
    alt_reverse_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    super_forced_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    place_result = "belt-draw-dummy-transport-belt",
    collision_mask = {
      layers = {
        ["belt-draw-layer"] = true
      }
    }
  },
  {
    type = "selection-tool",
    name = "belt-draw",
    icon = "__core__/graphics/icons/alerts/ammo-icon-red.png",
    mouse_cursor = "arrow",
    icon_size = 64,
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[belt-draw]",
    select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    alt_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    reverse_select = {
      mode = "deconstruct",
      border_color = { a = 0, r = 1 },
      cursor_box_type = "not-allowed",
    },
    alt_reverse_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    super_forced_select = {
      mode = "nothing",
      border_color = { a = 0 },
      cursor_box_type = "not-allowed",
    },
    flags = { "only-in-cursor", "spawnable", "not-stackable" },
    hidden = true,
    place_result = "belt-draw-dummy-entity",
    collision_mask = {
      layers = {
        ["belt-draw-layer"] = true
      }
    }
  },
  {
    type = "transport-belt",
    name = "belt-draw-dummy-transport-belt",
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.1 },
    speed = 1,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    belt_animation_set = data.raw["transport-belt"]["transport-belt"].belt_animation_set,
    hidden_in_factoriopedia = true,
    fast_replaceable_group = "transport-belt",
    created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line
  },
}
