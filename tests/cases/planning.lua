-- Route planning: undergrounds around obstacles, anchored segments, leftover drawings

local h = require("tests.helpers")
local east, south = defines.direction.east, defines.direction.south

--- Assemblers in a row along y = 0.5, each covers 3 tiles: x - 1 to x + 1
---@param ctx TestContext
---@param ... number centre x of each assembler
local function place_assemblers(ctx, ...)
  for _, x in ipairs({ ... }) do
    h.place(ctx, "assembling-machine-1", { x, 0.5 }, defines.direction.north)
  end
end

--- The underground pair entering at `entry` and leaving at `exit`
---@param ctx TestContext
---@param entry MapPosition
---@param exit MapPosition
---@param direction defines.direction
local function expect_underground(ctx, entry, exit, direction)
  local input = h.expect(ctx, entry, "underground-belt", direction)
  local output = h.expect(ctx, exit, "underground-belt")
  h.check_equal("input", input.belt_to_ground_type, "underground at " .. entry[1] .. "," .. entry[2])
  h.check_equal("output", output.belt_to_ground_type, "underground at " .. exit[1] .. "," .. exit[2])
  local neighbour = input.underground_belt_neighbour
  h.check(neighbour and neighbour.unit_number == output.unit_number, "the undergrounds aren't connected")
end

