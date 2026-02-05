return
{
  {
    type = "simple-entity-with-force",
    name = "belt-draw-dummy-entity",
    flags = { "not-on-map", "player-creation" },
    hidden = false,
    collision_box = { { -0.4, -0.4 }, { 0.4, 0.4 } },
    collision_mask = { layers = {} },
    selectable_in_game = false,
    hidden_in_factoriopedia = true,
    picture = {
      filename = "__core__/graphics/empty.png",
      size = 1
    },
    created_smoke = { smoke_name = "belt-draw-empty-smoke" } --- @diagnostic disable-line
  }
}
