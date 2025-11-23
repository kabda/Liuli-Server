# TOFU Certificate Handshake Contract

**Feature**: 001-lan-auto-discovery
**Date**: 2025-11-23
**Protocol**: Trust-On-First-Use (TOFU) with SPKI Pinning

## Overview

This document specifies the Trust-On-First-Use (TOFU) certificate validation and pinning protocol used to establish secure connections between mobile clients and Liuli-Server without requiring a centralized Certificate Authority (CA).

---

## Protocol Flow

```
Mobile Client                              Liuli-Server
     │                                          │
     │  1. TCP Handshake                       │
     │─────────────────────────────────────────→│
     │                                          │
     │  2. TLS Client Hello                    │
     │─────────────────────────────────────────→│
     │                                          │
     │  3. TLS Server Hello + Certificate      │
     │←─────────────────────────────────────────│
     │                                          │
     │  4. Extract SPKI, compute SHA-256       │
     │                                          │
     │  5. Check if server_id is known         │
     │     ├─ Yes: Compare with pinned hash   │
     │     │   ├─ Match: Continue connection  │
     │     │   └─ Mismatch: ABORT + Alert     │
     │     │                                    │
     │     └─ No: Show TOFU prompt to user    │
     │         ├─ User accepts: Pin + continue │
     │         └─ User rejects: ABORT          │
     │                                          │
     │  6. TLS Handshake Complete              │
     │←────────────────────────────────────────→│
     │                                          │
     │  7. Establish VPN Tunnel                │
     │═════════════════════════════════════════│
```

---

## Certificate Requirements

### Server Certificate (Self-Signed)

**Key Type**: RSA 2048-bit or ECDSA P-256
**Validity Period**: 10 years (self-signed, no CA)
**Subject DN**: `CN=<server_device_name>`
**SAN (Subject Alternative Name)**:
- DNS: `<server_device_name>.local`
- IP: `<server_local_ip>`

**Example**:
```
Subject: CN=John's MacBook Pro
SAN: DNS:johns-mbp.local, IP:192.168.1.100
Issuer: CN=John's MacBook Pro (self-signed)
Valid From: 2025-01-01
Valid To: 2035-01-01
```

### Generation (macOS Server)

```swift
import Security
import CryptoKit

actor CertificateGenerator {
    func generateSelfSignedCertificate() throws -> (SecCertificate, SecKey) {
        // Generate RSA keypair
        let parameters: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(parameters as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }

        let publicKey = SecKeyCopyPublicKey(privateKey)!

        // Create certificate request
        let deviceName = Host.current().localizedName ?? "Liuli-Server"
        let subjectName = "CN=\(deviceName)"

        // Generate self-signed certificate (using SecCertificateCreate* APIs or OpenSSL)
        let certificate = try createX509Certificate(
            publicKey: publicKey,
            privateKey: privateKey,
            subjectName: subjectName,
            validityYears: 10
        )

        // Store in Keychain for reuse
        try storeInKeychain(certificate: certificate, privateKey: privateKey)

        return (certificate, privateKey)
    }

    func getSPKIFingerprint(certificate: SecCertificate) throws -> String {
        let publicKey = SecCertificateCopyKey(certificate)!

        var error: Unmanaged<CFError>?
        guard let spkiData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }

        let hash = SHA256.hash(data: spkiData)
        return hash.compactMap { String(format: "%02X", $0) }.joined()
    }
}
```

---

## SPKI Pinning

### Why SPKI (not Certificate)?

| Aspect | Certificate Pinning | SPKI Pinning |
|--------|---------------------|--------------|
| **Renewal** | Must re-pin on cert renewal | Survives renewal (same keypair) |
| **Rotation** | Breaks connection | Seamless if key unchanged |
| **Flexibility** | Rigid | Recommended by RFC 7469 |

**Decision**: Use SPKI pinning for long-term stability.

### Fingerprint Format

**Algorithm**: SHA-256
**Encoding**: Hexadecimal (64 characters)
**Display**: Colon-separated for human readability

**Example**:
```
Raw: A1B2C3D4E5F6789012345678901234567890123456789012345678901234ABCD
Display: A1:B2:C3:D4:E5:F6:78:90:12:34:56:78:90:12:34:56:78:90:12:34:56:78:90:12:34:56:78:90:12:34:AB:CD
```

---

## Client Implementation

### iOS (Swift + Security Framework)

