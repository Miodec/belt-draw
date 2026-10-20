-- Deconstructing (reverse select) and super forced drawing

local h = require("tests.helpers")
local east, west, north = defines.direction.east, defines.direction.west, defines.direction.north

---@type TestCase[]
return {
  {
    name = "deconstructing marks belts of every kind and tier, and nothing else",
    setup = function(ctx)
      ctx.data.marked = {
        h.place(ctx, "transport-belt", { -4.5, 0.5 }, east),
        h.place(ctx, "fast-underground-belt", { -3.5, 0.5 }, east, { type = "input" }),
        h.place(ctx, "fast-underground-belt", { -1.5, 0.5 }, east, { type = "output" }),
        -- a splitter facing east is two tiles tall
        h.place(ctx, "express-splitter", { 0.5, 1 }, east),
      }
      h.place_ghost(ctx, "fast-transport-belt", { 2.5, 0.5 }, east)
      ctx.data.assembler = h.place(ctx, "assembling-machine-1", { 5.5, 0.5 }, north)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.deconstruct, { -5.5, -1.5 }, { 7.5, 2.5 }),
      h.run(function(ctx)
        ---@type LuaEntity[]
        local marked = ctx.data.marked
        for _, entity in ipairs(marked) do
          h.check(entity.valid, "a belt was removed instead of marked")
          h.check(entity.to_be_deconstructed(), entity.name .. " at " .. entity.position.x .. " isn't marked")
        end
        h.expect_none(ctx, { 2.5, 0.5 }, "fast-transport-belt", true)
        h.check(not ctx.data.assembler.to_be_deconstructed(), "the assembler is marked for deconstruction")
      end)
    ),
  },
  {
    name = "super forced drawing builds through obstacles and handles belts like blueprint drawing",
    setup = function(ctx)
      -- covers -0.5 to 1.5
      ctx.data.assembler = h.place(ctx, "assembling-machine-1", { 0.5, 0.5 }, north)
      ctx.data.yellow = h.place(ctx, "transport-belt", { -3.5, 0.5 }, west)
      ctx.data.fast = h.place(ctx, "fast-transport-belt", { 3.5, 0.5 }, west)
      ctx.data.yellow_unit = ctx.data.yellow.unit_number
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.drag(h.controls.super_forced_draw, { -3.5, 0.5 }, { 4.5, 0.5 }),
      h.run(function(ctx)
        h.check(ctx.data.assembler.to_be_deconstructed(), "the assembler isn't marked for deconstruction")
        for _, position in ipairs(h.row(-2.5, 2.5)) do
          h.expect(ctx, position, "transport-belt", east, true)
        end
        h.expect(ctx, { 4.5, 0.5 }, "transport-belt", east, true)

        local yellow = h.expect(ctx, { -3.5, 0.5 }, "transport-belt", east)
        h.check_equal(ctx.data.yellow_unit, yellow.unit_number, "yellow belt (same entity, rotated)")
        local fast = h.expect(ctx, { 3.5, 0.5 }, "fast-transport-belt", east)
        h.check(fast.to_be_upgraded(), "fast belt isn't marked for upgrade")
      end)
    ),
  },
  {
    name = "super forced drawing highlights what it will remove, until released",
    setup = function(ctx)
      h.place(ctx, "assembling-machine-1", { 0.5, 0.5 }, north)
      h.hold_tool(ctx)
    end,
    steps = h.steps(
      h.move_to({ -3.5, 0.5 }),
      h.press(h.controls.super_forced_draw),
      h.move_to({ 4.5, 0.5 }),
      h.wait(2),
      h.run(function(ctx)
        -- one box for the whole assembler, not one per tile it blocks
        h.check_equal(1, #ctx.surface.find_entities_filtered({ name = "highlight-box" }), "highlight boxes while drawing")
      end),
      h.release(h.controls.super_forced_draw),
      h.wait(10),
      h.run(function(ctx)
        h.check_equal(0, #ctx.surface.find_entities_filtered({ name = "highlight-box" }), "highlight boxes after release")
      end)
    ),
  },
}
