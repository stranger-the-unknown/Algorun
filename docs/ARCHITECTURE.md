# Algorun architecture (locked)

Working title: **Algorun**. Android-first Flutter/Dart puzzle game. The player constructs algorithms with typed blocks. No syntax. No eval of generated source.

This document supersedes the previous “web port / TypeScript twin” note. **There is no second implementation.**

## Locked decisions

1. **Flutter + Dart only.** All game and engine source is Dart. Android is the primary product target. iOS remains a future compile target. There is no TypeScript, React, or JavaScript product codebase.
2. **Engine is pure Dart.** `packages/algorun_engine` must not import `package:flutter`. The Flutter app depends on the engine; the engine never depends on the app.
3. **First five puzzles are engine/content probes, not the difficulty ceiling.** Campaign difficulty is LeetCode Medium/Hard and multi-concept from Milestone 8 onward. Milestone 1 ships a single data fixture (`ms1_contract_probe`) so loaders and contracts are testable.
4. **Per-puzzle allowlist is mandatory.** The editor palette is exactly `blocks.allow`. A full-catalog palette is a bug.
5. **No Big-O analyzer in v1.** Grade with deterministic `maxOps` / `maxAlloc` / `maxDepth`. Empirical complexity fitting is a later add-on and must never be presented as a proof.
6. **Local hidden tests are UI-hidden, not secret.** An APK can be unpacked. `VerdictSource.remote` is reserved so a later competitive mode can move hidden tests server-side without rewriting the engine API.
7. **Content generation is not the game engine.** `packages/algorun_content` validates JSON + reference constraints offline. The Flutter app must not import it. Generated puzzles enter the game only after this validator (and, later, a reference-solution run) passes.
8. **No framework change.** Stay on Flutter/Dart.

## Pipeline

```
Puzzle JSON
  → BlockGraph
    → validate          (allowlist, holes, init)
      → AST / IR
        → Interpreter   (sandboxed, deterministic)
          → TestRunner
            → Result + metrics (ops, alloc, depth, blocks, hints)
```

No Dart/JS/Kotlin `eval`. No codegen.

## Layers

| Layer | Location | Flutter? |
|---|---|---|
| Engine (IR, runtime types, puzzle model, contracts) | `packages/algorun_engine` | No |
| Content pipeline (offline) | `packages/algorun_content` | No |
| App UI, editor, asset loading | `lib/` | Yes |
| Puzzle JSON | `assets/puzzles/` | Data |

## State

- **Engine:** pure functions + `AlgorunEngine`.
- **Session / progression / results:** Riverpod.
- **Editor canvas (later):** a dedicated controller. Do not push pointer-move through Riverpod.

## Block language (summary)

Scratch-style statement stacks + typed expression holes. Not freeform node graphs.

Types: `void`, `num`, `bool`, `str`, `null`, `array<T>`, `map<K,V>`, `set<T>`, `stack<T>`, `queue<T>`, `deque<T>`, `heap<T>`, `listNode`, `treeNode`, `graph`, `pair<T,U>`, all optionally `?`. No implicit `num`→`bool`.

Semantic failures only (“This block needs a condition.”), never compiler syntax errors.

## Performance

Puzzles declare `limits.maxOps` (required), `maxDepth`, `maxAlloc`. A correct slow program fails as `Operation Limit` / `Memory Limit`. Do not show a fake “O(n) proved” badge in v1.

## Hidden tests

- Not rendered in the puzzle or results UI.
- Stored in local JSON for MVP (`VerdictSource.local`).
- Architecture leaves `VerdictSource.remote` so online validation can replace local hidden fixtures later.

## Content pipeline

Grok (or any generator) writes JSON. `dart run algorun_content:validate` must pass before a file is committed under `assets/puzzles`. Later: run a reference `BlockGraph` through the interpreter. Reject redundant Two-Sum clones, unsolvable allowlists, and missing edge cases.

## Milestones

1. Skeleton + contracts (this)
2. Typed block model
3. Editor UI
4. Lowering to IR
5. Interpreter / VM
6. Test runner
7. Puzzle schema hardening
8. First five real algorithm puzzles (still not the ceiling)
9. Hints
10. Performance metrics (still budget-based)
11. Progression + local save
12. Large original content
13. Mobile UX polish

Primary: Android (`com.algorun`). Flutter web is used only when a host cannot run an APK (this preview). It is the same Dart app, not a separate product.
