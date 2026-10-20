local tiers = require("src.tiers")
local Segment = require("src.segment")

---@param pos Position
---@param player LuaPlayer
function add_segment(pos, player)
  local state = get_state(player)
  if state.current_segment then
    -- current segment is nil for the first segment
    state.current_segment:remove_last_node()
  end

  local segment = Segment.new(pos, state.starting_direction, player, #state.segments + 1, state.current_tier,
    state.current_segment)
  table.insert(state.segments, segment)
  state.current_segment = segment
end

---@param player LuaPlayer
---@param setTool boolean
function cleanup(player, setTool)
  local state = get_state(player)
  for _, segment in pairs(state.segments) do
    if segment.destroy then segment:destroy() end
  end
  state.segments = {}
  state.current_segment = nil
  state.node_cache = nil
  state.dragging = false
  if setTool == nil or setTool == true then
    set_tool(player)
  end
end

--- Whether out of reach nodes of an inventory drawing get built as ghosts (the player's setting), or are left out
---@param player LuaPlayer
---@return boolean
function out_of_reach_ghosts(player)
  return settings.get_player_settings(player)["belt-draw-out-of-reach-ghosts"].value --[[@as boolean]]
end

--- Whether a player standing at position can build at x, y. Anything further away gets built as a ghost
---@param position MapPosition the player's position
---@param build_distance number
---@param x number
---@param y number
---@return boolean
function can_reach(position, build_distance, x, y)
  local dx = position.x - x
  local dy = position.y - y
  return dx * dx + dy * dy < build_distance * build_distance
end

---@param position MapPosition
---@return {x: number, y: number}
function to_tile_center(position)
  local x = position.x or position[1]
  local y = position.y or position[2]
  return { x = math.floor(x) + 0.5, y = math.floor(y) + 0.5 }
end

---@param tool_name string
---@return boolean
function is_bd_tool(tool_name)
  for _, tier in pairs(tiers) do
    if tool_name == tier.tool or tool_name == tier.preview_tool then
      return true
    end
  end
  return false
end

---@param player LuaPlayer
---@return boolean
function is_holding_bd_tool(player)
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil then return false end
  if not cursor_stack.valid_for_read then return false end
  if not is_bd_tool(cursor_stack.name) then return false end
  return true
end

---@param player LuaPlayer
---@return boolean
function is_holding_bd_preview_tool(player)
  local cursor_stack = player.cursor_stack
  if cursor_stack == nil then return false end
  if not cursor_stack.valid_for_read then return false end
  for _, tier in pairs(tiers) do
    if cursor_stack.name == tier.preview_tool then
      return true
    end
  end
  return false
end

---@param entity LuaEntity
---@return boolean
function is_bd_entity(entity)
  local name = entity.name
  if entity.type == "entity-ghost" then
    name = entity.ghost_name
  end


  for _, tier in pairs(tiers) do
    if name == tier.dummy then
      return true
    end
  end
  return false
end

---@param player LuaPlayer
---@param belt_tier BeltTier?
---@param notify boolean?
function set_tool(player, belt_tier, notify)
  local cursor_stack = player.cursor_stack
  if cursor_stack then
    if not cursor_stack.valid_for_read or is_bd_tool(cursor_stack.name) or player.clear_cursor() then
      local state = get_state(player)
      local tier_info = belt_tier and tiers[belt_tier] or tiers[state.current_tier]

      state.current_tier = tier_info.name
      cursor_stack.set_stack({ name = state.dragging and tier_info.tool or tier_info.preview_tool })

      if notify then
        player.create_local_flying_text({
          text = { tier_info.string },
          create_at_cursor = true
        })
      end
    end
  end
end
