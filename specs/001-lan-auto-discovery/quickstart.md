# Quick Start: LAN Auto-Discovery

**Feature**: 001-lan-auto-discovery
**Last Updated**: 2025-11-23

This guide walks you through setting up your development environment and implementing the LAN auto-discovery feature across macOS server, iOS client, and Android client.

---

## Prerequisites

### macOS Server Development

**Requirements**:
- macOS 14.0+ (Sonoma or later)
- Xcode 16.0+ (Swift 6.0+)
- Git

**Verify Setup**:
```bash
# Check Swift version
swift --version  # Should be 6.0+

# Check Xcode
xcodebuild -version  # Should be 16.0+

# Clone repository
git clone <repository-url>
cd Liuli-Server
git checkout 001-lan-auto-discovery
```

### iOS Client Development

**Requirements**:
- macOS 14.0+
- Xcode 16.0+
- iOS 17.0+ device or simulator
- Apple Developer account (for VPN entitlements)

**Verify Setup**:
```bash
cd Liuli-iOS
open Liuli-iOS.xcodeproj
```

### Android Client Development

**Requirements**:
- Android Studio Hedgehog (2023.1.1) or later
- JDK 17+
- Android SDK 34+
- Kotlin 1.9+

**Verify Setup**:
```bash
# Check Java version
java -version  # Should be 17+

# Check Gradle
./gradlew --version

cd Liuli-Android
./gradlew build
```

---

## Phase 1: macOS Server - Bonjour Broadcasting

### Step 1: Create Domain Entities

**File**: `Domain/Entities/ServiceBroadcast.swift`

```swift
import Foundation

public struct ServiceBroadcast: Sendable, Equatable {
    public let serviceType: String = "_liuli-proxy._tcp."
    public let domain: String = "local."
    public let deviceName: String
    public let deviceID: UUID
    public let port: Int
    public let bridgeStatus: BridgeStatus
    public let protocolVersion: String = "1.0.0"
    public let certificateHash: String

    public enum BridgeStatus: String, Sendable, Codable {
        case active
        case inactive
    }

    public var txtRecord: [String: String] {
        [
            "port": "\(port)",
            "version": protocolVersion,
            "device_id": deviceID.uuidString,
            "bridge_status": bridgeStatus.rawValue,
            "cert_hash": certificateHash
        ]
    }
}
```

### Step 2: Create Repository Protocol

**File**: `Domain/Repositories/BonjourBroadcastRepositoryProtocol.swift`

```swift
import Foundation

public protocol BonjourBroadcastRepositoryProtocol: Sendable {
    func startBroadcasting(config: ServiceBroadcast) async throws
    func stopBroadcasting() async throws
    func updateBridgeStatus(_ status: ServiceBroadcast.BridgeStatus) async throws
}

public enum BonjourError: Error {
    case publishFailed(reason: String)
    case notBroadcasting
}
```

### Step 3: Implement Repository

**File**: `Data/Repositories/BonjourBroadcastRepositoryImpl.swift`

