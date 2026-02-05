local tiers = require("tiers")
local Segment = require("src.segment")

---@param pos Position
---@param player LuaPlayer
function add_segment(pos, player)
  local segment = Segment.new(pos, storage.starting_direction, player, #storage.segments + 1, storage.current_tier)
  table.insert(storage.segments, segment)
  storage.current_segment = segment

  for _, seg in pairs(storage.segments) do
    seg:update_max_segment_id(#storage.segments)
  end
end

---@param player LuaPlayer
---@param setTool boolean
function cleanup(player, setTool)
  for _, segment in pairs(storage.segments) do
    segment:destroy()
  end
  storage.segments = {}
  storage.current_segment = nil
  storage.dragging = false
  if setTool == nil or setTool == true then
    set_tool(player)
  end
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

---@param entity LuaEntity
---@return boolean
function is_bd_entity(entity)
  local name = entity.name
  if entity.type == "entity-ghost" then
    name = entity.ghost_name
  end

  if name == "belt-draw-dummy-entity" then
    return true
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
      local tier_info = belt_tier and tiers[belt_tier] or tiers[storage.current_tier]

      storage.current_tier = tier_info.name
      cursor_stack.set_stack({ name = storage.dragging and tier_info.tool or tier_info.preview_tool })

      if notify then
        player.create_local_flying_text({
          text = { tiers[storage.current_tier].string },
          create_at_cursor = true
        })
      end
    end
  end
end
