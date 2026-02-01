data:extend({
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
    flags = { "only-in-cursor", "spawnable" },
    hidden = true,
    draw_label_for_cursor_render = true,
    place_result = "bp-dummy-entity"
  },
  {
    type = "shortcut",
    name = "belt-planner",
    action = "spawn-item",
    item_to_spawn = "belt-planner",
    icon = "__base__/graphics/icons/transport-belt.png",
    icon_size = 64,
    small_icon = "__base__/graphics/icons/transport-belt.png",
    small_icon_size = 64,
    associated_control_input = "belt-planner-shortcut"
  },
  {
    type = "simple-entity-with-force",
    name = "bp-dummy-entity",
    flags = { "not-on-map", "player-creation" },
    hidden = false,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    collision_mask = { layers = {} },
    selectable_in_game = false,
    picture = {
      filename = "__core__/graphics/empty.png",
      size = 1
    }
  },
  {
    type = "custom-input",
    name = "belt-planner-flip-orientation",
    key_sequence = "R",
    order = "a[mod]-b[belt-planner-flip]",
  },
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
