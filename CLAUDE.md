# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Liuli-Server is a macOS application that works in conjunction with Liuli-iOS (an iOS VPN app). Its primary function is to receive traffic from Liuli-iOS and forward it to Charles proxy tool for mobile traffic capture and analysis.

**Platform**: macOS 14.0+
**Language**: Swift 6.0+
**UI Framework**: SwiftUI
**Data Layer**: SwiftData
**Architecture**: Clean MVVM
**Concurrency**: Swift 6 strict concurrency enabled (`-strict-concurrency=complete`)

## Architecture Authority

**PRIMARY SOURCE**: This project follows architecture rules defined in `.specify/memory/constitution.md`

When conflicts arise, constitution.md takes precedence. Key principles:
- Clean MVVM with strict layer separation (App → Presentation → Domain ← Data)
- 100% constructor injection (no singletons in ViewModels/Use Cases)
- Swift 6.0 strict concurrency (zero data races)
- Test coverage targets (Domain 100%, Data 90%, Presentation 90%, Views 70%)
- Zero compiler warnings

Refer to constitution.md for complete rules and enforcement details.

## Development Environment

### Build & Run
```bash
# Open in Xcode
open Liuli-Server.xcodeproj

# Build from command line
xcodebuild -project Liuli-Server.xcodeproj -scheme Liuli-Server -configuration Debug build

# Run tests
xcodebuild test -project Liuli-Server.xcodeproj -scheme Liuli-Server -destination 'platform=macOS'
```

### Project Structure
```
Liuli-Server/
├── App/                    # Application entry point and dependency injection
├── Domain/                 # Business entities, use cases, repository protocols
├── Data/                   # Repository implementations, data sources, SwiftData models
├── Presentation/           # SwiftUI views and ViewModels
├── Resources/              # Assets and localizations
└── Shared/                 # Shared UI components and utilities
```

## Networking Architecture

### Traffic Forwarding Flow
```
Liuli-iOS (VPN Client)
    ↓ [Network Traffic]
Liuli-Server (macOS)
    ↓ [Proxy Protocol]
Charles Proxy Tool
```

### Key Responsibilities
1. **Traffic Reception**: Accept incoming connections from Liuli-iOS
2. **Protocol Handling**: Parse and process VPN protocol packets
3. **Proxy Forwarding**: Forward traffic to Charles proxy (typically localhost:8888)
4. **Connection Management**: Track active connections and their states
5. **Error Handling**: Handle network failures, disconnections, and protocol errors

### Network Layer Structure (To Be Implemented)
```swift
// Domain/Protocols/
protocol TrafficForwarder: Sendable {
    func startForwarding(config: ProxyConfiguration) async throws
    func stopForwarding() async throws
}

protocol ConnectionMonitor: Sendable {
    func observeConnections() -> AsyncStream<ConnectionState>
}

// Data/Services/
actor ProxyForwardingService: TrafficForwarder { /* ... */ }
actor ConnectionTrackerService: ConnectionMonitor { /* ... */ }
```

## Common Patterns

### Network Request Pattern
```swift
// Data Layer
actor NetworkRepository: MyDataRepository {
    private let session: URLSession

    func fetchData() async throws -> DomainModel {
        let (data, response) = try await session.data(from: url)
        return try mapToDomain(data)
    }
}

// Use Case
public struct FetchDataUseCase: Sendable {
    private let repository: MyDataRepository

    public func execute() async throws -> DomainModel {
        try await repository.fetchData()
    }
}

// ViewModel
@MainActor
final class MyViewModel: ObservableObject {
    private let fetchDataUseCase: FetchDataUseCase

    func loadData() async {
        do {
            let data = try await fetchDataUseCase.execute()
            // Update state
        } catch {
            // Handle error
        }
    }
}
```

### SwiftData Pattern
```swift
// Data Layer: @Model (internal to Data layer)
@Model
final class RecordModel {
    var id: UUID
    var timestamp: Date
}

// Domain Layer: Pure Swift entity
public struct Record: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
}

// Repository: Mapping layer
actor RecordRepository: RecordRepositoryProtocol {
    func fetchAll() async throws -> [Record] {
        let models = try context.fetch(FetchDescriptor<RecordModel>())
        return models.map { Record(model: $0) }
    }
}
```

### State Management Pattern
```swift
// State (value type)
struct MyViewState: Sendable, Equatable {
    var data: [Item] = []
    var isLoading = false
    var errorMessage: String?
}

// Actions
enum MyViewAction: Sendable {
    case onAppear
    case refresh
    case select(UUID)
}

// ViewModel
@MainActor
@Observable
final class MyViewModel {
    private let useCase: MyUseCase
    private(set) var state = MyViewState()

    func send(_ action: MyViewAction) {
        // Handle action, update state
    }
}
```

## Communication Language

- Use **Chinese** for all user-facing documentation, comments, and communication
- Use **English** for code identifiers, technical specifications, and architectural documents
- This CLAUDE.md file uses English as it serves as technical documentation

## Security Considerations

- All network communication must use secure protocols where applicable
- Proxy credentials (if any) must be stored in Keychain
- User privacy: no traffic content should be logged or persisted
- Connection metadata (timestamps, byte counts) stored via SwiftData must be encrypted

## Performance Requirements

- Application launch time: < 2 seconds
- Connection establishment: < 500ms
- Traffic forwarding latency: < 50ms overhead
- Memory usage: < 100MB baseline

## Quick Reference: Pre-Commit Checklist

Before committing code, verify:
- [ ] All layer dependencies follow correct direction (no reverse dependencies)
- [ ] No direct SwiftData access from Presentation layer
- [ ] All ViewModels use constructor injection (no singletons or `new` instances)
- [ ] Swift 6.0 strict concurrency passes (ZERO data race warnings)
- [ ] All concurrent types conform to `Sendable`
- [ ] All actor isolation boundaries are correct
- [ ] No `@unchecked Sendable` without justification
- [ ] No DispatchQueue or completion handlers (use async/await)
- [ ] All ViewModels marked with `@MainActor`
- [ ] All repositories implemented as `actor`
- [ ] Tests pass and coverage meets targets
- [ ] No compiler warnings
- [ ] Architecture guidelines followed

**Full checklist and rationale**: See `.specify/memory/constitution.md`

## Active Technologies
- Swift 6.0+ (strict concurrency enabled) + SwiftUI, SwiftData (for persistence), Foundation (URLSession for Charles detection), AppKit (NSStatusBar for menu bar) (002-main-ui-dashboard)
- SwiftData for settings persistence, UserDefaults for bridge state, connection tracking in-memory (002-main-ui-dashboard)

## Recent Changes
- 002-main-ui-dashboard: Added Swift 6.0+ (strict concurrency enabled) + SwiftUI, SwiftData (for persistence), Foundation (URLSession for Charles detection), AppKit (NSStatusBar for menu bar)
