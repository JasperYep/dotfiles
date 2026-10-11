# prompt-refiner

A pi extension that rewrites the draft prompt in your editor before you send it,
using a separate (usually cheaper) model.

```text
/refine              refine the current editor draft
/refine <prompt>     refine the given text
/refine undo         put the pre-refinement draft back
/refine reload       re-read config.json without restarting pi
```

The result replaces the editor text directly; there is no confirmation dialog.
`/refine undo` restores the previous draft, and Escape cancels a refinement that
is still running.

## Config

Optional. Defaults live in `core.ts`; a JSON file and environment variables
override them, in that order.

`~/.pi/agent/extensions/prompt-refiner/config.json` (see
`config.example.json`):

| Key | Default | Meaning |
| --- | --- | --- |
| `model` | `"cp"` | Model id used for refinement. `null` follows the session model. Matched exactly first, then as a case-insensitive substring. |
| `maxTokens` | `2048` | Output token cap for the refinement call. |
| `minChars` | `0` | Drafts shorter than this are skipped. Raise it to avoid spending a call on one-liners. |
| `maxChars` | `8000` | Drafts longer than this are refused; edit them by hand instead. |
| `resultMaxChars` | `4000` | Results longer than this are rejected as leaked reasoning. |
| `cacheMax` | `100` | LRU entries. `0` disables caching. |
| `cacheTtlMs` | `1800000` | Cache TTL in milliseconds (30 minutes). `0` never expires. |

Environment variables use the same names in `SCREAMING_SNAKE_CASE` with a
`PI_PROMPT_REFINER_` prefix, so `PI_PROMPT_REFINER_MODEL=deepseek-chat` overrides
the file. Invalid values are reported as a warning and skipped rather than
crashing the extension.

## Behaviour

**Gate.** Empty drafts, drafts below `minChars`, and drafts above `maxChars` are
rejected before any model call.

**Cache.** Results are keyed by system prompt version, model id, and the exact
draft, so switching models or editing the system prompt naturally invalidates
everything. A repeated draft returns the cached result without a model call.

**Context.** The model receives the project's `AGENTS.md` or `CLAUDE.md` (up to
2000 characters) plus the last six conversation turns (800 characters each,
tool results excluded), so it can resolve pronouns and references that the draft
alone does not explain.

**Cleaning.** Thinking blocks are never applied to the editor. An oversized
result is rejected as leaked reasoning, and lines that are pure meta-commentary
("Sure, here is the optimized prompt:") are dropped. A line that carries
substance survives even when it opens with a process word.

## Layout

```text
core.ts          pure logic: config, gate, cache, cleaning. No pi imports.
core.test.ts     tests for the above
loader.ts        the progress widget shown in TUI mode
loader.test.ts   tests for the widget
index.ts         the extension: command, model call, editor writes
index.test.ts    end-to-end tests driving a fake pi API
```

`node --test` from this directory runs all four suites. `index.ts` and
`loader.ts` import pi by package name, exactly as pi does at runtime, so the
tests need those packages resolvable here. Run `./test.sh`, which creates the
`node_modules/` symlinks (gitignored) and then runs the suites. `verify.sh`
calls the same script from its repository checks.
