local tiers = require("src.tiers")

script.on_event("belt-draw-cancel", function(event)
  local player = game.get_player(event.player_index) --- @diagnostic disable-line
  if not player then return end

  if not is_holding_bd_tool(player) then return end

  cleanup(player, false)

  if settings.get_player_settings(player)["belt-draw-smart-belt-building-disabled"].value then
    -- if player disabled smart belt building, this will fix cursor clear while
    local cursor_stack = player.cursor_stack
    if cursor_stack then
      if not cursor_stack.valid_for_read or is_bd_tool(cursor_stack.name) or player.clear_cursor() then
        local tier_info = tiers[storage.current_tier]

        storage.current_tier = tier_info.name
        cursor_stack.set_stack({ name = tier_info.preview_tool })
      end
    end
  else
    player.clear_cursor()
  end
end)
