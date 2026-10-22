# Modelus — Agent Instructions

## Project Overview

Project Zomboid mod implemented for the game's Lua modding environment. All mod behavior belongs in Lua under `mods/modelus/common/media/lua/`. The project targets single player; multiplayer is not supported. The mod is not intended to be compatible with other mods.

**Lua-only implementation policy:** always choose Lua for mod behavior. Do not add Java code, Java bridges, JAR requirements, or Gradle-based implementation/build dependencies for the mod. Treat existing non-Lua mod logic and tooling as legacy migration work: when a task touches it, port the required behavior and checks to Lua-compatible solutions instead of extending the legacy path. The game's implementation language does not change this policy.

## Planning Mode — Implementation Specification

Produce an implementation-ready plan that another agent can execute without redesigning the solution, guessing implementation details, or making significant architectural decisions.

A plan must describe **exactly what to change, where to change it, how to change it, and how to verify the result**.

### Mandatory Codebase Investigation

Before writing a plan:

- Inspect the existing implementation, related interfaces, dependencies, configurations, and tests.
- Use CodeGraph or available code-navigation tools to identify symbols, callers, implementations, and dependencies.
- Identify existing patterns and reusable components before proposing new abstractions.
- Verify that every referenced file, symbol, and method actually exists, unless explicitly marked for creation.
- Identify potential compatibility issues and affected consumers.
- Prefer the smallest change that satisfies the requirements.

**Never plan modifications based solely on assumptions about the codebase.**

### Required Implementation Step Structure

Every implementation step MUST contain:

1. **ID:** Unique identifier, such as `PLAN-001`.
2. **Action:** Create, Modify, Delete, or Move.
3. **File:** Exact repository-relative path.
4. **Symbol:** Lua module, table, function, event callback, or configuration key. Include function signatures when relevant.
5. **Location:** Existing symbol reference and approximate line range when available. Symbols are authoritative; line numbers are navigation hints.
6. **Change:** Precise implementation instructions, including expected logic, signatures, types, dependencies, configuration, and behavior.
7. **Dependencies:** Other plan steps that must be completed first.
8. **Verification:** Observable, reproducible conditions that prove the step is complete.

Use code snippets when exact Lua syntax, function signatures, algorithms, or structural changes are important to eliminate ambiguity.

Do not include large implementations unless necessary.

### Implementation Precision

Each instruction MUST be independently actionable.

**Forbidden vague instructions:**

- "Improve the service."
- "Handle edge cases."
- "Add appropriate tests."
- "Update the related components."
- "Refactor where necessary."
- "Implement the required logic."

Instead, specify the exact implementation:

- Which Lua file and function or event callback must change.
- Which parameters, return values, or error conditions must be introduced.
- Which conditions, validations, or algorithms must be implemented.
- Which existing behavior must remain unchanged.
- Which callers or dependencies require modifications.
- Which Lua test file and test cases must be created or updated.

For tests, identify the test file, target method, input scenarios, and expected assertions.

Do not delegate unresolved design decisions to the Builder.

### Scope and Dependencies

- Enumerate all expected files and symbols affected by the implementation.
- Order steps according to their technical dependencies.
- Identify game API, configuration, and backward-compatibility implications.
- Explicitly identify behavior that must remain unchanged.
- Include migration or integration steps when required.
- Do not introduce unrelated refactoring or speculative improvements.
- Prefer existing frameworks and established project conventions over custom implementations.

If essential information is unavailable, investigate it before finalizing the plan.

If uncertainty cannot be resolved, explicitly document it as a blocker rather than inventing an implementation.

### Verification Requirements

Every step MUST include verifiable acceptance criteria.

Verification must specify, where applicable:

- Exact Lua tests or in-game checks to create, modify, or execute.
- Expected behavior and assertions.
- Relevant Lua syntax, test, or in-game validation commands.
- Compatibility requirements for existing consumers.
- Observable conditions that distinguish success from failure.

Avoid generic criteria such as "tests pass" without identifying which tests or behaviors matter.

### Required Plan Format

Use the following structure for each step:

**PLAN-001 — [Concrete implementation objective]**

