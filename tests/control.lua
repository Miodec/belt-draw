-- Runs the test cases inside the main menu simulation, one after the other.
-- Results go to the log as "BELT-DRAW-TEST ..." lines, tests/run.sh reads them from there

-- the runner handles any event and pcall results, which the checker can't type
---@diagnostic disable: no-unknown

local cases = require("tests/cases")
local helpers = require("tests.helpers")

local PREFIX = "BELT-DRAW-TEST "
local DEFAULT_TIMEOUT = 60 * 20

---@class TestContext
---@field player LuaPlayer
---@field surface LuaSurface
---@field step_tick integer ticks spent in the current step so far
---@field data table scratch space for the current case, cleared between cases

---@alias TestStep fun(ctx: TestContext): boolean? returns true once done, errors to fail the test

---@class TestCase
---@field name string
---@field setup fun(ctx: TestContext)? runs before the first step, errors fail the case
---@field steps TestStep[]
---@field timeout integer? ticks, defaults to 20 seconds

-- a simulation can't be saved, so plain locals are fine here
---@type TestContext?
local ctx = nil
local case_index = 0
local step_index = 0
local case_tick = 0
local passed = 0
local failed = 0

-- the result lines on the map, newest first
---@type LuaRenderObject[]
local results = {}
---@type LuaRenderObject?
local summary = nil
---@type LuaRenderObject?
local running = nil

local function report(line)
  log(PREFIX .. line)
  game.print(line)
end

-- results go on the map right of the main menu, which covers the middle of the screen (see the camera in run)
local RESULTS_X = 42
local RESULTS_TOP = -26
local LINE_SCALE = 2.5
local LINE_HEIGHT = 1.4
-- the running line and the results start under the summary
local FIRST_LINE = RESULTS_TOP + 3

--- The passed and failed counts at the top of the results, kept up to date as cases finish
local function update_summary()
  if not ctx then return end
  local text = passed .. " passed, " .. failed .. " failed"
  if case_index <= #cases then
    text = text .. " (" .. (passed + failed) .. "/" .. #cases .. ")"
  end
  local color = failed == 0 and { 1, 1, 1 } or { 1, 0.3, 0.3 }
  if summary and summary.valid then
    summary.text = text
    summary.color = color
    return
  end
  summary = rendering.draw_text({
    text = text,
    surface = ctx.surface,
    target = { RESULTS_X, RESULTS_TOP },
    color = color,
    scale = 5,
  })
end

--- The case being run, above the results. Nil removes it
---@param name string?
local function show_running(name)
  if running and running.valid then running.destroy() end
  running = nil
  if not ctx or not name then return end
  running = rendering.draw_text({
    text = "RUNNING " .. name,
    surface = ctx.surface,
    target = { RESULTS_X, FIRST_LINE },
    color = { 1, 0.8, 0.2 },
    scale = LINE_SCALE,
  })
end

--- A line per case under the running line, the newest on top pushes the others down
---@param text string
---@param color Color
local function show_result(text, color)
  if not ctx then return end
  for i, line in ipairs(results) do
    line.target = { RESULTS_X, FIRST_LINE + (i + 1) * LINE_HEIGHT }
  end
  table.insert(results, 1, rendering.draw_text({
    text = text,
    surface = ctx.surface,
    target = { RESULTS_X, FIRST_LINE + LINE_HEIGHT },
    color = color,
    scale = LINE_SCALE,
  }))
  update_summary()
end

