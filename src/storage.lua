---@class PlayerState
---@field starting_direction defines.direction?
---@field dragging boolean
---@field swapping_tool boolean
---@field restarting_selection boolean
---@field segments Segment[]
---@field current_segment Segment?
---@field current_tier BeltTier
---@field selection_mode SelectionMode?
---@field draw_alt boolean?
---@field super_forced boolean?
---@field hide_preview boolean?
---@field node_cache table<number, table<number, table<defines.direction|-1, NodeInfo>>>? surface lookups for the current drawing, see Segment:node_info

---@class StorageData
---@field players table<integer, PlayerState>

---@type StorageData
storage = storage

local tiers = require("src.tiers")

---@param tier BeltTier?
---@return PlayerState
local function new_player_state(tier)
  return {
    starting_direction = nil,
    dragging = false,
    swapping_tool = false,
    restarting_selection = false,
    segments = {},
    current_segment = nil,
    -- the tier may no longer exist, e.g. turbo after disabling space age
    current_tier = tier and tiers[tier] and tier or "normal",
  }
end

--- Every player draws on their own, so all drawing state is kept per player
---@param player LuaPlayer|integer player or player index
---@return PlayerState
function get_state(player)
  local index = type(player) == "number" and player or player.index
  -- a script reload doesn't run on_configuration_changed, so players may not exist yet
  storage.players = storage.players or {}
  local state = storage.players[index]
  if not state then
    state = new_player_state()
    storage.players[index] = state
  end
  return state
end

-- Initialize global state
script.on_init(function()
  storage.players = {}
end)

script.on_configuration_changed(function()
  -- before multiplayer support everything was shared, keep the tier but drop the old fields
  local old_tier = storage.current_tier
  for _, key in pairs({ "starting_direction", "dragging", "swapping_tool", "restarting_selection", "player_reach",
    "segments", "current_segment", "current_tier", "selection_mode", "draw_alt", "super_forced", "hide_preview" }) do
    storage[key] = nil
  end

  -- a drawing in progress can't survive a mod update, start everyone fresh
  local old_players = storage.players or {}
  storage.players = {}
  for index, state in pairs(old_players) do
    storage.players[index] = new_player_state(state.current_tier)
  end
  if old_tier then
    for index in pairs(game.players) do
      if not storage.players[index] then
        storage.players[index] = new_player_state(old_tier)
      end
    end
  end
end)

script.on_event(defines.events.on_player_removed, function(event)
  if not storage.players then return end
  local state = storage.players[event.player_index]
  if state then
    for _, segment in pairs(state.segments) do
      if segment.destroy then segment:destroy() end
    end
  end
  storage.players[event.player_index] = nil
end)