- **Action:** Create
- **File:** `mods/modelus/common/media/lua/client/example/Feature.lua`
- **Symbol:** `Feature.refreshItems`
- **Location:** New file created for this example.
- **Change:**
  - Create `Feature.refreshItems(items, category)` to return only items matching the selected category.
  - Keep the helper in Lua and do not introduce compiled code or external build dependencies.
- **Dependencies:** None.
- **Verification:**
  - Matching items are returned and non-matching items are excluded.
  - An empty category returns all items.
  - The specified Lua tests pass.

Repeat this structure for every required implementation step.

### Planning Completion Gate

A plan is ready for execution only when:

- Every required change has an explicit implementation step.
- Files, symbols, and dependencies have been investigated.
- Implementation instructions are sufficiently precise.
- Verification criteria are concrete and observable.
- No essential architectural or behavioral decisions remain delegated to the Builder.
- The plan has a clearly defined scope and completion criteria.

**The final plan becomes the authoritative implementation contract after approval.**

## Building Mode — Strict Plan Execution

Implement the approved plan faithfully, without independently redesigning the solution, changing its scope, or selectively ignoring instructions.

**The approved implementation plan is the authoritative source of truth for the Builder.**

The Builder is an executor, not a second Planner.

### Plan Authority

The Builder MUST:

- Read the complete approved plan before modifying code.
- Identify all steps, dependencies, affected files, and acceptance criteria.
- Execute every step as specified.
- Preserve the planned method signatures, contracts, behavior, and architectural decisions.
- Implement changes in dependency order.
- Use the approved plan as the reference for all implementation decisions.

The Builder MUST NOT:

- Skip steps because they appear unnecessary.
- Replace planned solutions with preferred alternatives.
- Introduce unplanned architectural changes.
- Perform unrelated refactoring or cleanup.
- Add dependencies, abstractions, or functionality outside the approved scope.
- Treat acceptance criteria as optional.
- Silently modify the approved plan to match the implementation.

### Implementation Boundaries

Only changes explicitly authorized by the plan are permitted.

Minor implementation decisions are allowed when they:

- Are necessary to implement an approved step.
- Do not modify public contracts or expected behavior.
- Follow existing project conventions.
- Do not expand the scope.
- Do not contradict any plan instruction.

**Unspecified implementation details do not grant permission to redesign the solution.**

If additional files or significant changes are required but not covered by the plan, report the discrepancy and request a plan revision before proceeding.

### Step-by-Step Execution

For each implementation step:

1. Locate the exact target file and symbol.
2. Confirm that the actual code matches the plan's assumptions.
3. Apply only the specified changes.
4. Review the resulting diff for unintended modifications.
5. Execute the step's applicable verification checks.
6. Record the result against the original plan step ID.
7. Proceed only when the step is complete or its documented dependencies permit continued execution.

Do not mark a step complete merely because code was written.

**A step is complete only when its implementation and acceptance criteria have been verified.**

### Handling Discrepancies and Blockers

If the plan is incorrect, ambiguous, incomplete, or incompatible with the current codebase:

1. Stop execution of the affected step.
2. Identify the exact plan step, file, and symbol involved.
3. Explain the discrepancy using evidence from the codebase.
4. Describe the smallest necessary plan correction.
5. Request approval or an updated plan before implementing a material deviation.

Do not silently substitute another implementation.

Independent, unaffected steps may continue when their dependencies and contracts remain valid.

### Mandatory Plan Compliance Verification

Before reporting completion, compare the approved plan against the actual implementation.

For EVERY plan step, verify:

- The specified file was created or modified.
- The required symbol exists and has the expected signature.
- All specified behavior was implemented.
- Required tests and validations were executed.
- Backward-compatibility constraints were respected.
- No required change was omitted.
- No unauthorized change was introduced.

Review the final diff against the approved scope.

Do not rely exclusively on successful compilation or passing tests. These are necessary checks where applicable, but do not independently prove plan compliance.

### Required Implementation Report

Provide a concise implementation report using the original plan identifiers.

