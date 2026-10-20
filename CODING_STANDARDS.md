# Coding standards

Rules for reviewing a change. Mechanical problems are caught by `tools/check.sh` and the tests (`tests/run.sh`), so these are the judgement calls.

## Bug fixes come with a regression test

A change described as a bug fix (in the commit message, the changelog, or a comment) adds a test case that fails without the fix and passes with it: in the `tests/cases/` file for that area, or `regressions.lua` when no file fits.

- The case reproduces the bug itself: the input or state that triggered it, not a nearby happy path. A case that passes with the fix reverted proves nothing; check it by reverting the fix and running `tests/run.sh`.
- When the bug can't be reproduced in a simulation (saving and loading, multiplayer desyncs, sounds, flying text), say so in the change, and the changelog entry describes what was changed rather than claiming a fix that was never observed.
- A changelog "Fix …" line names a bug someone actually saw.

## Game data comes from the game

A value the game's prototypes already hold (underground reach, entity sizes, stack sizes, collision masks) is read from `prototypes` at runtime, not copied into the mod as a number. A copied value looks plausible and goes stale or is simply wrong: the fast and express underground reach was one tile too far, unnoticed.

## Names follow the glossary

New names, comments, test names, messages and changelog lines use the terms in `GLOSSARY.md` and none of its _Avoid_ words: "blueprint drawing" rather than "alt mode" or "shift drawing", "yellow" rather than "normal" for the tier, "drawing tool" rather than "real tool". Lines a change touches move over too; untouched code can wait. Existing identifiers like `draw_alt` stay until they're renamed on purpose.
