-- Blueprint drawing: Shift, map (remote) view or out of reach. Builds ghosts, belts already in the way
-- get rotated (same tier) or rotated and marked for upgrade (other tiers)

local h = require("tests.helpers")
local east, west = defines.direction.east, defines.direction.west

--- Belts of every kind blueprint drawing has to deal with, along y = 0.5:
--- -2.5 yellow, -1.5 fast, -0.5 fast ghost, all facing west. 0.5 is empty
---@param ctx TestContext
local function place_mixed_belts(ctx)
  ctx.data.yellow = h.place(ctx, "transport-belt", { -2.5, 0.5 }, west)
  ctx.data.fast = h.place(ctx, "fast-transport-belt", { -1.5, 0.5 }, west)
  h.place_ghost(ctx, "fast-transport-belt", { -0.5, 0.5 }, west)
  ctx.data.yellow_unit = ctx.data.yellow.unit_number
  ctx.data.fast_unit = ctx.data.fast.unit_number
end

--- What drawing east over place_mixed_belts should leave behind
---@param ctx TestContext
local function check_mixed_belts(ctx)
  local yellow = h.expect(ctx, { -2.5, 0.5 }, "transport-belt", east)
  h.check_equal(ctx.data.yellow_unit, yellow.unit_number, "yellow belt (same entity, rotated)")

  local fast = h.expect(ctx, { -1.5, 0.5 }, "fast-transport-belt", east)
  h.check_equal(ctx.data.fast_unit, fast.unit_number, "fast belt (same entity, rotated)")
  h.check(fast.to_be_upgraded(), "fast belt isn't marked for upgrade")
  local target = fast.get_upgrade_target()
  h.check_equal("transport-belt", target and target.name, "fast belt upgrade target")

  h.expect(ctx, { -0.5, 0.5 }, "transport-belt", east, true)
  h.expect_none(ctx, { -0.5, 0.5 }, "fast-transport-belt", true)

  h.expect(ctx, { 0.5, 0.5 }, "transport-belt", east, true)
end

---@type TestCase[]
return {
  {
    name = "blueprint drawing (shift) rotates same tier belts",
    setup = function(ctx)
      ctx.data.belts = {}
      for _, position in ipairs(h.row(-3.5, 2.5)) do
        table.insert(ctx.data.belts, h.place(ctx, "transport-belt", position, west))
      end
      ctx.data.units = h.unit_numbers(ctx.data.belts)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -2.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        -- the drawing covers -2.5 to 1.5
        for i, position in ipairs(h.row(-2.5, 1.5)) do
          local belt = h.expect(ctx, position, "transport-belt", east)
          h.check_equal(ctx.data.units[i + 1], belt.unit_number, "belt at " .. position[1] .. " (same entity, rotated)")
        end
        -- outside the drawing, left alone
        h.expect(ctx, { -3.5, 0.5 }, "transport-belt", west)
        h.expect(ctx, { 2.5, 0.5 }, "transport-belt", west)
      end)
    ),
  },
  {
    name = "blueprint drawing (shift) rotates other tiers and marks them for upgrade",
    setup = function(ctx)
      for _, position in ipairs(h.row(-1.5, 0.5)) do
        h.place(ctx, "fast-transport-belt", position, west)
      end
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -2.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-1.5, 0.5)) do
          local belt = h.expect(ctx, position, "fast-transport-belt", east)
          h.check(belt.to_be_upgraded(), "fast belt at " .. position[1] .. " isn't marked for upgrade")
          local target = belt.get_upgrade_target()
          h.check_equal("transport-belt", target and target.name, "upgrade target at " .. position[1])
        end
        h.expect(ctx, { -2.5, 0.5 }, "transport-belt", east, true)
        h.expect(ctx, { 1.5, 0.5 }, "transport-belt", east, true)
      end)
    ),
  },
  {
    name = "blueprint drawing (shift) swaps ghosts of other tiers",
    setup = function(ctx)
      for _, position in ipairs(h.row(-0.5, 0.5)) do
        h.place_ghost(ctx, "fast-transport-belt", position, west)
      end
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -1.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-1.5, 1.5)) do
          h.expect(ctx, position, "transport-belt", east, true)
          h.expect_none(ctx, position, "fast-transport-belt", true)
        end
      end)
    ),
  },
  {
    name = "blueprint drawing (map view) works like shift",
    setup = function(ctx)
      place_mixed_belts(ctx)
      ctx.player.set_controller({ type = defines.controllers.remote, position = { 0, 0 }, surface = ctx.surface })
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -2.5, 0.5 }, { 0.5, 0.5 }),
      h.run(check_mixed_belts)
    ),
  },
  {
    name = "blueprint drawing (shift) over every kind of belt at once",
    setup = function(ctx)
      place_mixed_belts(ctx)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -2.5, 0.5 }, { 0.5, 0.5 }),
      h.run(check_mixed_belts)
    ),
  },
  {
    name = "blueprint drawing (shift) places landfill under belts over water",
    setup = function(ctx)
      h.water(ctx, 0, 1)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -3.5, 0.5 }, { 4.5, 0.5 }),
      h.run(function(ctx)
        h.check_equal(0, #ctx.surface.find_entities_filtered({ name = "entity-ghost", ghost_name = "underground-belt" }), "underground ghosts")
        for _, position in ipairs(h.row(-3.5, 4.5)) do
          h.expect(ctx, position, "transport-belt", east, true)
        end
        for _, position in ipairs({ { 0.5, 0.5 }, { 1.5, 0.5 } }) do
          local tile = ctx.surface.find_entities_filtered({ name = "tile-ghost", position = position })[1]
          h.check(tile ~= nil and tile.ghost_name == "landfill", "no landfill ghost at " .. position[1])
        end
      end)
    ),
  },
}