```swift
@preconcurrency import Foundation

actor BonjourBroadcastRepositoryImpl: BonjourBroadcastRepositoryProtocol {
    private var netService: NetService?
    private nonisolated let delegate: NetServiceDelegateAdapter
    private var currentConfig: ServiceBroadcast?

    init() {
        self.delegate = NetServiceDelegateAdapter()
    }

    func startBroadcasting(config: ServiceBroadcast) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let service = NetService(
                domain: config.domain,
                type: config.serviceType,
                name: config.deviceName,
                port: Int32(config.port)
            )

            let txtData = NetService.data(fromTXTRecord: config.txtRecord.mapValues { $0.data(using: .utf8)! })
            service.setTXTRecord(txtData)

            delegate.onPublish = { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: BonjourError.publishFailed(reason: error ?? "Unknown"))
                }
            }

            service.delegate = delegate
            service.publish()

            self.netService = service
            self.currentConfig = config
        }
    }

    func stopBroadcasting() async throws {
        guard let service = netService else {
            throw BonjourError.notBroadcasting
        }

        service.stop()
        self.netService = nil
        self.currentConfig = nil
    }

    func updateBridgeStatus(_ status: ServiceBroadcast.BridgeStatus) async throws {
        guard var config = currentConfig else {
            throw BonjourError.notBroadcasting
        }

        // Stop current broadcast
        try await stopBroadcasting()

        // Restart with updated status
        config = ServiceBroadcast(
            deviceName: config.deviceName,
            deviceID: config.deviceID,
            port: config.port,
            bridgeStatus: status,
            certificateHash: config.certificateHash
        )

        try await startBroadcasting(config: config)
    }
}

final class NetServiceDelegateAdapter: NSObject, NetServiceDelegate, @unchecked Sendable {
    var onPublish: ((Bool, String?) -> Void)?

    nonisolated func netServiceDidPublish(_ sender: NetService) {
        Task { await onPublish?(true, nil) }
    }

    nonisolated func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let errorMessage = errorDict.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        Task { await onPublish?(false, errorMessage) }
    }
}
```

### Step 4: Test Broadcasting

**File**: `Tests/DataTests/BonjourBroadcastRepositoryTests.swift`

```swift
import XCTest
@testable import Liuli_Server

final class BonjourBroadcastRepositoryTests: XCTestCase {
    func testBroadcastStartStop() async throws {
        let repository = BonjourBroadcastRepositoryImpl()

        let config = ServiceBroadcast(
            deviceName: "Test Server",
            deviceID: UUID(),
            port: 9050,
            bridgeStatus: .active,
            certificateHash: String(repeating: "A", count: 64)
        )

        try await repository.startBroadcasting(config: config)

        // Wait for broadcast to propagate
        try await Task.sleep(for: .seconds(2))

        try await repository.stopBroadcasting()
    }
}
```

**Run Tests**:
```bash
xcodebuild test -project Liuli-Server.xcodeproj -scheme Liuli-Server -destination 'platform=macOS'
```

**Manual Verification**:
```bash
# In terminal, run dns-sd to verify broadcast
dns-sd -B _liuli-proxy._tcp local.

# You should see your server appear in the output
# Example: Test Server._liuli-proxy._tcp.local.
```

---

## Phase 2: iOS Client - Service Discovery

### Step 1: Add Privacy Declaration

**File**: `Liuli-iOS/Info.plist`

Add the following key-value pair:
```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Liuli needs to discover proxy servers on your local network to provide VPN services.</string>
```

### Step 2: Create Discovery Repository

**File**: `Data/Repositories/BonjourDiscoveryRepositoryImpl.swift`

```swift
import Foundation
import Network

actor BonjourDiscoveryRepositoryImpl: ServerDiscoveryRepositoryProtocol {
    private var browser: NWBrowser?

    func startDiscovery() -> AsyncStream<DiscoveredServer> {
        AsyncStream { continuation in
            let browser = NWBrowser(
                for: .bonjourWithTXTRecord(type: "_liuli-proxy._tcp", domain: "local."),
                using: .tcp
            )

            browser.stateUpdateHandler = { state in
                switch state {
                case .failed(let error):
                    print("Browser failed: \(error)")
                    continuation.finish()
                case .ready:
                    print("Browser ready")
                default:
                    break
                }
            }

            browser.browseResultsChangedHandler = { results, changes in
                for result in results {
                    if case .service(let name, _, _, _) = result.endpoint,
                       let txtRecord = result.txtRecord {

                        let server = self.parseServer(name: name, txtRecord: txtRecord, result: result)
                        if let server = server {
                            continuation.yield(server)
                        }
                    }
                }
            }

            browser.start(queue: .main)
            self.browser = browser

            continuation.onTermination = { @Sendable _ in
                browser.cancel()
            }
        }
    }

    private func parseServer(name: String, txtRecord: NWTXTRecord, result: NWBrowser.Result) -> DiscoveredServer? {
        guard let portString = txtRecord["port"].flatMap({ String(data: $0, encoding: .utf8) }),
              let port = Int(portString),
              let deviceIDString = txtRecord["device_id"].flatMap({ String(data: $0, encoding: .utf8) }),
              let deviceID = UUID(uuidString: deviceIDString),
              let bridgeStatusString = txtRecord["bridge_status"].flatMap({ String(data: $0, encoding: .utf8) }),
              let bridgeStatus = DiscoveredServer.BridgeStatus(rawValue: bridgeStatusString),
              let version = txtRecord["version"].flatMap({ String(data: $0, encoding: .utf8) }),
              let certHash = txtRecord["cert_hash"].flatMap({ String(data: $0, encoding: .utf8) })
        else {
            return nil
        }

        // Extract address from result
        let address = self.extractAddress(from: result)

        return DiscoveredServer(
            id: deviceID,
            name: name,
            address: address,
            port: port,
            bridgeStatus: bridgeStatus,
            protocolVersion: version,
            certificateHash: certHash
        )
    }

    private func extractAddress(from result: NWBrowser.Result) -> String {
        // Simplified - in production, resolve the service endpoint
        return "192.168.1.100"  // Placeholder
    }

    func stopDiscovery() async {
        browser?.cancel()
        browser = nil
    }
}
```

