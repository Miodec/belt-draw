-- Shared helpers for the test cases in tests/cases/

-- helpers pass around dynamic values (entity parameters, render targets, defines tables) the checker can't type
---@diagnostic disable: no-unknown

local helpers = {}

--- The game controls a mouse button press fires, with the default bindings. A real click fires both the selection
--- control and the build/mine control on the same key. Pressing only the selection control isn't the same:
--- after the mod swaps the tool mid drag, releasing it alone doesn't end the restarted selection
helpers.controls = {
  draw = { "select-for-blueprint", "build" },
  shift_draw = { "select-for-cancel-deconstruct", "build-ghost" },
  super_forced_draw = { "select-for-super-forced-deconstruct", "super-forced-build" },
  deconstruct = { "reverse-select", "mine" },
}

---@param ... TestStep|TestStep[]
---@return TestStep[]
function helpers.steps(...)
  local list = {}
  for _, part in ipairs({ ... }) do
    if type(part) == "function" then
      table.insert(list, part)
    else
      for _, step in ipairs(part) do table.insert(list, step) end
    end
  end
  return list
end

--- A step that runs once
---@param fn fun(ctx: TestContext)
---@return TestStep
function helpers.run(fn)
  return function(ctx)
    fn(ctx)
    return true
  end
end

---@param ticks integer
---@return TestStep
function helpers.wait(ticks)
  return function(ctx) return ctx.step_tick >= ticks end
end

--- Tiles per tick the cursor moves. The game's default is 0.2, about how fast a person drags.
--- Kept under 1 so the cursor still lands on every tile and the mod gets an update per tile, like a real drag
helpers.cursor_speed = 0.9

---@param position MapPosition
---@return TestStep
function helpers.move_to(position)
  return function() return game.simulation.move_cursor({ position = position, speed = helpers.cursor_speed }) end
end

--- Controls currently held down, so a case that fails mid drag can have them released (helpers.release_all).
--- Releasing a control that isn't held crashes the game, so only these get released
---@type table<string, true>
local held = {}

---@param controls string[] one of helpers.controls
---@return TestStep
function helpers.press(controls)
  return helpers.run(function()
    for _, control in ipairs(controls) do
      game.simulation.control_down({ control = control, notify = false })
      held[control] = true
    end
  end)
end

---@param controls string[] one of helpers.controls
---@return TestStep
function helpers.release(controls)
  return helpers.run(function()
    for _, control in ipairs(controls) do
      game.simulation.control_up({ control = control })
      held[control] = nil
    end
  end)
end

--- Let go of whatever is still held
function helpers.release_all()
  for control in pairs(held) do
    game.simulation.control_up({ control = control })
  end
  held = {}
end

--- Drag from one position to another, then let go. Waits a few ticks for the mod to place things
---@param control string[] one of helpers.controls
---@param ... MapPosition the path: start, then every point the cursor moves through
---@return TestStep[]
function helpers.drag(control, ...)
  local path = { ... }
  local list = { helpers.move_to(path[1]), helpers.press(control) }
  for i = 2, #path do table.insert(list, helpers.move_to(path[i])) end
  table.insert(list, helpers.release(control))
  table.insert(list, helpers.wait(10))
  return list
end

---@param control string
---@return TestStep[]
function helpers.press_and_release(control)
  return {
    helpers.run(function() game.simulation.control_press({ control = control, notify = false }) end),
    helpers.wait(10),
  }
end

---@param x number
---@param y number
---@return string
local function key(x, y)
  return string.format("%.1f,%.1f", x, y)
end

local DIRECTION_NAMES = {}
for name, value in pairs(defines.direction) do DIRECTION_NAMES[value] = name end

---@param direction defines.direction?
---@return string
function helpers.direction_name(direction)
  return tostring(DIRECTION_NAMES[direction])
end

---@param condition any
---@param message string
function helpers.check(condition, message)
  if not condition then error(message, 0) end
end

---@param expected any
---@param actual any
---@param what string
function helpers.check_equal(expected, actual, what)
  if expected ~= actual then
    error(what .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 0)
  end
end

--- Belt line positions along y = 0.5 (or another row), from x to x, tile centers
---@param from_x number
---@param to_x number
---@param y number?
---@return MapPosition[]
function helpers.row(from_x, to_x, y)
  local list = {}
  local step = from_x <= to_x and 1 or -1
  for x = from_x, to_x, step do table.insert(list, { x, y or 0.5 }) end
  return list
end

---@param ctx TestContext
---@param name string
---@param position MapPosition
---@param direction defines.direction
---@param extra table?
---@return LuaEntity
function helpers.place(ctx, name, position, direction, extra)
  local params = { name = name, position = position, direction = direction, force = "player" }
  for k, v in pairs(extra or {}) do params[k] = v end
  local entity = ctx.surface.create_entity(params)
  helpers.check(entity, "setup: couldn't place " .. name .. " at " .. key(position[1], position[2]))
  ---@cast entity LuaEntity
  return entity
end

---@param ctx TestContext
---@param ghost_name string
---@param position MapPosition
---@param direction defines.direction
---@return LuaEntity
function helpers.place_ghost(ctx, ghost_name, position, direction)
  return helpers.place(ctx, "entity-ghost", position, direction, { ghost_name = ghost_name })
end

