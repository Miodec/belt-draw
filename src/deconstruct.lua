local BELT_TYPES = {
  ["transport-belt"] = true,
  ["underground-belt"] = true,
  ["splitter"] = true,
}

---@param player LuaPlayer
---@param entities LuaEntity[] entities from the selection event
function deconstruct(player, entities)
  -- mark entities for deconstruction
  local num = 0
  for _, e in pairs(entities) do
    if not e.valid then
      goto continue
    end
    -- ghost_type covers ghosts of every belt tier, not just the yellow ones
    local type = e.type == "entity-ghost" and e.ghost_type or e.type
    if not BELT_TYPES[type] then
      goto continue
    end
    e.order_deconstruction(player.force, player, (num == 0) and 0 or 1)
    num = num + 1
    ::continue::
  end

  cleanup(player, true)
end
