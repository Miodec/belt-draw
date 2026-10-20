---@param event EventData.CustomInputEvent
script.on_event("bd_build_pressed", function(event)
  local player = game.get_player(event.player_index)
  if not player or not is_holding_bd_tool(player) then return end

  get_state(player).starting_direction = event.cursor_direction or defines.direction.north
end)
