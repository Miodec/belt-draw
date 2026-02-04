data:extend({
  {
    type = "collision-layer",
    name = "belt-draw-layer",
  },
  {
    type = "trivial-smoke",
    name = "belt-draw-empty-smoke",
    animation = {
      filename = "__core__/graphics/empty.png",
      size = { 1, 1 },
      frame_count = 8,
    },
    duration = 1,
  },
  {
    type = "selection-tool",
    name = "belt-draw-preview",
    icon = "__base__/graphics/icons/transport-belt.png",
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
    flags = { "only-in-cursor", "spawnable" },
    hidden = true,
    draw_label_for_cursor_render = true,
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
    icon = "__base__/graphics/icons/transport-belt.png",
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
    flags = { "only-in-cursor", "spawnable" },
    hidden = true,
    draw_label_for_cursor_render = true,
    place_result = "belt-draw-dummy-entity",
    collision_mask = {
      layers = {
        ["belt-draw-layer"] = true
      }
    }
  },
  {
    type = "shortcut",
    name = "belt-draw-shortcut",
    action = "spawn-item",
    item_to_spawn = "belt-draw-preview",
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/transport-belt.png",
    small_icon_size = 64,
    associated_control_input = "belt-draw-shortcut"
  },
  {
    type = "simple-entity-with-force",
    name = "belt-draw-dummy-entity",
    flags = { "not-on-map", "player-creation" },
    hidden = false,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    collision_mask = { layers = {} },
    selectable_in_game = false,
    picture = {
      filename = "__core__/graphics/empty.png",
      size = 1
    },
    created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line
  },
  {
    type = "custom-input",
    name = "belt-draw-flip-orientation",
    key_sequence = "F",
    order = "a[mod]-b[belt-draw-flip]",
  },
  {
    type = "custom-input",
    name = "belt-draw-anchor",
    key_sequence = "R",
    order = "a[mod]-b[belt-draw-anchor]",
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
    fast_replaceable_group = "transport-belt",
    created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line
  },
  {
    type = "sprite",
    name = "belt-draw-above",
    filename = "__belt-draw__/graphics/above.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "sprite",
    name = "belt-draw-under",
    filename = "__belt-draw__/graphics/under.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "sprite",
    name = "belt-draw-anchor",
    filename = "__belt-draw__/graphics/anchor2.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "sprite",
    name = "belt-draw-entryexit",
    filename = "__belt-draw__/graphics/entryexit.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "sprite",
    name = "belt-draw-blocked",
    filename = "__belt-draw__/graphics/blocked.png",
    size = 64,
    priority = "extra-high-no-scale"
  },
  {
    type = "sprite",
    name = "belt-draw-empty",
    filename = "__core__/graphics/factorio.png",
    size = 64,
    priority = "extra-high-no-scale"
  }
})