--- What the map and the mod looked like when a case failed, only goes to the log
local function dump_state()
  if not ctx then return end
  local entities = {}
  for _, e in pairs(ctx.surface.find_entities_filtered({ area = { { -20, -15 }, { 20, 15 } } })) do
    if e.type ~= "character" then
      local name = e.name == "entity-ghost" and ("ghost " .. e.ghost_name) or e.name
      table.insert(entities, string.format("%s@%.1f,%.1f/%s", name, e.position.x, e.position.y, tostring(e.direction)))
    end
  end
  log(PREFIX .. "  entities: " .. (#entities > 0 and table.concat(entities, " ") or "none"))
  local inventory = ctx.player.get_main_inventory()
  local items = {}
  for _, item in pairs(inventory and inventory.get_contents() or {}) do
    table.insert(items, item.name .. "=" .. item.count)
  end
  log(PREFIX .. "  inventory: " .. (#items > 0 and table.concat(items, " ") or "empty") ..
    ", player at " .. ctx.player.position.x .. "," .. ctx.player.position.y ..
    ", controller " .. tostring(ctx.player.controller_type) .. ", build distance " .. tostring(ctx.player.build_distance))
  local state = get_state(ctx.player)
  log(PREFIX .. "  mod state: dragging " .. tostring(state.dragging) .. ", segments " .. #state.segments ..
    ", selection mode " .. tostring(state.selection_mode))
end

---@param case TestCase
---@param reason string
local function fail(case, reason)
  failed = failed + 1
  report("FAIL " .. case.name .. ": " .. reason)
  dump_state()
  show_result("FAIL " .. case.name .. ": " .. reason, { 1, 0.3, 0.3 })
end

---@param case TestCase
local function pass(case)
  passed = passed + 1
  report("PASS " .. case.name)
  show_result("PASS " .. case.name, { 0.3, 1, 0.3 })
end

--- Clear everything the previous case left behind
local function reset()
  if not ctx then return end
  -- a case that failed mid drag leaves its buttons held, which would break the next case's drags
  helpers.release_all()
  if ctx.player.controller_type == defines.controllers.remote then
    ctx.player.exit_remote_view()
  end
  ctx.player.clear_cursor()
  ctx.player.clear_items_inside()
  settings.get_player_settings(ctx.player)["belt-draw-out-of-reach-ghosts"] = { value = false }
  -- other test players (multiplayer cases) may have drawings going too
  for _, player in pairs(game.players) do
    cleanup(player, false)
  end
  ctx.data = {}
  -- cases may change tiles (water)
  ctx.surface.build_checkerboard({ { -20, -15 }, { 20, 15 } })
  for _, entity in pairs(ctx.surface.find_entities_filtered({ area = { { -20, -15 }, { 20, 15 } } })) do
    -- characters of the test players stay, ones a case placed go
    if entity.valid and not (entity.type == "character" and entity.player) then
      entity.destroy()
    end
  end
  local stack = ctx.player.undo_redo_stack
  while stack.get_undo_item_count() > 0 do stack.remove_undo_item(1) end
  while stack.get_redo_item_count() > 0 do stack.remove_redo_item(1) end
  ctx.player.teleport({ 0, 5.5 })
  game.simulation.camera_player_cursor_position = ctx.player.position
end

local function start_case()
  case_index = case_index + 1
  step_index = 1
  case_tick = 0
  local case = cases[case_index]
  if not case then
    -- the last case may have left a tool in the cursor, its build preview would look like part of the result
    if ctx then
      ctx.player.clear_cursor()
      cleanup(ctx.player, false)
    end
    report("DONE " .. passed .. " passed, " .. failed .. " failed")
    show_running(nil)
    update_summary()
    return
  end
  reset()
  show_running(case.name)
  ctx.step_tick = 0
  if case.setup then
    local ok, err = pcall(case.setup, ctx)
    if not ok then
      fail(case, "setup: " .. tostring(err))
      start_case()
    end
  end
end

script.on_event(defines.events.on_tick, function()
  if not ctx then return end
  local case = cases[case_index]
  if not case then return end

  case_tick = case_tick + 1
  if case_tick > (case.timeout or DEFAULT_TIMEOUT) then
    fail(case, "timed out in step " .. step_index)
    start_case()
    return
  end

  local step = case.steps[step_index]
  local ok, result = pcall(step, ctx)
  if not ok then
    fail(case, "step " .. step_index .. ": " .. tostring(result))
    start_case()
    return
  end

  ctx.step_tick = ctx.step_tick + 1
  if result then
    step_index = step_index + 1
    ctx.step_tick = 0
    if step_index > #case.steps then
      pass(case)
      start_case()
    end
  end
end)

-- An error in the mod stops the simulation with an error screen and never reaches the log, so the run could
-- only time out. Catch errors in every handler the mod registered instead, log the traceback and fail the case
local event_names = {}
for name, id in pairs(defines.events) do event_names[id] = name end
local event_types = {}
for id in pairs(event_names) do
  if id ~= defines.events.on_tick then table.insert(event_types, id) end
end
for name in pairs(prototypes.custom_input) do table.insert(event_types, name) end
for _, event_type in pairs(event_types) do
  local original = script.get_event_handler(event_type)
  if original then
    script.on_event(event_type, function(event)
      local ok, err = xpcall(original, debug.traceback, event)
      if ok then return end
      local name = event_names[event_type] or event_type
      log(PREFIX .. "ERROR in " .. name .. ": " .. tostring(err))
      local case = cases[case_index]
      if case then
        fail(case, "mod error in " .. name .. ": " .. tostring(err):match("^[^\n]*"))
        start_case()
      end
    end)
  end
end

-- set to true to log every selection, cursor and build event the mod gets, for working out why a case fails
local TRACE = false
if TRACE then
  for _, name in pairs({
    "on_player_start_selected_area", "on_player_change_selected_area", "on_player_cancel_selected_area",
    "on_player_selected_area", "on_player_alt_selected_area", "on_player_reverse_selected_area",
    "on_player_super_forced_selected_area", "on_player_cursor_stack_changed", "on_built_entity",
  }) do
    local id = defines.events[name]
    -- wrap the mod's own handler, an event only has one handler per mod
    local original = script.get_event_handler(id)
    script.on_event(id, function(event)
      ---@type {tick: integer, player_index: integer, cursor_position: {x: number, y: number}?, entity: LuaEntity?}
      event = event
      local cursor = game.get_player(event.player_index).cursor_stack
      log(PREFIX .. "  event " .. name .. " tick " .. event.tick ..
        (event.cursor_position and string.format(" at %.1f,%.1f", event.cursor_position.x, event.cursor_position.y) or "") ..
        (event.entity and (" entity " .. event.entity.name) or "") ..
        " cursor " .. (cursor and cursor.valid_for_read and cursor.name or "empty"))
      if original then original(event) end
    end)
  end
end

remote.add_interface("belt-draw-tests", {
  run = function()
    local player = game.simulation.create_test_player({ name = "tester" })
    game.simulation.camera_player = player
    -- the main menu covers the middle of the screen and can't be hidden, so the camera looks to the right of
    -- the test area (x -15 to 15), which leaves it on the left of the menu
    game.simulation.camera_position = { 28, 2 }
    game.simulation.camera_zoom = 0.5
    ctx = { player = player, surface = player.surface, step_tick = 0, data = {} }
    report("START " .. #cases .. " cases")
    update_summary()
    start_case()
  end,
})
