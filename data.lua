local data_util = require("__flib__.data-util")

data:extend({
  {
    type = "collision-layer",
    name = "belt-planner-layer",
  },
  {
    type = "trivial-smoke",
    name = "belt-planner-empty-smoke",
    animation = {
      filename = data_util.empty_image,
      size = { 1, 1 },
      frame_count = 8,
    },
    duration = 1,
  },
  {
    type = "selection-tool",
    name = "belt-planner-preview",
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[belt-planner]",
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
    flags = { "only-in-cursor", "spawnable" },
    hidden = true,
    draw_label_for_cursor_render = true,
    place_result = "belt-planner-dummy-transport-belt",
    collision_mask = {
      layers = {
        ["belt-planner-layer"] = true
      }
    }
  },
  {
    type = "selection-tool",
    name = "belt-planner",
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    stack_size = 1,
    subgroup = "tool",
    order = "c[automated-construction]-d[belt-planner]",
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
    flags = { "only-in-cursor", "spawnable" },
    hidden = true,
    draw_label_for_cursor_render = true,
    place_result = "belt-planner-dummy-entity",
    collision_mask = {
      layers = {
        ["belt-planner-layer"] = true
      }
    }
  },
  {
    type = "shortcut",
    name = "belt-planner-shortcut",
    action = "spawn-item",
    item_to_spawn = "belt-planner-preview",
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/transport-belt.png",
    small_icon_size = 64,
    associated_control_input = "belt-planner-shortcut"
  },
  {
    type = "simple-entity-with-force",
    name = "belt-planner-dummy-entity",
    flags = { "not-on-map", "player-creation" },
    hidden = false,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    collision_mask = { layers = {} },
    selectable_in_game = false,
    picture = {
      filename = "__core__/graphics/empty.png",
      size = 1
    },
    created_smoke = { smoke_name = "belt-planner-empty-smoke" } --- @diagnostic disable-line
  },
  {
    type = "custom-input",
    name = "belt-planner-flip-orientation",
    key_sequence = "F",
    order = "a[mod]-b[belt-planner-flip]",
  },
  {
    type = "transport-belt",
    name = "belt-planner-dummy-transport-belt",
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    flags = { "placeable-neutral", "player-creation" },
    minable = { mining_time = 0.1 },
    speed = 1,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    belt_animation_set = data.raw["transport-belt"]["transport-belt"].belt_animation_set,
    fast_replaceable_group = "transport-belt",
    created_smoke = { smoke_name = "belt-planner-empty-smoke" } --- @diagnostic disable-line
  },
  {
    type = "sprite",
    name = "belt-planner-chevron",
    filename = "__belt-planner__/graphics/chevron.png",
    size = 64,
    priority = "extra-high-no-scale"
  }
  -- {
  --   type = "simple-entity-with-force",
  --   name = "bp-transport-belt",
  --   icon = "__base__/graphics/icons/transport-belt.png",
  --   icon_size = 64,
  --   flags = { "placeable-neutral", "player-creation" },
  --   collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
  --   selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } },
  --   picture = {
  --     layers = {
  --       {
  --         filename = "__base__/graphics/entity/transport-belt/transport-belt.png",
  --         priority = "extra-high",
  --         width = 64,
  --         height = 64,
  --         frame_count = 1,
  --         hr_version = {
  --           filename = "__base__/graphics/entity/transport-belt/hr-transport-belt.png",
  --           priority = "extra-high",
  --           width = 128,
  --           height = 128,
  --           scale = 0.5,
  --           frame_count = 1
  --         }
  --       }
  --     }
  --   },
  --   minable = { mining_time = 0.1, result = nil }
  -- }
})
