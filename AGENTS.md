# Project Agent Rules

## Branch Hygiene
- Create a fresh branch for every meaningful feature, fix, refactor, or release-prep slice.
- Keep branches small. When a logical feature is finished, commit it before starting the next larger slice.
- Use Conventional Commits: `<type>(<scope>): <short description in lowercase>`.
- Do not let unrelated UI, release, docs, and architecture work accumulate on one long-running branch.

## Multi-Agent Safety
- Assume other Codex sessions, terminal windows, and agents may be working in the repo at the same time.
- Before editing, check `git status --short --branch` and inspect files you plan to touch.
- Never revert or overwrite changes you did not make.
- Keep edits scoped to the current task. If another session is working on website/API/release work, avoid those files unless Johannes explicitly asks.
- If a file has concurrent changes that affect the current task, pause and coordinate instead of forcing a rewrite.

## Product Direction
- SlamDih is sensor-only. Do not reintroduce microphone detection, microphone permissions, microphone fallback UI, or microphone fallback onboarding.
- Unsupported Mac means unsupported live detection.
