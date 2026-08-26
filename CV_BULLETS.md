# CV / Resume Bullet Points — Expense Splitter

Use under a "Personal Projects" section. Pick 2–4 depending on space.

**Expense Splitter** — Personal project · Flutter, Dart, Riverpod, Hive
*(add a repository link once pushed to GitHub/GitLab)*

- Built a cross-platform expense-splitting app (Android, iOS, Web, Windows, macOS) from a single Flutter codebase, supporting equal, custom, and percentage-based expense splits with multi-payer support.
- Designed and implemented a settlement engine using a greedy debt-simplification algorithm to compute the minimum set of payments needed to settle a group's balances.
- Architected a layered application structure separating pure, unit-tested business logic (split, balance, and settlement calculations) from a local persistence layer and a reactive Riverpod-based UI, using a single shared invalidation signal to keep all derived views automatically in sync.
- Ensured exact financial calculations by representing all money as integers in minor units and using deterministic remainder-distribution logic, eliminating floating-point rounding errors.
- Authored an 11-file automated test suite covering calculation logic, local-storage integrity (including cascading deletes and safe-delete guards), and a full end-to-end scenario validated against hand-computed results.

## One-line version (for a compact CV)

Built and shipped a cross-platform Flutter expense-splitting app with custom split/settlement algorithms, offline-first local persistence, and a fully unit-tested calculation core.
