<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.0.1
- Change type: PATCH (removed redundant examples, kept only enforcement rules)
- Rationale: Deduplicate content with CLAUDE.md, reduce token usage
- Date: 2025-11-22
-->

# Liuli-Server Constitution

## Core Principles

### I. Clean MVVM Architecture (NON-NEGOTIABLE)

**Dependency Direction**: `App → Presentation → Domain ← Data`

**Layer Responsibilities**:
- **Domain**: Pure Swift, Sendable entities, repository protocols. Zero UI/framework deps.
- **Data**: Implements Domain protocols. `@Model` never exposed. Uses `actor` for repos.
- **Presentation**: SwiftUI views (no logic). ViewModels `@MainActor @Observable`, depend only on Domain.
- **App**: Entry point, DI container, navigation, config.

**Forbidden**: Reverse deps, layer violations, business logic in views.

### II. 100% Constructor Injection (NON-NEGOTIABLE)

All dependencies via `init()` parameters. Default values OK (e.g., `= .shared`) but injectable.

**Forbidden**: `.shared`, `.default`, `.global` in ViewModels/Use Cases. No `new` in ViewModels. No direct `ModelContext` in Presentation.

**Required**: Inject via `init()`, depend on protocols, use `AppDependencyContainer`.

### III. Swift 6.0 Strict Concurrency (NON-NEGOTIABLE)

Compile with `-strict-concurrency=complete`, ZERO warnings.

**Sendable**: Domain entities, cross-actor types, captured closures. No `@unchecked` without justification.

**Actor Isolation**: ViewModels `@MainActor`, repos `actor`, no sync calls across actors.

**Async/Await**: All async ops use async/await. No completion handlers, no DispatchQueue.

### IV. Test Coverage (MANDATORY)

- Domain Use Cases: ≥ 100% branch
- Data Repositories: ≥ 90% path
- Presentation ViewModels: ≥ 90% statement
- Views: ≥ 70%

XCTest only. Mock via protocols. Mirror source structure.

### V. Zero Compiler Warnings (NON-NEGOTIABLE)

Zero Swift warnings, SwiftLint errors, concurrency warnings, deprecations.

### VI. Specification-Driven Development (MANDATORY)

User stories with priorities (P1/P2/P3). Each independently testable. Given/When/Then scenarios. Tasks by story. All FR-XXX map to tasks.

**Workflow**: spec.md → plan.md → tasks.md → implement by story → validate scenarios.

### VII. Security & Privacy by Design (MANDATORY)

Credentials in Keychain. No traffic logging. Local network only (RFC 1918). Validate inputs. Encrypt persisted metadata.

## Performance Standards

- Launch: < 2s
- Connection: < 500ms
- Forwarding: < 50ms (< 5ms target)
- Memory: < 100MB idle, < 50MB with 10 conns
- UI: < 100ms response
- Concurrent: 100+ no degradation

Verify with Instruments. Violations block merge.

## Pre-Commit Checklist

- [ ] Correct dependency direction (no reverse)
- [ ] No SwiftData in Presentation
- [ ] Constructor injection (no singletons)
- [ ] Swift 6 concurrency passes (ZERO warnings)
- [ ] `Sendable` conformance
- [ ] Actor isolation correct
- [ ] No `@unchecked Sendable` (or justified)
- [ ] Async/await only (no DispatchQueue)
- [ ] ViewModels `@MainActor`, repos `actor`
- [ ] Tests pass, coverage met
- [ ] Zero compiler warnings

## Code Review Gates

- Pass tests (unit + integration)
- Meet coverage thresholds
- Pass concurrency checks
- Zero warnings
- Document deviations (requires approval)
- Include scenario validation

## Governance

**Authority**: Constitution supersedes all practices.

**Amendments**: Rationale + impact + template updates + semver bump.

**Versioning**:
- MAJOR: Incompatible principle changes
- MINOR: New principles
- PATCH: Clarifications

**Compliance**: All PRs verify via checklist.

**Version**: 1.0.1 | **Ratified**: 2025-11-22 | **Last Amended**: 2025-11-22
