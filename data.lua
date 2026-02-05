local normal_tools = require("prototypes.tools.normal")
local other_tools = require("prototypes.other")
local entities = require("prototypes.entities")
local input = require("prototypes.input")
local sprites = require("prototypes.sprites")

for _, prototype in pairs(normal_tools) do
  data:extend({ prototype })
end

for _, prototype in pairs(other_tools) do
  data:extend({ prototype })
end

for _, prototype in pairs(entities) do
  data:extend({ prototype })
end

for _, prototype in pairs(input) do
  data:extend({ prototype })
end

for _, prototype in pairs(sprites) do
  data:extend({ prototype })
end
