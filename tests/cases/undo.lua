-- Undo and redo: one undo reverts a whole drawing, rotations included

local h = require("tests.helpers")
local east, west = defines.direction.east, defines.direction.west

---@type TestCase[]
return {
  {
    name = "one undo reverts a blueprint drawing (shift), redo puts it back",
    setup = function(ctx)
      h.place(ctx, "transport-belt", { -1.5, 0.5 }, west)
      h.place(ctx, "fast-transport-belt", { -0.5, 0.5 }, west)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { -2.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        -- the drawing itself, so a failure below is about undo and not the drawing
        h.expect(ctx, { -1.5, 0.5 }, "transport-belt", east)
        h.check(h.expect(ctx, { -0.5, 0.5 }, "fast-transport-belt", east).to_be_upgraded(), "fast belt isn't marked for upgrade")
      end),
      h.press_and_release("undo"),
      h.run(function(ctx)
        h.expect(ctx, { -1.5, 0.5 }, "transport-belt", west)
        local fast = h.expect(ctx, { -0.5, 0.5 }, "fast-transport-belt", west)
        h.check(not fast.to_be_upgraded(), "fast belt is still marked for upgrade")
        for _, position in ipairs({ { -2.5, 0.5 }, { 0.5, 0.5 }, { 1.5, 0.5 } }) do
          h.expect_none(ctx, position, "transport-belt", true)
        end
      end),
      h.press_and_release("redo"),
      h.run(function(ctx)
        h.expect(ctx, { -1.5, 0.5 }, "transport-belt", east)
        h.check(h.expect(ctx, { -0.5, 0.5 }, "fast-transport-belt", east).to_be_upgraded(),
          "fast belt isn't marked for upgrade after redo")
        for _, position in ipairs({ { -2.5, 0.5 }, { 0.5, 0.5 }, { 1.5, 0.5 } }) do
          h.expect(ctx, position, "transport-belt", east, true)
        end
      end)
    ),
  },
  {
    name = "one undo reverts an inventory drawing",
    setup = function(ctx)
      h.place(ctx, "transport-belt", { -0.5, 0.5 }, west)
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -2.5, 0.5 }, { 1.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-2.5, 1.5)) do
          h.expect(ctx, position, "transport-belt", east)
        end
      end),
      h.press_and_release("undo"),
      h.run(function(ctx)
        -- undoing a build marks it for deconstruction, like the game does for belts placed by hand
        for _, position in ipairs({ { -2.5, 0.5 }, { -1.5, 0.5 }, { 0.5, 0.5 }, { 1.5, 0.5 } }) do
          local belt = h.expect(ctx, position, "transport-belt")
          h.check(belt.to_be_deconstructed(), "belt at " .. position[1] .. " isn't marked for deconstruction")
        end
        local rotated = h.expect(ctx, { -0.5, 0.5 }, "transport-belt", west)
        h.check(not rotated.to_be_deconstructed(), "the rotated belt is marked for deconstruction")
      end)
    ),
  },
  {
    name = "one undo reverts an inventory drawing that goes out of reach, belts and ghosts",
    timeout = 60 * 30,
    setup = function(ctx)
      h.ghosts_out_of_reach(ctx)
      ctx.player.teleport({ 0, 3.5 })
      h.give(ctx, "transport-belt", 50)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -13.5, 0.5 }, { 13.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-13.5, 13.5)) do
          h.expect(ctx, position, "transport-belt", east, not h.in_reach(ctx, position))
        end
      end),
      h.press_and_release("undo"),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-13.5, 13.5)) do
          if h.in_reach(ctx, position) then
            local belt = h.expect(ctx, position, "transport-belt")
            h.check(belt.to_be_deconstructed(), "belt at " .. position[1] .. " isn't marked for deconstruction")
          else
            h.expect_none(ctx, position, "transport-belt", true)
          end
        end
      end),
      h.press_and_release("redo"),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-13.5, 13.5)) do
          local in_reach = h.in_reach(ctx, position)
          local belt = h.expect(ctx, position, "transport-belt", east, not in_reach)
          if in_reach then
            h.check(not belt.to_be_deconstructed(), "belt at " .. position[1] .. " is still marked for deconstruction")
          end
        end
      end)
    ),
  },
  {
    name = "one undo reverts an inventory drawing back over the previous one",
    setup = function(ctx)
      h.give(ctx, "transport-belt", 20)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { 1.5, 0.5 }, { -1.5, 0.5 }),
      h.drag(h.controls.draw, { -3.5, 0.5 }, { 3.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-3.5, 3.5)) do
          h.expect(ctx, position, "transport-belt", east)
        end
      end),
      h.press_and_release("undo"),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-3.5, 3.5)) do
          local belt = h.expect(ctx, position, "transport-belt")
          local previous = position[1] > -2 and position[1] < 2
          h.check_equal(not previous, belt.to_be_deconstructed(), "belt at " .. position[1] .. " marked for deconstruction")
          if previous then
            h.check_equal(west, belt.direction, "direction of the belt at " .. position[1])
          end
        end
      end)
    ),
  },
  {
    name = "one undo reverts a blueprint drawing (shift) back over the previous one",
    setup = function(ctx)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.shift_draw, { 1.5, 0.5 }, { -1.5, 0.5 }),
      h.drag(h.controls.shift_draw, { -3.5, 0.5 }, { 3.5, 0.5 }),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-3.5, 3.5)) do
          h.expect(ctx, position, "transport-belt", east, true)
        end
      end),
      h.press_and_release("undo"),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-3.5, 3.5)) do
          if position[1] > -2 and position[1] < 2 then
            h.expect(ctx, position, "transport-belt", west, true)
          else
            h.expect_none(ctx, position, "transport-belt", true)
          end
        end
      end)
    ),
  },
  {
    name = "one undo reverts a longer drawing back over a fast belt drawing",
    setup = function(ctx)
      h.give(ctx, "fast-transport-belt", 20)
      h.hold_tool(ctx, "belt-draw-fast-preview")
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -1.5, 0.5 }, { 0.5, 0.5 }),
      h.drag(h.controls.draw, { 1.5, 0.5 }, { -2.5, 0.5 }),
      h.press_and_release("undo"),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-2.5, 1.5)) do
          local belt = h.expect(ctx, position, "fast-transport-belt")
          local previous = position[1] > -2 and position[1] < 1
          h.check_equal(not previous, belt.to_be_deconstructed(), "belt at " .. position[1] .. " marked for deconstruction")
          if previous then
            h.check_equal(east, belt.direction, "direction of the belt at " .. position[1])
          end
        end
      end)
    ),
  },
  {
    name = "one undo reverts an inventory drawing that goes out of reach, with out of reach ghosts off",
    timeout = 60 * 30,
    setup = function(ctx)
      ctx.player.teleport({ 0, 3.5 })
      h.give(ctx, "transport-belt", 50)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.draw, { -13.5, 0.5 }, { 13.5, 0.5 }),
      h.press_and_release("undo"),
      h.run(function(ctx)
        for _, position in ipairs(h.row(-13.5, 13.5)) do
          if h.in_reach(ctx, position) then
            local belt = h.expect(ctx, position, "transport-belt")
            h.check(belt.to_be_deconstructed(), "belt at " .. position[1] .. " isn't marked for deconstruction")
          else
            h.expect_none(ctx, position, "transport-belt")
            h.expect_none(ctx, position, "transport-belt", true)
          end
        end
        h.check_equal(0, ctx.player.undo_redo_stack.get_undo_item_count(), "undo items left")
      end)
    ),
  },
}