### Step 3: Create ViewModel

**File**: `Presentation/ServerDiscovery/ServerDiscoveryViewModel.swift`

```swift
import Foundation

@MainActor
@Observable
final class ServerDiscoveryViewModel {
    private let repository: ServerDiscoveryRepositoryProtocol

    private(set) var discoveredServers: [DiscoveredServer] = []
    private(set) var isScanning = false

    init(repository: ServerDiscoveryRepositoryProtocol) {
        self.repository = repository
    }

    func startScanning() {
        isScanning = true
        discoveredServers.removeAll()

        Task {
            for await server in repository.startDiscovery() {
                updateServer(server)
            }
        }
    }

    func stopScanning() async {
        await repository.stopDiscovery()
        isScanning = false
    }

    private func updateServer(_ server: DiscoveredServer) {
        if let index = discoveredServers.firstIndex(where: { $0.id == server.id }) {
            discoveredServers[index] = server
        } else {
            discoveredServers.append(server)
        }
    }
}
```

### Step 4: Create UI

**File**: `Presentation/ServerDiscovery/ServerListView.swift`

```swift
import SwiftUI

struct ServerListView: View {
    @State private var viewModel: ServerDiscoveryViewModel

    init(viewModel: ServerDiscoveryViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        List(viewModel.discoveredServers) { server in
            ServerRow(server: server)
        }
        .navigationTitle("Available Servers")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleScanning) {
                    Image(systemName: viewModel.isScanning ? "stop.circle" : "arrow.clockwise")
                }
            }
        }
        .onAppear {
            viewModel.startScanning()
        }
        .onDisappear {
            Task {
                await viewModel.stopScanning()
            }
        }
    }

    private func toggleScanning() {
        if viewModel.isScanning {
            Task { await viewModel.stopScanning() }
        } else {
            viewModel.startScanning()
        }
    }
}

struct ServerRow: View {
    let server: DiscoveredServer

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(server.name)
                    .font(.headline)
                Text("\(server.address):\(server.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            StatusBadge(status: server.bridgeStatus)
        }
    }
}

struct StatusBadge: View {
    let status: DiscoveredServer.BridgeStatus

    var body: some View {
        Text(status == .active ? "Active" : "Inactive")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status == .active ? Color.green : Color.gray)
            .foregroundStyle(.white)
            .cornerRadius(8)
    }
}
```

### Step 5: Test on Device

**Run on Device**:
1. Connect iOS device via USB
2. Select device as build target
3. Build and run (⌘R)
4. Grant local network permission when prompted
5. Verify server appears in list within 5 seconds

---

## Phase 3: Android Client - NSD Discovery

### Step 1: Add Dependencies

**File**: `app/build.gradle.kts`

```kotlin
dependencies {
    implementation("org.jmdns:jmdns:3.5.9")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Existing dependencies...
}
```

