-- ---@param player LuaPlayer
-- ---@param area BoundingBox
-- local function on_deconstruct(player, area)
--   -- mark entities for deconstruction
--   local entities = player.surface.find_entities_filtered({
--     area = area,
--     type = { "transport-belt", "underground-belt", "splitter", "entity-ghost" },
--   })
--   local num = 0
--   for _, e in pairs(entities) do
--     if e.type == "entity-ghost" then
--       if e.ghost_name ~= "transport-belt" and e.ghost_name ~= "underground-belt" and e.ghost_name ~= "splitter" then
--         goto continue
--       end
--     end
--     e.order_deconstruction(player.force, player, (num == 0) and 0 or 1)
--     num = num + 1
--     ::continue::
--   end

--   cleanup(player, true)
-- end

-- ---@param player LuaPlayer
-- ---@param area BoundingBox
-- ---@param mode "normal"|"alt"
-- local function on_release(player, area, mode)
--   place(player, storage.segments, mode)

--   cleanup(player, true)
-- end


-- script.on_event(defines.events.on_player_selected_area, function(event)
--   if not is_bd_tool(event.item) then return end

--   local player = game.get_player(event.player_index)
--   if not player then
--     return
--   end

--   if settings.startup["belt-draw-swap-left-right-click"].value then
--     on_deconstruct(player, event.area)
--   else
--     on_release(player, event.area, "normal")
--   end
-- end)

-- script.on_event(defines.events.on_player_alt_selected_area, function(event)
--   if not is_bd_tool(event.item) then return end

--   local player = game.get_player(event.player_index)
--   if not player then
--     return
--   end


--   if settings.startup["belt-draw-swap-left-right-click"].value then
--     -- do nothing
--   else
--     on_release(player, event.area, "alt")
--   end
-- end)

-- script.on_event(defines.events.on_player_reverse_selected_area, function(event)
--   if not is_bd_tool(event.item) then return end

--   local player = game.get_player(event.player_index)
--   if not player then
--     return
--   end

--   if settings.startup["belt-draw-swap-left-right-click"].value then
--     on_release(player, event.area, "normal")
--   else
--     on_deconstruct(player, event.area)
--   end
-- end)

-- script.on_event(defines.events.on_player_alt_reverse_selected_area, function(event)
--   if not is_bd_tool(event.item) then return end

--   local player = game.get_player(event.player_index)
--   if not player then
--     return
--   end

--   if settings.startup["belt-draw-swap-left-right-click"].value then
--     on_release(player, event.area, "alt")
--   else
--     -- do nothing
--   end
-- end)

---@alias SelectionMode "select" | "alt" | "reverse" | "alt_reverse" | "super_forced"

---@type table<defines.selection_mode, SelectionMode>
local MODE_MAP = {
  [defines.selection_mode.select] = "select",
  [defines.selection_mode.alt_select] = "alt",
  [defines.selection_mode.reverse_select] = "reverse",
  [defines.selection_mode.alt_reverse_select] = "alt_reverse",
  [defines.selection_mode.super_forced_select] = "super_forced"
}

--- What a selection mode does. Players who swapped mouse buttons rebind the selection controls,
--- so select is always drawing and reverse select is always deconstructing
---@param mode SelectionMode
---@return "normal"|"alt"|"super_forced"|"deconstruct"|nil
local function get_action(mode)
  if mode == "select" then return "normal" end
  if mode == "alt" then return "alt" end
  if mode == "super_forced" then return "super_forced" end
  if mode == "reverse" then return "deconstruct" end
  return nil
end

---@param player LuaPlayer
local function swap_to_drag_tool(player)
  local state = get_state(player)
  state.dragging = true
  -- already holding it (e.g. leftovers were cleared mid-drag), nothing gets cancelled or restarted
  if not is_holding_bd_preview_tool(player) then return end
  -- swapping the cursor item cancels the current selection, ignore that cancel
  state.swapping_tool = true
  -- the game then restarts the selection while the button is held, that start continues the drawing
  state.restarting_selection = true
  set_tool(player)
end