| Step | Status | Evidence |
| --- | --- | --- |
| PLAN-001 | COMPLETE | Implemented the specified method; targeted tests passed |
| PLAN-002 | COMPLETE | Updated the specified configuration; validation passed |
| PLAN-003 | BLOCKED | Planned symbol does not exist; requires plan revision |

Allowed statuses:

- **COMPLETE:** Implementation matches the plan and verification succeeded.
- **BLOCKED:** Execution requires clarification, an external dependency, or plan revision.
- **INCOMPLETE:** Implementation or verification remains unfinished.

For each step, provide the actual file and symbol references, the relevant verification results, and any deviations or blockers.

Never report tests as passed unless they were executed successfully.

If verification cannot be performed, explicitly state what was not verified and why.

### Final Completion Gate

The Builder MUST NOT declare the implementation complete unless:

- Every approved plan step is marked COMPLETE.
- Every acceptance criterion has been verified.
- Required tests and validation checks have succeeded.
- The final diff contains no unauthorized changes.
- No unresolved blockers remain.
- Existing behavior and compatibility requirements are preserved.

If any condition is not satisfied, report the implementation as partial or blocked.

**Final rule: Implement the approved plan, verify every requirement, and report evidence. Do not reinterpret, optimize, or redesign the plan during execution.**

## Execution Principles

### Parallelize

Delegate independent work to sub-agents in parallel. Don't read 4+ files inline — delegate exploration. Don't build/test inline — delegate execution. Run independent reads together, never sequentially when avoidable.

### Check Engram First

Before planning or executing any task, call `mem_search` for relevant prior context (bugs fixed, decisions made, conventions established). If you find something, surface it. If you don't find anything, say so briefly and proceed.

### Context

In adition of engram, you also have codegraph to find symbols and references in the codebase.

### Don't Assume — Ask

If a requirement, scope, or design decision is unclear, **ask**. One question at a time.  
If you must proceed under a specific assumption about the requirement or design decision, prefix the message with **"He asumido:"** and list what was assumed. Verify at the first opportunity.

## Mod Implementation Language

**Lua only. Always.**
Implement all mod behavior, validation that runs in-game, UI, and event integration in Lua under `mods/modelus/common/media/lua/`. Do not choose Java or another language as an alternative, even when it appears more convenient. If existing behavior or tooling is outside Lua, treat it as legacy to migrate; do not add to or depend on it for new mod behavior.

```
mods/modelus/common/media/lua/    ← mod behavior, UI, and game integration
```

## Mod Version

The single source of truth for the mod version is `mods/modelus/common/mod.info` (`modversion=X.Y.Z`). Keep the version displayed in:

- `mods/modelus/common/media/lua/client/ModelusMainScreen.lua` → `local versionText`

For a mod behavior fix, increment the patch version by 0.0.1; for a new feature, increment the minor version when appropriate. Keep `mod.info` and the Lua display string in sync directly. Documentation-only changes do not require a mod version bump.

Example: `0.6.9` → after a fix → `0.6.10`

## Deploy Script

`deploy.ps1` at the project root must deploy the Lua mod files directly:

1. Copy the contents of `mods/modelus/` to `$env:USERPROFILE\Zomboid\mods\modelus`.
2. Do not compile code, invoke Gradle, or require a JAR as part of deployment.

If the existing deployment script still requires compiled artifacts, migrate it to this Lua-only contract before using it. After deployment, report:

- Whether the Lua mod files were copied successfully
- The new `modversion` value
- A brief summary of what changed (so it's easy to verify in-game)

```powershell
.\deploy.ps1
```

## Lua Validation & Test

- Keep mod tests and validation runnable without Java, Gradle, or compiled artifacts.
- Run the repository's Lua syntax checks and Lua tests for the files changed.
- When behavior depends on Project Zomboid APIs or events, verify it in-game and report the exact scenario tested.
- Migrate any existing Java/Gradle-only test, validation, generation, or deployment step needed by a change to a Lua-compatible solution; do not treat the legacy step as a reason to add more Java or Gradle dependencies.

## Conventions

- Conventional commits only (no AI attribution, no "Co-Authored-By")
- No unnecessary refactors — change only what the task requires
- Don't add comments or docstrings to code you didn't change