### Step 2: Add Permissions

**File**: `app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>

    <application ...>
        <!-- Your activities -->
    </application>
</manifest>
```

### Step 3: Implement Discovery Repository

**File**: `app/src/main/java/com/liuli/android/data/NsdDiscoveryRepositoryImpl.kt`

```kotlin
package com.liuli.android.data

import android.content.Context
import android.net.wifi.WifiManager
import com.liuli.android.domain.DiscoveredServer
import com.liuli.android.domain.ServerDiscoveryRepository
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import javax.jmdns.JmDNS
import javax.jmdns.ServiceEvent
import javax.jmdns.ServiceListener
import java.net.InetAddress
import java.util.UUID

class NsdDiscoveryRepositoryImpl(
    private val context: Context
) : ServerDiscoveryRepository {

    private var jmdns: JmDNS? = null
    private val lock: WifiManager.MulticastLock by lazy {
        (context.getSystemService(Context.WIFI_SERVICE) as WifiManager)
            .createMulticastLock("LiuliDiscovery")
    }

    override fun startDiscovery(): Flow<DiscoveredServer> = callbackFlow {
        lock.acquire()

        val localAddress = getLocalIPAddress()
        jmdns = JmDNS.create(localAddress, "Liuli-Android").apply {
            addServiceListener("_liuli-proxy._tcp.local.", object : ServiceListener {
                override fun serviceAdded(event: ServiceEvent) {
                    requestServiceInfo(event.type, event.name)
                }

                override fun serviceResolved(event: ServiceEvent) {
                    val info = event.info

                    val server = DiscoveredServer(
                        id = UUID.fromString(info.getPropertyString("device_id")),
                        name = info.name,
                        address = info.inet4Addresses.firstOrNull()?.hostAddress ?: return,
                        port = info.getPropertyString("port")?.toInt() ?: return,
                        bridgeStatus = when(info.getPropertyString("bridge_status")) {
                            "active" -> DiscoveredServer.BridgeStatus.ACTIVE
                            else -> DiscoveredServer.BridgeStatus.INACTIVE
                        },
                        protocolVersion = info.getPropertyString("version") ?: "1.0.0",
                        certificateHash = info.getPropertyString("cert_hash") ?: return,
                        lastSeenAt = System.currentTimeMillis()
                    )

                    trySend(server)
                }

                override fun serviceRemoved(event: ServiceEvent) {
                    // Handle server removal if needed
                }
            })
        }

        awaitClose {
            jmdns?.close()
            if (lock.isHeld) {
                lock.release()
            }
        }
    }

    private fun getLocalIPAddress(): InetAddress {
        // Simplified - should get actual WiFi IP
        return InetAddress.getLocalHost()
    }
}
```

### Step 4: Create ViewModel

**File**: `app/src/main/java/com/liuli/android/presentation/ServerDiscoveryViewModel.kt`

```kotlin
package com.liuli.android.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.liuli.android.domain.DiscoveredServer
import com.liuli.android.domain.ServerDiscoveryRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ServerDiscoveryViewModel(
    private val repository: ServerDiscoveryRepository
) : ViewModel() {

    private val _discoveredServers = MutableStateFlow<List<DiscoveredServer>>(emptyList())
    val discoveredServers: StateFlow<List<DiscoveredServer>> = _discoveredServers.asStateFlow()

    private val _isScanning = MutableStateFlow(false)
    val isScanning: StateFlow<Boolean> = _isScanning.asStateFlow()

    fun startScanning() {
        _isScanning.value = true
        _discoveredServers.value = emptyList()

        viewModelScope.launch {
            repository.startDiscovery().collect { server ->
                val current = _discoveredServers.value.toMutableList()
                val index = current.indexOfFirst { it.id == server.id }

                if (index >= 0) {
                    current[index] = server
                } else {
                    current.add(server)
                }

                _discoveredServers.value = current
            }
        }
    }

    fun stopScanning() {
        _isScanning.value = false
    }
}
```

