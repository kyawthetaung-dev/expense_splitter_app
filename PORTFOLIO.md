# Expense Splitter

*A cross-platform, offline-first Flutter app for splitting and settling shared group expenses.*

## Overview

Expense Splitter is a Splitwise-style app for tracking shared expenses within a group — trips, shared households, or any situation where a group of people needs to split costs and figure out who owes whom. It runs fully offline with local storage, so there's no backend, account, or internet connection required.

Users create a group, add participants, and log expenses with flexible splitting rules — equal shares, custom fixed amounts, or percentages — including support for expenses paid jointly by multiple people. The app continuously calculates each participant's balance and, when it's time to settle up, suggests the minimal set of payments needed to zero everyone out.

Built solo end-to-end: data model, split/settlement algorithms, app architecture, UI, and automated test suite.

## Key Features

- **Group & participant management** — create groups, add/rename/remove participants, with a safety guard that blocks deleting a participant who has expense history unless explicitly overridden.
- **Three expense split types** — equal, custom fixed amounts, and percentage-based, each with live "remaining to allocate" feedback while entering an expense.
- **Multi-payer expenses** — any subset of participants can jointly cover a single expense, each contributing a different amount.
- **Live balance tracking** — per-participant "owes / is owed / settled" status, computed across the group's full expense history and updated instantly on any change.
- **Automatic settlement suggestions** — a dedicated screen computes the minimal set of "who pays whom" transactions to settle the group, using a greedy debt-simplification algorithm (the standard approach used by Splitwise-style apps).
- **Exact money math** — all amounts are stored as integers in minor currency units, avoiding floating-point rounding errors entirely.
- **Fully offline** — all data lives on-device via local storage; no network dependency, account, or sign-in.
- **Custom branding** — a designed app icon generated and wired into every target platform.

## Technical Highlights

- **Layered architecture** — pure, framework-free calculation services (split math, balance math, settlement math) are fully decoupled from persistence and UI, making the app's core business logic independently unit-testable.
- **Reactive state with a single invalidation signal** — built with Riverpod, using one shared "data revision" counter that every write bumps and every derived view depends on. This keeps balances, summaries, and settlement suggestions always in sync without hand-written cache-invalidation logic scattered across the app.
- **Hand-written local persistence layer** — a local NoSQL data layer (Hive) with explicit, hand-written serialization adapters for every entity, designed for safe schema evolution over time.
- **Deterministic financial calculations** — percentage splits use the largest-remainder method and equal splits use canonicalized participant ordering, so recalculating an unchanged expense always reproduces identical results.
- **Genuinely cross-platform** — one codebase builds and runs on Android, iOS, Web (installable as a PWA), Windows, and macOS, including a real dependency pin made deliberately to avoid requiring a native Android build toolchain.
- **Automated test suite** — an 11-file suite covering split/balance/settlement calculation logic, local-storage repository behavior (including cascading deletes and safe-delete guards), and an end-to-end scenario test chained across the full calculation pipeline. A shared, hand-verified test fixture is reused across multiple test files to cross-check results independently rather than testing each layer in isolation only.

## Tech Stack

Flutter · Dart · Riverpod (state management) · Hive (local persistence) · Material 3

## My Role

Solo developer — designed the data model and core algorithms (expense splitting, balance calculation, settlement optimization), and implemented the full application: persistence layer, state management, UI, and test suite.

---

*[Add screenshots and a link to the source repository here.]*