---@param ctx TestContext
local function expect_no_undergrounds(ctx)
  local found = ctx.surface.find_entities_filtered({ area = { { -20, -15 }, { 20, 15 } }, name = "underground-belt" })
  local ghosts = ctx.surface.find_entities_filtered({
    area = { { -20, -15 }, { 20, 15 } }, name = "entity-ghost", ghost_name = "underground-belt",
  })
  h.check_equal(0, #found + #ghosts, "undergrounds")
end

---@type TestCase[]
return {
  {
    name = "drawing into the side of a belt line leaves that line alone",
    setup = function(ctx)
      ctx.data.line = {}
      for y = -1.5, 2.5 do
        table.insert(ctx.data.line, h.place(ctx, "transport-belt", { 2.5, y }, south))
      end
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -1.5, 0.5 }, { 2.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-1.5, 1.5)) do h.expect(ctx, position, "transport-belt", east) end
        -- the belt it feeds into isn't turned
        for y = -1.5, 2.5 do h.expect(ctx, { 2.5, y }, "transport-belt", south) end
      end)
    ),
  },
  {
    name = "drawing into a splitter facing the same way joins it",
    setup = function(ctx)
      ctx.data.splitter = h.place(ctx, "splitter", { 0.5, 1 }, east)
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -2.5, 0.5 }, { 0.5, 0.5 }),
      h.run(function(ctx)
        h.check(ctx.data.splitter.valid, "the splitter was replaced")
        for _, position in ipairs(h.row(-2.5, -0.5)) do h.expect(ctx, position, "transport-belt", east) end
      end)
    ),
  },
  {
    -- a belt line passing through would be split, so it goes under the splitter instead
    name = "drawing through a splitter goes under it",
    setup = function(ctx)
      ctx.data.splitter = h.place(ctx, "splitter", { 0.5, 1 }, east)
      h.give(ctx, "transport-belt", 20)
      h.give(ctx, "underground-belt", 10)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -2.5, 0.5 }, { 3.5, 0.5 }),
      h.run(function(ctx)
        h.check(ctx.data.splitter.valid, "the splitter was replaced")
        expect_underground(ctx, { -0.5, 0.5 }, { 1.5, 0.5 }, east)
        h.expect(ctx, { -2.5, 0.5 }, "transport-belt", east)
        h.expect(ctx, { 3.5, 0.5 }, "transport-belt", east)
      end)
    ),
  },
  {
    name = "an obstacle within range gets an underground",
    setup = function(ctx)
      place_assemblers(ctx, 0.5)
      h.give(ctx, "transport-belt", 20)
      h.give(ctx, "underground-belt", 10)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -4.5, 0.5 }, { 5.5, 0.5 }),
      h.run(function(ctx)
        expect_underground(ctx, { -1.5, 0.5 }, { 2.5, 0.5 }, east)
        for _, position in ipairs(h.row(-4.5, -2.5)) do h.expect(ctx, position, "transport-belt", east) end
        for _, position in ipairs(h.row(3.5, 5.5)) do h.expect(ctx, position, "transport-belt", east) end
      end)
    ),
  },
  {
    name = "an obstacle too long for an underground leaves a gap (inventory drawing)",
    setup = function(ctx)
      -- covers -0.5 to 7.5, 9 tiles
      place_assemblers(ctx, 0.5, 3.5, 6.5)
      ctx.player.teleport({ 3.5, 5.5 })
      h.give(ctx, "transport-belt", 20)
      h.give(ctx, "underground-belt", 10)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -3.5, 0.5 }, { 10.5, 0.5 }),
      h.run(function(ctx)
        expect_no_undergrounds(ctx)
        for _, position in ipairs(h.row(-3.5, -1.5)) do h.expect(ctx, position, "transport-belt", east) end
        for _, position in ipairs(h.row(8.5, 10.5)) do h.expect(ctx, position, "transport-belt", east) end
      end)
    ),
  },
  {
    name = "an obstacle too long for an underground leaves a gap (blueprint drawing)",
    setup = function(ctx)
      place_assemblers(ctx, 0.5, 3.5, 6.5)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -3.5, 0.5 }, { 10.5, 0.5 }),
      h.run(function(ctx)
        expect_no_undergrounds(ctx)
        for _, position in ipairs(h.row(-3.5, -1.5)) do h.expect(ctx, position, "transport-belt", east, true) end
        for _, position in ipairs(h.row(8.5, 10.5)) do h.expect(ctx, position, "transport-belt", east, true) end
      end)
    ),
  },
  {
    name = "an anchored segment goes under an earlier one it crosses",
    timeout = 60 * 30,
    setup = function(ctx)
      h.give(ctx, "transport-belt", 50)
      h.give(ctx, "underground-belt", 10)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.move_to({ -3.5, 0.5 }),
      h.press(h.controls.draw),
      -- east, then north, then west, then south back across the first segment
      h.move_to({ 2.5, 0.5 }),
      h.run(function(ctx) add_segment(get_state(ctx.player).current_segment.to, ctx.player) end),
      h.move_to({ 2.5, -2.5 }),
      h.run(function(ctx) add_segment(get_state(ctx.player).current_segment.to, ctx.player) end),
      h.move_to({ 0.5, -2.5 }),
      h.run(function(ctx) add_segment(get_state(ctx.player).current_segment.to, ctx.player) end),
      h.move_to({ 0.5, 3.5 }),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        -- the first segment is untouched where it's crossed
        h.expect(ctx, { 0.5, 0.5 }, "transport-belt", east)
        expect_underground(ctx, { 0.5, -0.5 }, { 0.5, 1.5 }, south)
      end)
    ),
  },
  {
    name = "starting a new drag clears a leftover drawing",
    setup = function(ctx)
      h.hold_tool(ctx)
      -- a drawing that never finished, as if its cancel event got lost
      local state = get_state(ctx.player)
      add_segment({ x = -6.5, y = -3.5 }, ctx.player)
      state.current_segment:update_to({ x = -3.5, y = -3.5 })
      state.dragging = false
      local leftover = 0
      for tile in pairs(h.preview_sprites()) do
        if tile:find(",%-3%.5$") then leftover = leftover + 1 end
      end
      h.check(leftover > 0, "setup: the leftover drawing has no preview")
    end,
    steps = h.steps(
      h.move_to({ 2.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 4.5, 0.5 }),
      h.wait(2),
      h.run(function()
        for tile in pairs(h.preview_sprites()) do
          h.check(not tile:find(",%-3%.5$"), "leftover preview still at " .. tile)
        end
      end),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-6.5, -3.5, -3.5)) do
          h.expect_none(ctx, position, "transport-belt")
          h.expect_none(ctx, position, "transport-belt", true)
        end
      end)
    ),
  },
}
