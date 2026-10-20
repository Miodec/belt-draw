# Belt Draw

A Factorio mod for laying belts by dragging a path with a tool: it plans the belts, undergrounds and joins along the way and builds them on release.

## Drawing

**Drawing**:
Dragging a Belt Draw tool from press to release, and the belt path that drag lays down.
_Avoid_: painting, placing

**Inventory drawing**:
Drawing that builds real belts from the player's inventory, within reach and outside map view.
_Avoid_: normal mode, normal drawing

**Blueprint drawing**:
Drawing that builds ghosts instead: while holding Shift, in map view, and for any inventory drawing part out of reach.
_Avoid_: alt mode, ghost mode, shift drawing

**Super forced drawing**:
Blueprint drawing (CTRL + Shift) that marks whatever is in the way for removal and builds straight through it instead of going under.
_Avoid_: force mode

**Deconstructing**:
Reverse dragging with a Belt Draw tool, which marks the belts in the area for removal and leaves everything else.
_Avoid_: erasing

**Out of reach**:
Beyond the character's build distance; that part of a drawing becomes blueprint drawing.

## Shape

**Segment**:
One L-shaped stretch of a drawing, from where it starts to the cursor. A drawing is one or more segments.
_Avoid_: line, leg

**Node**:
One tile of a segment, with the direction the belt there will face.
_Avoid_: cell, step

**Bend**:
The corner where a segment's L turns.
_Avoid_: turn, elbow

**Orientation**:
Which way a segment's L goes first, horizontal or vertical. Set by the way the cursor moves first.

**Flip**:
Switching a segment to the other orientation mid-drag (F).

**Anchor**:
The point where a new segment starts mid-drag (R), fixing the segment before it in place.
_Avoid_: waypoint, checkpoint

## Tools

**Tier**:
A belt level the tools build: yellow, fast, express or turbo.
_Avoid_: level, speed, normal (for yellow)

**Preview tool**:
The tool in the cursor before a drag, showing the belt it would place.
_Avoid_: ghost tool

**Drawing tool**:
The tool the preview tool turns into once a drag covers two tiles.
_Avoid_: real tool

**Shortcut tool**:
The tool from the shortcut bar; it turns into the preview tool of the last used tier.
_Avoid_: generic tool

## Planning

**Preview**:
The planned belts shown while dragging, only to the player drawing. Blue where they will be built as ghosts.
_Avoid_: overlay

**Obstacle**:
Anything a belt can't be built on: an entity in the way or an unbuildable tile.

**Going under**:
Carrying the drawing past an obstacle with an underground pair.
_Avoid_: tunnelling

**Underground reach**:
The most tiles a tier's underground pair can cross.

**Joining**:
Ending a drawing into an existing belt, splitter or underground facing the same way, without replacing it.
_Avoid_: connecting

**Rotating**:
Turning an existing belt of the drawn tier to the drawn direction instead of rebuilding it. Any drawing does this; undergrounds are never rotated.

**Upgrading**:
Replacing an existing belt of another tier with the drawn tier: straight away in inventory drawing, marked for robots in blueprint drawing.
_Avoid_: replacing (alone)

**Cover tile**:
The tile (landfill, foundation) blueprint drawing places under belts over water or void.

**Highlight**:
The red box on everything super forced drawing will remove, shown while dragging.