---@param pos {x:number,y:number}
---@param player LuaPlayer
---@param mode SelectionMode
local function on_start_or_drag(pos, player, mode)
  local state = get_state(player)
  local action = get_action(mode)

  if action == "deconstruct" then
    -- no segment to wait for, switch to the real tool straight away
    if not state.dragging and is_holding_bd_preview_tool(player) then
      swap_to_drag_tool(player)
    end
    return
  end

  if action ~= "normal" and action ~= "alt" and action ~= "super_forced" then return end

  if state.current_segment == nil then
    add_segment(pos, player)
  elseif state.current_segment ~= nil then
    state.current_segment:update_to(pos)
  end

  if not state.dragging and state.current_segment and #state.current_segment.nodes >= 2 then
    swap_to_drag_tool(player)
  end
end

---@param player LuaPlayer
---@param entities LuaEntity[]
---@param mode SelectionMode
local function on_release(player, entities, mode)
  local action = get_action(mode)
  if action == "normal" or action == "alt" or action == "super_forced" then
    place(player, get_state(player).segments, action)
    cleanup(player, true)
  elseif action == "deconstruct" then
    deconstruct(player, entities)
  end
end

---@param event EventData.on_player_start_selected_area|EventData.on_player_change_selected_area
local function on_selecting(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if not is_holding_bd_tool(player) then return end

  local state = get_state(player)
  local mode = MODE_MAP[event.selection_mode]
  if mode ~= state.selection_mode then
    -- holding/releasing shift mid selection switches between select and alt select
    state.selection_mode = mode

    local action = get_action(mode)

    local draw_alt = action == "alt"
    if draw_alt ~= state.draw_alt then
      state.draw_alt = draw_alt
      for _, segment in pairs(state.segments) do
        -- alt mode can build over water with landfill, so the plan changes too
        segment:replan()
        segment:apply_alt_sprites()
      end
    end

    -- super forced deconstructs obstacles instead of undergrounding, so the plan changes
    local super_forced = action == "super_forced"
    if super_forced ~= state.super_forced then
      state.super_forced = super_forced
      for _, segment in pairs(state.segments) do
        segment:replan()
        segment:apply_alt_sprites()
      end
    end

    -- deconstructing, the belt preview would only get in the way
    local hide_preview = action == "deconstruct"
    if hide_preview ~= state.hide_preview then
      state.hide_preview = hide_preview
      for _, segment in pairs(state.segments) do
        segment:apply_visibility()
      end
    end
  end

  on_start_or_drag(to_tile_center(event.cursor_position), player, mode)
end

script.on_event(defines.events.on_player_start_selected_area, function(event)
  local state = get_state(event.player_index)
  state.swapping_tool = false

  -- a start right after the tool swap is the same selection restarting, keep the drawing
  local restarting = state.restarting_selection
  state.restarting_selection = false

  -- anything else is a new selection, so segments are leftovers from one that never finished
  -- (a missed cancel event, or a save made mid-drag being loaded)
  local player = game.get_player(event.player_index)
  if player and not restarting and #state.segments > 0 and is_holding_bd_tool(player) then
    -- don't set the tool, swapping it would cancel the selection that is just starting
    cleanup(player, false)
  end

  on_selecting(event)
end)

script.on_event(defines.events.on_player_change_selected_area, on_selecting)

script.on_event(defines.events.on_player_cancel_selected_area, function(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local state = get_state(player)
  if not state.dragging then
    return
  end

  if state.swapping_tool then
    state.swapping_tool = false
    return
  end


  if not is_holding_bd_tool(player) then return end
  cleanup(player, true)
end)

---@param mode SelectionMode
local function release_handler(mode)
  ---@param event EventData.on_player_selected_area
  return function(event)
    if not is_bd_tool(event.item) then return end

    local player = game.get_player(event.player_index)
    if not player then
      return
    end

    on_release(player, event.entities, mode)
  end
end

script.on_event(defines.events.on_player_selected_area, release_handler("select"))
script.on_event(defines.events.on_player_alt_selected_area, release_handler("alt"))
script.on_event(defines.events.on_player_reverse_selected_area, release_handler("reverse"))
script.on_event(defines.events.on_player_alt_reverse_selected_area, release_handler("alt_reverse"))
script.on_event(defines.events.on_player_super_forced_selected_area, release_handler("super_forced"))

-- entering/leaving remote view switches between normal and alt sprites
script.on_event(defines.events.on_player_controller_changed, function(event)
  for _, segment in pairs(get_state(event.player_index).segments) do
    segment:apply_alt_sprites()
  end
end)
