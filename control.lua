if script.active_mods["gvv"] then require("__gvv__.gvv")() end

require("src/storage")
require("src/util")
require("src/place")
require("src/deconstruct")
require("src/events/cursor_stack")
require("src/events/anchor")
require("src/events/select")
require("src/events/tier")
require("src/events/flip")
require("src/events/build")

if settings.startup["belt-draw-run-tests"].value then
  require("tests/control")
end
