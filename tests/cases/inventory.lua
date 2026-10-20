-- Inventory drawing: from the inventory, within reach, not in map view. Builds real belts

local h = require("tests.helpers")
local east, west = defines.direction.east, defines.direction.west

---@type TestCase[]
return {
  {
    name = "inventory drawing builds real belts from the inventory",
    setup = function(ctx)
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -2.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-2.5, 1.5)) do
          h.expect(ctx, position, "transport-belt", east)
          h.expect_none(ctx, position, "transport-belt", true)
        end
        h.check_equal(15, h.count(ctx, "transport-belt"), "belts left in the inventory")
      end)
    ),
  },
  {
    name = "inventory drawing over identical belts leaves them alone",
    setup = function(ctx)
      ctx.data.belts = {}
      for _, position in ipairs(h.row(-1.5, 1.5)) do
        table.insert(ctx.data.belts, h.place(ctx, "transport-belt", position, east))
      end
      ctx.data.units = h.unit_numbers(ctx.data.belts)
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -1.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        for i, position in ipairs(h.row(-1.5, 1.5)) do
          local belt = h.expect(ctx, position, "transport-belt", east)
          h.check_equal(ctx.data.units[i], belt.unit_number, "belt at " .. position[1] .. " (same entity)")
          h.expect_none(ctx, position, "transport-belt", true)
        end
        h.check_equal(20, h.count(ctx, "transport-belt"), "belts in the inventory")
      end)
    ),
  },
  {
    name = "inventory drawing rotates same tier belts without rebuilding them",
    setup = function(ctx)
      ctx.data.belts = {}
      for _, position in ipairs(h.row(-1.5, 1.5)) do
        local belt = h.place(ctx, "transport-belt", position, west)
        belt.get_transport_line(defines.transport_line.left_line).insert_at(0.5, { name = "iron-plate", count = 1 })
        table.insert(ctx.data.belts, belt)
      end
      ctx.data.units = h.unit_numbers(ctx.data.belts)
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -1.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        -- the belts keep running, so the plates move between them. None should be lost
        local items = 0
        for i, position in ipairs(h.row(-1.5, 1.5)) do
          local belt = h.expect(ctx, position, "transport-belt", east)
          h.check_equal(ctx.data.units[i], belt.unit_number, "belt at " .. position[1] .. " (same entity, rotated)")
          items = items + h.items_on_belt(belt)
        end
        h.check_equal(4, items, "iron plates on the belts")
        h.check_equal(20, h.count(ctx, "transport-belt"), "belts in the inventory")
      end)
    ),
  },
  {
    name = "inventory drawing replaces other tier belts straight away",
    setup = function(ctx)
      for _, position in ipairs(h.row(-1.5, 0.5)) do
        h.place(ctx, "fast-transport-belt", position, west)
      end
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -2.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-2.5, 1.5)) do
          h.expect(ctx, position, "transport-belt", east)
          h.expect_none(ctx, position, "fast-transport-belt")
        end
        h.check_equal(15, h.count(ctx, "transport-belt"), "yellow belts left in the inventory")
        h.check_equal(3, h.count(ctx, "fast-transport-belt"), "fast belts returned to the inventory")
      end)
    ),
  },
  {
    name = "inventory drawing places ghosts once the items run out",
    setup = function(ctx)
      h.give(ctx, "transport-belt", 3)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -3.5, 0.5 }, { 4.5, 0.5 }),
      h.run(function(ctx)
        local positions = h.row(-3.5, 4.5)
        for i, position in ipairs(positions) do
          if i <= 3 then
            h.expect(ctx, position, "transport-belt", east)
          else
            h.expect(ctx, position, "transport-belt", east, true)
          end
        end
        h.check_equal(0, h.count(ctx, "transport-belt"), "belts left in the inventory")
      end)
    ),
  },
  {
    name = "out of reach nodes become ghosts and show the blue preview",
    timeout = 60 * 30,
    setup = function(ctx)
      ctx.player.teleport({ 0, 3.5 })
      h.give(ctx, "transport-belt", 50)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      -- starts out of reach, comes into reach, goes out of reach again
      h.move_to({ -13.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 13.5, 0.5 }),
      h.wait(2),
      h.run(function(ctx)
        local sprites = h.preview_sprites()
        for _, position in ipairs(h.row(-13.5, 13.5)) do
          local expected = h.in_reach(ctx, position) and "belt-draw-above" or "belt-draw-above-alt"
          h.check_equal(expected, h.sprite_at(sprites, position), "preview at " .. position[1])
        end
      end),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-13.5, 13.5)) do
          h.expect(ctx, position, "transport-belt", east, not h.in_reach(ctx, position))
        end
      end)
    ),
  },
  {
    name = "inventory drawing goes under water instead of placing landfill",
    setup = function(ctx)
      h.water(ctx, 0, 1)
      h.give(ctx, "transport-belt", 20)
      h.give(ctx, "underground-belt", 10)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -3.5, 0.5 }, { 4.5, 0.5 }),
      h.run(function(ctx)
        h.check_equal(0, #ctx.surface.find_entities_filtered({ name = "tile-ghost" }), "landfill ghosts")
        h.check_equal(0, #ctx.surface.find_entities_filtered({ name = "entity-ghost" }), "ghosts")
        h.check_equal("input", h.expect(ctx, { -0.5, 0.5 }, "underground-belt", east).belt_to_ground_type, "underground before the water")
        h.check_equal("output", h.expect(ctx, { 2.5, 0.5 }, "underground-belt", east).belt_to_ground_type, "underground after the water")
        for _, position in ipairs({ { 0.5, 0.5 }, { 1.5, 0.5 } }) do
          h.expect_none(ctx, position, "transport-belt")
        end
      end)
    ),
  },
}
