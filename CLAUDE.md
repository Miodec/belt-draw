# Belt Draw (Factorio 2.1 mod)

- `GLOSSARY.md`: the words for drawing modes, segments, tools and planning. Use them in code, tests and replies.
- `tests/run.sh`: in-game tests, run after changing `src/` (opens a Factorio window). `ONLY=<file or case name>` runs a subset. Cases in `tests/cases/`, how it works in the script's header.
- `tools/check.sh`: type check against the Factorio API, run before finishing a change.
- `tools/api.py NAME`: the installed game's API docs (parameters, call style, read-only fields). Look up an API before relying on it.
- `tools/cpuprofile.py PROFILE`: summarise a `.cpuprofile` from `script-output/`.
- Game log: `~/Library/Application Support/factorio/factorio-current.log`. Script changes reload with simple-mod-reload; prototype (data stage) changes need a game restart.
- `docs/factorio-notes.md`: Factorio 2.1 behaviour the API docs don't cover (selection tools, blueprints, undo, simulations). Read before changing placement, undo or the tests.
- Review rules: `CODING_STANDARDS.md`.
