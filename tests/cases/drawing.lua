-- The drawing itself: L shapes, going back over the path, flipping, single clicks, cancelling, walking

local h = require("tests.helpers")
local east, south = defines.direction.east, defines.direction.south

---@param ctx TestContext
local function with_belts(ctx)
  h.give(ctx, "transport-belt", 50)
  h.hold_tool(ctx)
end

---@type TestCase[]
return {
  {
    name = "an L shaped drag bends where the cursor turned (horizontal first)",
    setup = with_belts,
    steps = h.steps(
      -- the cursor goes right first, then down
      h.drag(h.controls.draw, { -3.5, 0.5 }, { 1.5, 0.5 }, { 1.5, 3.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-3.5, 0.5)) do h.expect(ctx, position, "transport-belt", east) end
        -- the corner already points down the second leg
        h.expect(ctx, { 1.5, 0.5 }, "transport-belt", south)
        for y = 1.5, 3.5 do h.expect(ctx, { 1.5, y }, "transport-belt", south) end
        h.expect_none(ctx, { -3.5, 3.5 }, "transport-belt")
      end)
    ),
  },
  {
    name = "an L shaped drag bends where the cursor turned (vertical first)",
    setup = with_belts,
    steps = h.steps(
      -- the cursor goes down first, then right
      h.drag(h.controls.draw, { -3.5, 0.5 }, { -3.5, 3.5 }, { 1.5, 3.5 }),
      h.run(function(ctx)
        for y = 0.5, 2.5 do h.expect(ctx, { -3.5, y }, "transport-belt", south) end
        h.expect(ctx, { -3.5, 3.5 }, "transport-belt", east)
        for _, position in ipairs(h.row(-2.5, 1.5, 3.5)) do h.expect(ctx, position, "transport-belt", east) end
        h.expect_none(ctx, { 1.5, 0.5 }, "transport-belt")
      end)
    ),
  },
  {
    name = "flipping (F) mid drag moves the bend to the other side",
    setup = with_belts,
    steps = h.steps(
      h.move_to({ -3.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 1.5, 0.5 }),
      h.move_to({ 1.5, 3.5 }),
      h.tap("belt-draw-flip-orientation"),
      h.wait(2),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        -- now vertical first, like the drag above
        for y = 0.5, 2.5 do h.expect(ctx, { -3.5, y }, "transport-belt", south) end
        h.expect(ctx, { -3.5, 3.5 }, "transport-belt", east)
        for _, position in ipairs(h.row(-2.5, 1.5, 3.5)) do h.expect(ctx, position, "transport-belt", east) end
        h.expect_none(ctx, { 1.5, 0.5 }, "transport-belt")
      end)
    ),
  },
  {
    name = "going back over the path shrinks the drawing and its preview",
    setup = with_belts,
    steps = h.steps(
      h.move_to({ -3.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 3.5, 0.5 }),
      h.move_to({ 0.5, 0.5 }),
      h.wait(2),
      h.run(function() h.expect_preview_exactly(h.row(-3.5, 0.5)) end),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-3.5, 0.5)) do h.expect(ctx, position, "transport-belt", east) end
        for _, position in ipairs(h.row(1.5, 3.5)) do h.expect_none(ctx, position, "transport-belt") end
        h.check_equal(45, h.count(ctx, "transport-belt"), "belts left in the inventory")
      end)
    ),
  },
  {
    name = "a single click builds one belt facing the cursor direction",
    setup = function(ctx)
      with_belts(ctx)
      game.simulation.camera_player_cursor_direction = east
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { 0.5, 0.5 }),
      h.run(function(ctx)
        h.expect(ctx, { 0.5, 0.5 }, "transport-belt", east)
        h.check_equal(49, h.count(ctx, "transport-belt"), "belts left in the inventory")
      end)
    ),
  },
  {
    name = "emptying the cursor mid drag cancels the drawing",
    setup = with_belts,
    steps = h.steps(
      h.move_to({ -3.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 1.5, 0.5 }),
      h.tap("clear-cursor"),
      h.wait(2),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        h.expect_preview_exactly({})
        for _, position in ipairs(h.row(-3.5, 1.5)) do
          h.expect_none(ctx, position, "transport-belt")
          h.expect_none(ctx, position, "transport-belt", true)
        end
        h.check_equal(50, h.count(ctx, "transport-belt"), "belts in the inventory")
      end)
    ),
  },
  {
    name = "walking while drawing updates which nodes are out of reach",
    timeout = 60 * 30,
    setup = function(ctx)
      h.ghosts_out_of_reach(ctx)
      ctx.player.teleport({ 0, 3.5 })
      with_belts(ctx)
    end,
    steps = h.steps(
      h.move_to({ -9.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 12.5, 0.5 }),
      -- walk to the right, the left end goes out of reach and the right end comes into reach
      h.run(function(ctx) ctx.player.teleport({ 8, 3.5 }) end),
      h.wait(2),
      h.run(function(ctx)
        local sprites = h.preview_sprites()
        for _, position in ipairs(h.row(-9.5, 12.5)) do
          local expected = h.in_reach(ctx, position) and "belt-draw-above" or "belt-draw-above-alt"
          h.check_equal(expected, h.sprite_at(sprites, position), "preview at " .. position[1])
        end
      end),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-9.5, 12.5)) do
          h.expect(ctx, position, "transport-belt", east, not h.in_reach(ctx, position))
        end
      end)
    ),
  },
  {
    name = "walking while drawing updates which nodes are faded, with out of reach ghosts off",
    timeout = 60 * 30,
    setup = function(ctx)
      ctx.player.teleport({ 0, 3.5 })
      with_belts(ctx)
    end,
    steps = h.steps(
      h.move_to({ -9.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 12.5, 0.5 }),
      -- walk to the right, the left end goes out of reach and the right end comes into reach
      h.run(function(ctx) ctx.player.teleport({ 8, 3.5 }) end),
      h.wait(2),
      h.run(function(ctx)
        local sprites = h.preview_sprites()
        local opacities = h.preview_opacities()
        for _, position in ipairs(h.row(-9.5, 12.5)) do
          h.check_equal("belt-draw-above", h.sprite_at(sprites, position), "preview at " .. position[1])
          local opacity = h.in_reach(ctx, position) and 1 or 0.5
          h.check_equal(opacity, h.sprite_at(opacities, position), "preview opacity at " .. position[1])
        end
      end),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-9.5, 12.5)) do
          if h.in_reach(ctx, position) then
            h.expect(ctx, position, "transport-belt", east)
          else
            h.expect_none(ctx, position, "transport-belt")
            h.expect_none(ctx, position, "transport-belt", true)
          end
        end
      end)
    ),
  },
}
