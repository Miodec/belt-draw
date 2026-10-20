-- Bugs fixed during the 3.0 rework, each of these failed before its fix

local h = require("tests.helpers")
local east, west = defines.direction.east, defines.direction.west

---@type TestCase[]
return {
  {
    -- the first node's direction came from the build key press, which shift drawing doesn't fire.
    -- Planning crashed comparing a nil direction once that node was on a belt
    name = "shift drawing that starts on a belt, with no build press before it",
    setup = function(ctx)
      for _, position in ipairs(h.row(-2.5, 1.5)) do
        h.place(ctx, "transport-belt", position, west)
      end
      -- earlier cases pressed build, which left a direction behind
      get_state(ctx.player).starting_direction = nil
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -2.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-2.5, 1.5)) do
          h.expect(ctx, position, "transport-belt", east)
        end
      end)
    ),
  },
  {
    -- ghosts were created with fast replace, which took the real belt underneath into the inventory
    name = "out of items, belts of another tier are marked for upgrade rather than taken away",
    setup = function(ctx)
      ctx.data.fast = h.place(ctx, "fast-transport-belt", { -0.5, 0.5 }, west)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -1.5, 0.5 }, { 0.5, 0.5 }),
      h.run(function(ctx)
        h.check(ctx.data.fast.valid, "the fast belt was taken away")
        h.expect(ctx, { -0.5, 0.5 }, "fast-transport-belt", east)
        h.check(ctx.data.fast.to_be_upgraded(), "the fast belt isn't marked for upgrade")
        h.check_equal(0, h.count(ctx, "fast-transport-belt"), "fast belts in the inventory")
        h.expect(ctx, { -1.5, 0.5 }, "transport-belt", east, true)
        h.expect(ctx, { 0.5, 0.5 }, "transport-belt", east, true)
      end)
    ),
  },
  {
    -- all drawing state used to be shared, another player's drawing got placed or cleared along with yours
    name = "two players draw independently, each only sees their own preview",
    setup = function(ctx)
      local other = game.get_player("other tester") or game.simulation.create_test_player({ name = "other tester" })
      other.teleport({ 10, -10 })
      ctx.data.other = other
      -- the other player is halfway through a drawing of their own
      other.cursor_stack.set_stack({ name = "belt-draw-preview" })
      add_segment({ x = 5.5, y = -5.5 }, other)
      get_state(other).current_segment:update_to({ x = 8.5, y = -5.5 })
      get_state(other).dragging = true

      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.move_to({ -2.5, 0.5 }),
      h.press(h.controls.draw),
      h.move_to({ 1.5, 0.5 }),
      h.wait(2),
      h.run(function(ctx)
        local mine, theirs = 0, 0
        for _, object in pairs(rendering.get_all_objects("belt-draw")) do
          if object.type == "sprite" then
            local players = object.players
            h.check(players and #players == 1, "a preview sprite is shown to " .. (players and #players or "every") .. " players")
            ---@cast players LuaPlayer[]
            if players[1] == ctx.player then mine = mine + 1 else theirs = theirs + 1 end
          end
        end
        h.check(mine > 0 and theirs > 0, "expected previews for both players, got " .. mine .. " and " .. theirs)
      end),
      h.release(h.controls.draw),
      h.wait(10),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-2.5, 1.5)) do
          h.expect(ctx, position, "transport-belt", east)
        end
        -- the other drawing wasn't placed or cleared
        for _, position in ipairs(h.row(5.5, 8.5, -5.5)) do
          h.expect_none(ctx, position, "transport-belt")
          h.expect_none(ctx, position, "transport-belt", true)
        end
        local state = get_state(ctx.data.other)
        h.check_equal(1, #state.segments, "segments of the other player's drawing")
        h.check(state.dragging, "the other player's drawing stopped")
      end)
    ),
  },
  {
    -- out of reach nodes are built with a blueprint, which covers water with landfill. They used to be planned
    -- like reachable ones, so water got an underground
    name = "out of reach water gets landfill, not an underground",
    setup = function(ctx)
      h.ghosts_out_of_reach(ctx)
      h.water(ctx, 11, 13)
      ctx.player.teleport({ 0, 3.5 })
      h.give(ctx, "transport-belt", 20)
      h.give(ctx, "underground-belt", 10)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { 7.5, 0.5 }, { 14.5, 0.5 }),
      h.run(function(ctx)
        h.check_equal(0, #ctx.surface.find_entities_filtered({ name = "underground-belt" }) +
          #ctx.surface.find_entities_filtered({ name = "entity-ghost", ghost_name = "underground-belt" }), "undergrounds")
        for _, position in ipairs(h.row(11.5, 13.5)) do
          h.expect(ctx, position, "transport-belt", east, true)
          h.check(#ctx.surface.find_entities_filtered({ name = "tile-ghost", position = position }) > 0,
            "no landfill ghost at " .. position[1])
        end
      end)
    ),
  },
  {
    name = "out of reach water is left alone with out of reach ghosts off",
    setup = function(ctx)
      h.water(ctx, 11, 13)
      ctx.player.teleport({ 0, 3.5 })
      h.give(ctx, "transport-belt", 20)
      h.give(ctx, "underground-belt", 10)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { 7.5, 0.5 }, { 14.5, 0.5 }),
      h.run(function(ctx)
        h.check_equal(0, #ctx.surface.find_entities_filtered({ name = "tile-ghost" }), "landfill ghosts")
        h.check_equal(0, #ctx.surface.find_entities_filtered({ name = "entity-ghost" }), "ghosts")
        for _, position in ipairs(h.row(7.5, 14.5)) do
          if h.in_reach(ctx, position) then
            h.expect(ctx, position, "transport-belt", east)
          else
            h.check_equal(0, #ctx.surface.find_entities_filtered({ position = position, type = { "transport-belt", "underground-belt" } }),
              "belts at " .. position[1])
          end
        end
      end)
    ),
  },
}