```swift
actor VPNConnectionRepository {
    private let keychainService = "com.liuli.server-pins"

    func connect(to server: DiscoveredServer) async throws {
        // Establish TLS connection
        let connection = try await establishTLSConnection(
            host: server.address,
            port: server.port
        )

        // Extract server certificate
        guard let peerTrust = connection.peerTrust else {
            throw CertificateError.noCertificate
        }

        let certificate = SecTrustGetCertificateAtIndex(peerTrust, 0)!
        let fingerprint = try getSPKIFingerprint(certificate)

        // Check if we've pinned this server before
        if let pinnedFingerprint = try? loadPinnedFingerprint(serverID: server.id) {
            // Subsequent connection - validate against pinned cert
            guard fingerprint == pinnedFingerprint else {
                throw CertificateError.fingerprintMismatch(
                    expected: pinnedFingerprint,
                    actual: fingerprint
                )
            }

            // Pin valid, proceed
            await logEvent("certificate_validated", serverID: server.id)

        } else {
            // First connection - TOFU prompt
            let approved = await showTOFUPrompt(
                serverName: server.name,
                fingerprint: fingerprint.formatWithColons()
            )

            guard approved else {
                throw CertificateError.userRejected
            }

            // Save pin
            try savePinnedFingerprint(fingerprint, forServerID: server.id)
            await logEvent("certificate_pinned", serverID: server.id)
        }

        // Establish VPN tunnel
        try await establishVPNTunnel(via: connection)
    }

    private func getSPKIFingerprint(_ certificate: SecCertificate) throws -> String {
        let publicKey = SecCertificateCopyKey(certificate)!

        var error: Unmanaged<CFError>?
        guard let spkiData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }

        let hash = SHA256.hash(data: spkiData)
        return hash.compactMap { String(format: "%02X", $0) }.joined()
    }

    private func savePinnedFingerprint(_ fingerprint: String, forServerID serverID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: serverID.uuidString,
            kSecValueData as String: fingerprint.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess || status == errSecDuplicateItem else {
            throw KeychainError.saveFailed(status)
        }
    }

    private func loadPinnedFingerprint(serverID: UUID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: serverID.uuidString,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let fingerprint = String(data: data, encoding: .utf8) else {
            throw KeychainError.notFound
        }

        return fingerprint
    }
}
```

### Android (Kotlin + X509TrustManager)

```kotlin
class VpnConnectionRepository(
    private val context: Context
) {
    private val prefs = context.getSharedPreferences("server_pins", Context.MODE_PRIVATE)

    suspend fun connect(server: DiscoveredServer) {
        // Establish TLS connection
        val connection = establishTLSConnection(
            host = server.address,
            port = server.port,
            trustManager = createTOFUTrustManager(server)
        )

        // If we reach here, cert was validated or pinned
        establishVPNTunnel(connection)
    }

    private fun createTOFUTrustManager(server: DiscoveredServer): X509TrustManager {
        return object : X509TrustManager {
            override fun checkServerTrusted(chain: Array<X509Certificate>, authType: String) {
                val peerCert = chain[0]
                val fingerprint = getSPKIFingerprint(peerCert)

                val pinnedFingerprint = prefs.getString(server.id.toString(), null)

                if (pinnedFingerprint != null) {
                    // Subsequent connection - validate
                    if (fingerprint != pinnedFingerprint) {
                        throw CertificateException("Fingerprint mismatch: expected $pinnedFingerprint, got $fingerprint")
                    }
                    logEvent("certificate_validated", server.id)

                } else {
                    // First connection - TOFU
                    val approved = runBlocking {
                        showTOFUDialog(
                            serverName = server.name,
                            fingerprint = fingerprint.formatWithColons()
                        )
                    }

                    if (!approved) {
                        throw CertificateException("User rejected certificate")
                    }

                    // Save pin
                    prefs.edit()
                        .putString(server.id.toString(), fingerprint)
                        .apply()

                    logEvent("certificate_pinned", server.id)
                }
            }

            override fun checkClientTrusted(chain: Array<X509Certificate>, authType: String) {
                // Not used (server doesn't verify client cert)
            }

            override fun getAcceptedIssuers(): Array<X509Certificate> = emptyArray()
        }
    }

    private fun getSPKIFingerprint(cert: X509Certificate): String {
        val publicKey = cert.publicKey.encoded
        val digest = MessageDigest.getInstance("SHA-256")
        val hash = digest.digest(publicKey)
        return hash.joinToString("") { "%02X".format(it) }
    }
}

fun String.formatWithColons(): String {
    return chunked(2).joinToString(":")
}
```

---

## TOFU Prompt UI

### iOS (SwiftUI)

```swift
struct TOFUPromptView: View {
    let serverName: String
    let fingerprint: String
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Connect to \(serverName)?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Verify this certificate fingerprint matches the one displayed on your server:")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Text(fingerprint)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

            HStack(spacing: 16) {
                Button("Reject", role: .cancel, action: onReject)
                    .buttonStyle(.bordered)

                Button("Trust", action: onApprove)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
```

### Android (Jetpack Compose)