### Step 5: Create UI

**File**: `app/src/main/java/com/liuli/android/presentation/ServerListScreen.kt`

```kotlin
package com.liuli.android.presentation

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.liuli.android.domain.DiscoveredServer

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ServerListScreen(
    viewModel: ServerDiscoveryViewModel,
    modifier: Modifier = Modifier
) {
    val servers by viewModel.discoveredServers.collectAsState()
    val isScanning by viewModel.isScanning.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Available Servers") },
                actions = {
                    IconButton(onClick = { viewModel.startScanning() }) {
                        Icon(Icons.Default.Refresh, contentDescription = "Refresh")
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(
            modifier = modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            items(servers) { server ->
                ServerListItem(server = server)
            }
        }
    }
}

@Composable
fun ServerListItem(server: DiscoveredServer) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp)
        ) {
            Text(
                text = server.name,
                style = MaterialTheme.typography.titleMedium
            )

            Text(
                text = "${server.address}:${server.port}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(8.dp))

            StatusChip(
                status = server.bridgeStatus,
                modifier = Modifier
            )
        }
    }
}

@Composable
fun StatusChip(
    status: DiscoveredServer.BridgeStatus,
    modifier: Modifier = Modifier
) {
    Surface(
        color = if (status == DiscoveredServer.BridgeStatus.ACTIVE) {
            MaterialTheme.colorScheme.primary
        } else {
            MaterialTheme.colorScheme.surfaceVariant
        },
        shape = MaterialTheme.shapes.small,
        modifier = modifier
    ) {
        Text(
            text = if (status == DiscoveredServer.BridgeStatus.ACTIVE) "Active" else "Inactive",
            style = MaterialTheme.typography.labelSmall,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
        )
    }
}
```

### Step 6: Test on Device

**Run on Device**:
```bash
./gradlew installDebug
adb shell am start -n com.liuli.android/.MainActivity
```

**Verify**:
1. Grant location permission (required for WiFi multicast on Android 10+)
2. Ensure device on same WiFi as macOS server
3. Tap refresh icon
4. Server should appear within 5 seconds

---

## Troubleshooting

### macOS: Service Not Broadcasting

**Symptoms**: `dns-sd -B` doesn't show service

**Solutions**:
1. Check firewall settings: System Settings → Network → Firewall → Allow mDNS
2. Verify port not in use: `lsof -i :9050`
3. Check logs: `log stream --predicate 'subsystem == "com.apple.network"'`

### iOS: No Servers Found

**Symptoms**: Server list remains empty

**Solutions**:
1. Verify local network permission: Settings → Liuli → Local Network
2. Check same subnet: `ifconfig en0` on Mac, Settings → WiFi on iOS
3. Restart Network.framework browser (stop/start scanning)
4. Check Xcode console for NWBrowser errors

### Android: JmDNS Not Discovering

**Symptoms**: No services resolved

**Solutions**:
1. Verify multicast lock acquired: Check logcat for "MulticastLock"
2. Ensure WiFi connected (not mobile data): Settings → WiFi
3. Grant location permission: Settings → Apps → Liuli → Permissions
4. Restart JmDNS: Stop/start discovery

---

## Next Steps

1. **Certificate Implementation**: Follow [tofu-handshake.md](./contracts/tofu-handshake.md) to add TOFU authentication
2. **Heartbeat Protocol**: Implement heartbeat as per [heartbeat-protocol.md](./contracts/heartbeat-protocol.md)
3. **Integration Testing**: Test cross-platform discovery on real network
4. **Performance Tuning**: Profile battery usage and network overhead

---

## Resources

- [Bonjour Broadcast Contract](./contracts/bonjour-broadcast.md)
- [Heartbeat Protocol](./contracts/heartbeat-protocol.md)
- [TOFU Handshake](./contracts/tofu-handshake.md)
- [Data Model](./data-model.md)
- [Research Document](./research.md)
- [Full Specification](./spec.md)

**Document Status**: ✅ Complete
**For Support**: Contact development team or file issue on repository
