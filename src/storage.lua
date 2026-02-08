---@class StorageData
---@field rendering_target LuaEntity?
---@field starting_direction defines.direction?
---@field dragging boolean
---@field player_reach number?
---@field segments Segment[]
---@field current_segment Segment?
---@field current_tier BeltTier

---@type StorageData
storage = storage

-- Initialize global state
script.on_init(function()
  storage.starting_direction = nil
  storage.dragging = false
  storage.player_reach = nil
  storage.segments = {}
  storage.current_segment = nil
  storage.current_tier = "normal"
end)

script.on_configuration_changed(function()
  storage.starting_direction = storage.starting_direction or nil
  storage.dragging = storage.dragging or false
  storage.player_reach = storage.player_reach or nil
  storage.segments = {}
  storage.current_segment = nil
  storage.current_tier = storage.current_tier or "normal"
end)
