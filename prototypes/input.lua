return {
  {
    type = "custom-input",
    name = "belt-draw-flip-orientation",
    key_sequence = "F",
    order = "a[mod]-b[belt-draw-flip]",
  },
  {
    type = "custom-input",
    name = "belt-draw-anchor",
    key_sequence = "R",
    order = "a[mod]-b[belt-draw-anchor]",
  },
  {
    type = "custom-input",
    name = "belt-draw-next-tier",
    key_sequence = "SHIFT + mouse-wheel-up",
    consuming = "game-only",
    order = "a[mod]-b[belt-draw-next-tier]",
  },
  {
    type = "custom-input",
    name = "belt-draw-previous-tier",
    key_sequence = "SHIFT + mouse-wheel-down",
    consuming = "game-only",
    order = "a[mod]-b[belt-draw-previous-tier]",
  },
}
