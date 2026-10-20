data:extend({
  {
    type = "bool-setting",
    name = "belt-draw-replace-belt-with-tool",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "belt-draw-out-of-reach-ghosts",
    setting_type = "runtime-per-user",
    default_value = false,
    order = "b",
  },
  {
    -- turns the main menu into the test runner, see tests/run.sh. Hidden, it's only set by the test runner
    type = "bool-setting",
    name = "belt-draw-run-tests",
    setting_type = "startup",
    default_value = false,
    hidden = true,
  },
  {
    -- which tests to run (tests/run.sh ONLY=...), empty runs them all. Hidden, only set by the test runner
    type = "string-setting",
    name = "belt-draw-test-filter",
    setting_type = "startup",
    default_value = "",
    allow_blank = true,
    hidden = true,
  },
})
