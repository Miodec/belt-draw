-- Belt tiers: drawing with the higher tiers, their underground reach, switching tiers

local h = require("tests.helpers")
local east = defines.direction.east

--- A wall `length` tiles long along a row, starting at x = 0.5
---@param ctx TestContext
---@param length integer
---@param y number
local function place_wall(ctx, length, y)
  for x = 0, length - 1 do
    h.place(ctx, "stone-wall", { x + 0.5, y }, defines.direction.north)
  end
end

--- Undergrounds reach `reach` tiles: a wall that long gets an underground pair, one tile longer doesn't.
--- `reach` is the game's max_distance minus one (it counts both ends)
---@param tier string tool name suffix, "fast" or "express"
---@param prefix string entity name prefix, "fast-" or "express-"
---@param reach integer
---@return TestCase
local function underground_reach_case(tier, prefix, reach)
  local belt, underground = prefix .. "transport-belt", prefix .. "underground-belt"
  local last = reach + 1.5
  return {
    name = tier .. " belts go under " .. reach .. " tiles, not " .. (reach + 1),
    timeout = 60 * 30,
    setup = function(ctx)
      -- rows at y = -2.5 (just in reach) and y = 1.5 (one too long), the player stands between them
      place_wall(ctx, reach, -2.5)
      place_wall(ctx, reach + 1, 1.5)
      ctx.player.teleport({ reach / 2, -0.5 })
      h.give(ctx, belt, 50)
      h.give(ctx, underground, 20)
      h.hold_tool(ctx, "belt-draw-" .. tier .. "-preview")
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -1.5, -2.5 }, { last + 1, -2.5 }),
      h.drag(h.controls.draw, { -1.5, 1.5 }, { last + 1, 1.5 }),
      h.run(function(ctx)
        local input = h.expect(ctx, { -0.5, -2.5 }, underground, east)
        local output = h.expect(ctx, { reach + 0.5, -2.5 }, underground)
        h.check_equal("input", input.belt_to_ground_type, "underground before the wall")
        h.check_equal("output", output.belt_to_ground_type, "underground after the wall")
        h.expect(ctx, { -1.5, -2.5 }, belt, east)

        h.check_equal(0, #ctx.surface.find_entities_filtered({ area = { { -5, 0.5 }, { 20, 2.5 } }, name = underground }),
          "undergrounds next to the too long wall")
        h.expect(ctx, { -1.5, 1.5 }, belt, east)
        h.expect(ctx, { -0.5, 1.5 }, belt, east)
        h.expect(ctx, { reach + 1.5, 1.5 }, belt, east)
      end)
    ),
  }
end

---@type TestCase[]
return {
  underground_reach_case("fast", "fast-", 6),
  underground_reach_case("express", "express-", 8),
  {
    name = "yellow belts go under 4 tiles, not 5",
    timeout = 60 * 30,
    setup = function(ctx)
      place_wall(ctx, 4, -2.5)
      place_wall(ctx, 5, 1.5)
      ctx.player.teleport({ 2, -0.5 })
      h.give(ctx, "transport-belt", 50)
      h.give(ctx, "underground-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -1.5, -2.5 }, { 6.5, -2.5 }),
      h.drag(h.controls.draw, { -1.5, 1.5 }, { 6.5, 1.5 }),
      h.run(function(ctx)
        h.expect(ctx, { -0.5, -2.5 }, "underground-belt", east)
        h.expect(ctx, { 4.5, -2.5 }, "underground-belt")
        h.check_equal(0, #ctx.surface.find_entities_filtered({ area = { { -5, 0.5 }, { 20, 2.5 } }, name = "underground-belt" }),
          "undergrounds next to the too long wall")
        h.expect(ctx, { 5.5, 1.5 }, "transport-belt", east)
      end)
    ),
  },
  {
    name = "switching tiers (shift + scroll) changes the tool",
    setup = function(ctx) h.hold_tool(ctx) end,
    steps = h.steps(
      h.tap("belt-draw-next-tier"),
      h.wait(2),
      h.run(function(ctx)
        h.check_equal("belt-draw-fast-preview", ctx.player.cursor_stack.name, "tool after next tier")
        h.check_equal("fast", get_state(ctx.player).current_tier, "tier after next tier")
      end),
      h.tap("belt-draw-previous-tier"),
      h.wait(2),
      h.run(function(ctx)
        h.check_equal("belt-draw-preview", ctx.player.cursor_stack.name, "tool after previous tier")
        h.check_equal("normal", get_state(ctx.player).current_tier, "tier after previous tier")
      end)
    ),
  },
  {
    name = "the shortcut tool turns into the current tier's tool",
    setup = function(ctx)
      -- last used tier is express
      h.hold_tool(ctx, "belt-draw-express-preview")
    end,
    steps = h.steps(
      -- the mod handles cursor events after this tick, against whatever the cursor holds by then,
      -- so each change needs its own tick
      h.wait(2),
      h.run(function(ctx) ctx.player.clear_cursor() end),
      h.wait(2),
      h.run(function(ctx) ctx.player.cursor_stack.set_stack({ name = "belt-draw-generic" }) end),
      h.wait(2),
      h.run(function(ctx)
        h.check_equal("belt-draw-express-preview", ctx.player.cursor_stack.name, "tool from the shortcut")
      end)
    ),
  },
}