```kotlin
@Composable
fun TOFUPromptDialog(
    serverName: String,
    fingerprint: String,
    onApprove: () -> Unit,
    onReject: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onReject,
        icon = {
            Icon(
                imageVector = Icons.Default.Shield,
                contentDescription = null,
                modifier = Modifier.size(48.dp)
            )
        },
        title = {
            Text("Connect to $serverName?")
        },
        text = {
            Column {
                Text("Verify this certificate fingerprint matches the one displayed on your server:")

                Spacer(modifier = Modifier.height(12.dp))

                Text(
                    text = fingerprint,
                    fontFamily = FontFamily.Monospace,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color.Gray.copy(alpha = 0.1f))
                        .padding(8.dp)
                )
            }
        },
        confirmButton = {
            TextButton(onClick = onApprove) {
                Text("Trust")
            }
        },
        dismissButton = {
            TextButton(onClick = onReject) {
                Text("Reject")
            }
        }
    )
}
```

---

## Server-Side Fingerprint Display

Display fingerprint in server UI (Dashboard) for user verification:

```swift
struct ServerInfoView: View {
    let certificateFingerprint: String

    var body: some View {
        GroupBox("Certificate Fingerprint") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Show this code to verify new device connections:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(certificateFingerprint.formatWithColons())
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)

                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(certificateFingerprint, forType: .string)
                }
                .buttonStyle(.link)
            }
        }
    }
}
```

---

## Security Analysis

### Threat Model

| Attack | Mitigation | Residual Risk |
|--------|------------|---------------|
| **MITM on first connection** | User visual verification of fingerprint | Low (requires attacker to win race AND forge UI) |
| **Compromised server key** | User can "Forget Server" to re-pin | Low (local attack surface only) |
| **Malware reading Keychain/KeyStore** | OS-level protection (biometric unlock) | Low (requires device compromise) |
| **Certificate substitution** | SPKI pinning detects key change | None (attack prevented) |

### Comparison to CA-Based PKI

| Aspect | CA PKI | TOFU |
|--------|--------|------|
| **Infrastructure Cost** | High (CA setup, renewal) | Zero |
| **User Experience** | Transparent (when working) | One-time verification |
| **Attack Surface** | Global (CA compromise) | Local (LAN only) |
| **Suitability** | Enterprise, Internet-facing | Personal, LAN-only |

**Decision**: TOFU is appropriate for Liuli's use case (personal/small team, local network only).

---

## Certificate Lifecycle

### Initial Generation
- On first launch, server generates self-signed certificate
- Private key stored in Keychain (never leaves device)
- Fingerprint displayed in server UI

### Rotation (Optional)
- User initiates via Settings → "Regenerate Certificate"
- All client pins invalidated (force re-TOFU)
- Use case: Suspected compromise, key loss

### Revocation
- Client-side: User selects "Forget Server" → deletes pin
- Server-side: User selects "Clear All Clients" → regenerates cert (forces re-TOFU)

---

## Testing

### Unit Tests

```swift
func testFingerprintCalculation() throws {
    let testCert = loadTestCertificate()
    let fingerprint = try getSPKIFingerprint(testCert)

    XCTAssertEqual(fingerprint.count, 64)  // SHA-256 = 32 bytes = 64 hex chars
    XCTAssertTrue(fingerprint.allSatisfy { $0.isHexDigit })
}

func testKeychainStorage() throws {
    let testFingerprint = String(repeating: "A1", count: 32)
    let testServerID = UUID()

    try savePinnedFingerprint(testFingerprint, forServerID: testServerID)

    let loaded = try loadPinnedFingerprint(serverID: testServerID)
    XCTAssertEqual(loaded, testFingerprint)
}

func testFingerprintMismatch() async throws {
    let server = DiscoveredServer(/* ... */)
    let wrongFingerprint = String(repeating: "FF", count: 32)

    try savePinnedFingerprint(wrongFingerprint, forServerID: server.id)

    // Attempt connection with different cert
    await XCTAssertThrowsError(try await connect(to: server)) { error in
        XCTAssertTrue(error is CertificateError)
    }
}
```

### Integration Tests

```swift
func testTOFUFlow() async throws {
    // Start server with self-signed cert
    let server = try await startTestServer()
    let fingerprint = try server.getCertificateFingerprint()

    // Client connects for first time
    let client = TestClient()
    let promptShown = expectation(description: "TOFU prompt shown")

    client.onTOFUPrompt = { serverName, displayedFingerprint in
        XCTAssertEqual(serverName, "Test Server")
        XCTAssertEqual(displayedFingerprint, fingerprint.formatWithColons())
        promptShown.fulfill()
        return true  // User approves
    }

    try await client.connect(to: server)

    await fulfillment(of: [promptShown], timeout: 5.0)
    XCTAssertTrue(client.isConnected)

    // Disconnect and reconnect - should not prompt again
    await client.disconnect()

    client.onTOFUPrompt = { _, _ in
        XCTFail("TOFU prompt should not show on subsequent connections")
        return false
    }

    try await client.connect(to: server)
    XCTAssertTrue(client.isConnected)
}
```

---

**Document Status**: ✅ Complete
**Related**: [bonjour-broadcast.md](./bonjour-broadcast.md), [heartbeat-protocol.md](./heartbeat-protocol.md)
