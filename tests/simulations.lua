-- Replaces the main menu simulations when the hidden "belt-draw-run-tests" setting is on (see tests/run.sh).
-- Simulations get real cursor input, so selection events fire like they do for a player, which scripts can't fake
return {
  belt_draw_tests = {
    checkboard = true,
    mods = { "belt-draw" },
    -- the runner stops the game once the tests are done, this only has to be long enough
    length = 60 * 60 * 10,
    init = [[
      remote.call("belt-draw-tests", "run")
    ]],
  },
}
