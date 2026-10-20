-- Every test case, run in this order by tests/control.lua. The cases themselves are in tests/cases/

local files = { "inventory", "blueprint", "drawing", "tiers", "undo", "planning", "deconstruct", "regressions" }

-- tests/run.sh ONLY=... : a file name runs that file, anything else runs the cases whose name contains it
local only = settings.startup["belt-draw-test-filter"].value --[[@as string]]

local cases = {}
for _, file in ipairs(files) do
  ---@type TestCase[]
  local file_cases = require("tests.cases." .. file)
  for _, case in ipairs(file_cases) do
    if only == "" or only == file or case.name:find(only, 1, true) then
      table.insert(cases, case)
    end
  end
end
return cases
