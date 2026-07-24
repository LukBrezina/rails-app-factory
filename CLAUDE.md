# CLAUDE.md

Read the README first — its "Architecture" section is the handoff document:
big picture, naming conventions, session lifecycle, deploy/backup internals,
and a Gotchas list of non-obvious constraints (bundler-env stripping into
tmux, Turbo Drive deliberately off, claude's process title, xterm FitAddon
padding, tailwind-watcher TTY). Don't undo those without reading why.

## Commands

- `bin/rails test` — the suite (fast; includes subprocess tests of bin/hook)
- `bin/rails tailwindcss:build` — required after CSS/token changes if no watcher runs
- `APPSMOOTHLY_PROJECTS_DIR=<dir> bin/dev` — run locally (foreman needs a TTY; headless: `tailwindcss:build` + `bin/rails server`)

## Hard rules

- Sessions are DB rows (identity/lifecycle) + tmux (runtime: liveness, PORT,
  attached, live title). Never infer existence from tmux alone — a row
  without tmux is *asleep*, not gone; opening it resumes via
  `claude --continue`. Rows/worktrees are removed only on explicit kill.
- This box hosts exactly ONE app, named by `APPSMOOTHLY_APP` and adopted by
  `App.current` (created on first use; carries deployed_at + prod/backup
  config). There is no app switcher / add-app / app-scoped routes — provisioning
  (appsmoothly-infra) clones the app into `<projects>/<name>`; the factory just
  runs it. `bin/create-app` is the infra's tool, not driven from the UI.
- Names: `<app>--<session>`; the `/\A\w+(?:-\w+)*\z/` validation makes `--`
  unambiguous. The app name comes from `APPSMOOTHLY_APP`; session slugs come from the
  typed task (`Session.slug_for`), display names from Claude's own terminal
  title.
- `bin/hook` executes under each app's own Ruby — keep its syntax
  old-Ruby-compatible.
- All UI copy targets someone who never coded: deploy→"go live",
  restore→"rewind", worktree→"private workspace", attached→"open in a browser".
- Long-running work (deploy, restore) runs in visible tmux sessions named
  `<app>--deploy/restore` — keep that pattern for new features. (App creation
  is no longer factory-driven; it happens at provisioning time.)
