---@param n number
---@return number Sign of the number: 1, -1, or 0
local function sign(n)
  if n > 0 then
    return 1
  elseif n < 0 then
    return -1
  else
    return 0
  end
end


-- local findLDivergencePoint = require("divergence")
---@param start {x: number, y: number} The starting position
---@param oldFinish {x: number, y: number} The previous finish position
---@param newFinish {x: number, y: number} The new finish position
---@param direction "horizontal"|"vertical" The direction of the L: "horizontal" (horizontal first) or "vertical" (vertical first)
---@return {point: {x: number, y: number}, index: number}|nil Returns a table with point coordinates and divergence index, or nil if inputs are invalid
local function findLDivergencePoint(start, oldFinish, newFinish, direction)
  -- Validate inputs
  if not start or not newFinish then
    return nil
  end

  if not start.x or not start.y or not newFinish.x or not newFinish.y then
    return nil
  end

  -- If no oldFinish, this is the first update - diverge from start
  if not oldFinish or not oldFinish.x or not oldFinish.y then
    return { point = start, index = 0 }
  end

  if direction == "horizontal" then
    -- Horizontal-first L: go horizontal first, then vertical
    local oldCorner = { x = oldFinish.x, y = start.y }
    local newCorner = { x = newFinish.x, y = start.y }

    -- Add after line that calculates distances
    local oldHorizontalDist = math.abs(oldFinish.x - start.x)
    local newHorizontalDist = math.abs(newFinish.x - start.x)

    -- Special case: if horizontal leg collapses to zero but had length before
    if newHorizontalDist == 0 and oldHorizontalDist > 0 then
      return { point = start, index = 0 }
    end

    -- Check if they go in the same horizontal direction
    local oldXDirection = sign(oldFinish.x - start.x)
    local newXDirection = sign(newFinish.x - start.x)

    if oldXDirection ~= newXDirection and oldXDirection ~= 0 and newXDirection ~= 0 then
      -- Different horizontal directions, diverge immediately after start
      return { point = start, index = 0 }
    end

    -- Find the minimum horizontal distance (where they share the same path)
    local minHorizontalDist = math.min(oldHorizontalDist, newHorizontalDist)

    if oldHorizontalDist ~= newHorizontalDist then
      -- Diverge along the horizontal segment
      local divergencePoint = {
        x = start.x + (oldXDirection * minHorizontalDist),
        y = start.y
      }
      return { point = divergencePoint, index = minHorizontalDist }
    end

    -- Horizontal segments are the same, check vertical segments
    local oldVerticalDist = math.abs(oldFinish.y - start.y)
    local newVerticalDist = math.abs(newFinish.y - start.y)

    local oldYDirection = sign(oldFinish.y - start.y)
    local newYDirection = sign(newFinish.y - start.y)

    if oldYDirection ~= newYDirection and oldYDirection ~= 0 and newYDirection ~= 0 then
      -- Different vertical directions, diverge at the corner
      return { point = oldCorner, index = oldHorizontalDist }
    end

    local minVerticalDist = math.min(oldVerticalDist, newVerticalDist)

    if oldVerticalDist ~= newVerticalDist then
      -- Diverge along the vertical segment
      local divergencePoint = {
        x = oldCorner.x,
        y = oldCorner.y + (oldYDirection * minVerticalDist)
      }
      return { point = divergencePoint, index = oldHorizontalDist + minVerticalDist }
    end

    -- Lines are identical
    return { point = oldFinish, index = oldHorizontalDist + oldVerticalDist }
  else -- "vertical"
    -- Vertical-first L: go vertical first, then horizontal
    local oldCorner = { x = start.x, y = oldFinish.y }
    local newCorner = { x = start.x, y = newFinish.y }

    -- Calculate vertical distances
    local oldVerticalDist = math.abs(oldFinish.y - start.y)
    local newVerticalDist = math.abs(newFinish.y - start.y)

    -- Special case: if vertical leg collapses to zero but had length before
    if newVerticalDist == 0 and oldVerticalDist > 0 then
      return { point = start, index = 0 }
    end

    -- Check if they go in the same vertical direction
    local oldYDirection = sign(oldFinish.y - start.y)
    local newYDirection = sign(newFinish.y - start.y)

    if oldYDirection ~= newYDirection and oldYDirection ~= 0 and newYDirection ~= 0 then
      -- Different vertical directions, diverge immediately after start
      return { point = start, index = 0 }
    end

    -- Find the minimum vertical distance (where they share the same path)
    local minVerticalDist = math.min(oldVerticalDist, newVerticalDist)

    if oldVerticalDist ~= newVerticalDist then
      -- Diverge along the vertical segment
      local divergencePoint = {
        x = start.x,
        y = start.y + (oldYDirection * minVerticalDist)
      }
      return { point = divergencePoint, index = minVerticalDist }
    end

    -- Vertical segments are the same, check horizontal segments
    local oldHorizontalDist = math.abs(oldFinish.x - start.x)
    local newHorizontalDist = math.abs(newFinish.x - start.x)

    local oldXDirection = sign(oldFinish.x - start.x)
    local newXDirection = sign(newFinish.x - start.x)

    if oldXDirection ~= newXDirection and oldXDirection ~= 0 and newXDirection ~= 0 then
      -- Different horizontal directions, diverge at the corner
      return { point = oldCorner, index = oldVerticalDist }
    end

    local minHorizontalDist = math.min(oldHorizontalDist, newHorizontalDist)

    if oldHorizontalDist ~= newHorizontalDist then
      -- Diverge along the horizontal segment
      local divergencePoint = {
        x = oldCorner.x + (oldXDirection * minHorizontalDist),
        y = oldCorner.y
      }
      return { point = divergencePoint, index = oldVerticalDist + minHorizontalDist }
    end

    -- Lines are identical
    return { point = oldFinish, index = oldVerticalDist + oldHorizontalDist }
  end
end


return findLDivergencePoint