---@param ctx TestContext
---@param position MapPosition
---@param name string entity name, or for ghosts the ghosted entity's name
---@param ghost boolean?
---@return LuaEntity?
function helpers.find(ctx, position, name, ghost)
  if ghost then
    return ctx.surface.find_entities_filtered({ position = position, name = "entity-ghost", ghost_name = name })[1]
  end
  return ctx.surface.find_entities_filtered({ position = position, name = name })[1]
end

--- Check there's a `name` at position facing direction, returns it
---@param ctx TestContext
---@param position MapPosition
---@param name string
---@param direction defines.direction?
---@param ghost boolean?
---@return LuaEntity
function helpers.expect(ctx, position, name, direction, ghost)
  local entity = helpers.find(ctx, position, name, ghost)
  local where = (ghost and "ghost " or "") .. name .. " at " .. key(position[1], position[2])
  if not entity then
    local found = {}
    for _, e in pairs(ctx.surface.find_entities_filtered({ position = position })) do
      if e.type ~= "character" then
        table.insert(found, e.name == "entity-ghost" and ("ghost " .. e.ghost_name) or e.name)
      end
    end
    error("no " .. where .. " (found: " .. (#found > 0 and table.concat(found, ", ") or "nothing") .. ")", 0)
  end
  ---@cast entity LuaEntity
  if direction and entity.direction ~= direction then
    error(where .. " faces " .. helpers.direction_name(entity.direction) ..
      ", expected " .. helpers.direction_name(direction), 0)
  end
  return entity
end

---@param ctx TestContext
---@param position MapPosition
---@param name string
---@param ghost boolean?
function helpers.expect_none(ctx, position, name, ghost)
  helpers.check(not helpers.find(ctx, position, name, ghost),
    "unexpected " .. (ghost and "ghost " or "") .. name .. " at " .. key(position[1], position[2]))
end

--- Number of `item` in the test player's main inventory
---@param ctx TestContext
---@param item string
---@return integer
function helpers.count(ctx, item)
  local inventory = ctx.player.get_main_inventory()
  return inventory and inventory.get_item_count(item) or 0
end

---@param belt LuaEntity
---@return integer
function helpers.items_on_belt(belt)
  local total = 0
  for i = 1, belt.get_max_transport_line_index() do
    total = total + belt.get_transport_line(i --[[@as defines.transport_line]]).get_item_count()
  end
  return total
end

--- Sprite names of the visible Belt Draw preview, keyed by tile ("x,y")
---@return table<string, string>
function helpers.preview_sprites()
  local sprites = {}
  for _, object in pairs(rendering.get_all_objects("belt-draw")) do
    if object.valid and object.type == "sprite" and object.visible then
      local target = object.target
      local position = target and (target.position or target)
      if position and position.x then
        sprites[key(position.x, position.y)] = object.sprite
      end
    end
  end
  return sprites
end

---@param sprites table<string, string>
---@param position MapPosition
---@return string?
function helpers.sprite_at(sprites, position)
  return sprites[key(position[1], position[2])]
end

--- Whether the test player can build at position. Worked out here rather than with the mod's can_reach,
--- so a bug there can't hide itself
---@param ctx TestContext
---@param position MapPosition
---@return boolean
function helpers.in_reach(ctx, position)
  local dx = ctx.player.position.x - position[1]
  local dy = ctx.player.position.y - position[2]
  local distance = ctx.player.build_distance
  return dx * dx + dy * dy < distance * distance
end

--- Put a Belt Draw tool in the test player's cursor, the normal tier one by default
---@param ctx TestContext
---@param tool string? e.g. "belt-draw-fast-preview"
function helpers.hold_tool(ctx, tool)
  ctx.player.cursor_stack.set_stack({ name = tool or "belt-draw-preview" })
end

--- Press and release a control, or a mod's custom input, without moving the cursor
---@param control string
---@return TestStep
function helpers.tap(control)
  return helpers.run(function() game.simulation.control_press({ control = control, notify = false }) end)
end

--- Check the visible preview covers exactly these tiles
---@param positions MapPosition[]
function helpers.expect_preview_exactly(positions)
  local sprites = helpers.preview_sprites()
  local expected = {}
  for _, position in ipairs(positions) do
    local tile = key(position[1], position[2])
    expected[tile] = true
    helpers.check(sprites[tile], "no preview at " .. tile)
  end
  for tile in pairs(sprites) do
    helpers.check(expected[tile], "leftover preview at " .. tile)
  end
end

--- Water along y = 0.5 from from_x to to_x (tile corners), with landfill as the cover tile
---@param ctx TestContext
---@param from_x integer
---@param to_x integer
function helpers.water(ctx, from_x, to_x)
  -- the cover tile is a per surface and force setting, a fresh map has none
  local landfill = ctx.player.force.technologies["landfill"] ---@type LuaTechnology
  landfill.researched = true
  ctx.surface.set_default_cover_tile(ctx.player.force, "water", "landfill")
  local tiles = {}
  for x = from_x, to_x do table.insert(tiles, { name = "water", position = { x, 0 } }) end
  ctx.surface.set_tiles(tiles)
end

---@param ctx TestContext
---@param item string
---@param count integer
function helpers.give(ctx, item, count)
  ctx.player.insert({ name = item, count = count })
end

--- unit_number of each entity, to check later that they are the same entities (rotated, not rebuilt)
---@param entities LuaEntity[]
---@return integer[]
function helpers.unit_numbers(entities)
  local list = {}
  for i, entity in ipairs(entities) do list[i] = entity.unit_number end
  return list
end

return helpers
