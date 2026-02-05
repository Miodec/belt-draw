script.on_event("belt-draw-flip-orientation", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bd_tool(player) then return end
  if storage.current_segment == nil then return end

  storage.current_segment:flip_orientation()
  player.create_local_flying_text({
    text = { "belt-draw.flipped" },
    create_at_cursor = true
  })
end)
