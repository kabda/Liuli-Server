# Certificate Regeneration Procedure

**Feature**: 001-lan-auto-discovery
**Component**: macOS Server
**Purpose**: Guide for regenerating self-signed TLS certificates

## When to Regenerate Certificate

Regenerate the server certificate in these situations:

1. **Suspected Compromise**: If the private key may have been accessed by unauthorized parties
2. **Certificate Expiration**: Although certificates are valid for 10 years, regeneration may be needed earlier
3. **Security Policy**: Proactive rotation as part of security best practices
4. **Key Loss**: If the Keychain entry becomes corrupted or lost

## Impact of Regeneration

⚠️ **Important**: Certificate regeneration forces all mobile clients to re-validate via TOFU prompt.

- All existing client pins will become invalid
- Each mobile device must verify the new certificate fingerprint on next connection
- Users will see the TOFU prompt again, even if they previously trusted the server
- No data loss occurs - connection history remains intact

## Regeneration Steps (macOS Server)

### 1. Stop Bridge Service

Ensure no active connections before regenerating:

```swift
// In ViewModel or Use Case
await bridgeService.stopMonitoring()
```

### 2. Delete Existing Certificate

```swift
let keychainService = KeychainService()
try await keychainService.deleteCertificate()
```

### 3. Generate New Certificate

```swift
let certificateGenerator = CertificateGenerator(
    keychainService: keychainService
)

let (newCertificate, newFingerprint) = try await certificateGenerator.generateSelfSignedCertificate()
```

### 4. Display New Fingerprint in UI

The new certificate fingerprint must be visible in the Dashboard for mobile clients to verify:

```swift
// In Dashboard Settings Panel
Text("Certificate Fingerprint")
    .font(.headline)

Text(certificateFingerprint.formatWithColons())
    .font(.system(.body, design: .monospaced))
    .textSelection(.enabled)

Button("Copy Fingerprint") {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(certificateFingerprint, forType: .string)
}
```

Fingerprint format example:
```
A1:B2:C3:D4:E5:F6:78:90:12:34:56:78:90:12:34:56:78:90:12:34:56:78:90:12:34:56:78:90:12:34:AB:CD
```

### 5. Restart Bridge Service

```swift
try await bridgeService.startMonitoring()
```

The broadcast will automatically include the new certificate hash in the TXT record.

### 6. Notify Mobile Clients

Inform users that:
- Certificate was regenerated for security reasons
- They will see a TOFU prompt on next connection
- They should verify the fingerprint matches the Dashboard display

## Client-Side Re-Pairing

When mobile clients (iOS/Android) connect after certificate regeneration:

1. **Detection**: Client compares received certificate fingerprint with pinned value → mismatch detected
2. **TOFU Prompt**: Client displays new fingerprint for user verification
3. **User Action**: User verifies fingerprint matches Dashboard, then taps "Trust"
4. **Re-Pin**: Client stores new fingerprint, replacing old pin

## Automation (Optional)

For automated certificate rotation (e.g., every 6 months):

```swift
// Use Case: CheckCertificateExpirationUseCase
public struct CheckCertificateExpirationUseCase: Sendable {
    private let certificateGenerator: CertificateGenerator
    private let loggingService: LoggingServiceProtocol

    public func execute() async throws -> Bool {
        // Load certificate from Keychain
        let (certificate, _) = try await certificateGenerator.generateSelfSignedCertificate()

        // Check expiration (if within 30 days, regenerate proactively)
        // Implementation left as exercise
        return false  // Certificate still valid
    }
}
```

## Security Best Practices

1. **Display Fingerprint**: Always show certificate fingerprint in Dashboard UI
2. **Log Regeneration**: Record certificate regeneration events with timestamp
3. **Secure Storage**: Never expose private key - always use Keychain
4. **User Communication**: Notify users before planned regeneration
5. **Backup Strategy**: Consider exporting certificate for disaster recovery

## Troubleshooting

### Certificate Not Deleted

**Symptom**: `generateSelfSignedCertificate()` returns existing certificate

**Solution**: Explicitly call `deleteCertificate()` first

### Keychain Access Denied

**Symptom**: `KeychainError.storeFailed` with status `-25291`

**Solution**: Grant Keychain access permission to Liuli-Server in System Settings → Privacy & Security → Keychain

### Broadcast Doesn't Update

**Symptom**: Clients still receive old certificate hash in TXT record

**Solution**: Ensure bridge service was fully stopped and restarted after regeneration

## Code Reference

- Certificate Generation: `Data/Services/CertificateGenerator.swift`
- Keychain Storage: `Data/Services/KeychainService.swift`
- Fingerprint Calculation: `CertificateGenerator.calculateSPKIFingerprint()`
- TOFU Validation: See `specs/001-lan-auto-discovery/contracts/tofu-handshake.md`

## Example: Manual Regeneration Button

```swift
// In Dashboard Settings View
Button("Regenerate Certificate") {
    Task {
        do {
            // Stop bridge
            try await bridgeService.stopMonitoring()

            // Regenerate
            let keychainService = KeychainService()
            try await keychainService.deleteCertificate()

            let generator = CertificateGenerator(keychainService: keychainService)
            let (_, fingerprint) = try await generator.generateSelfSignedCertificate()

            // Update UI
            self.certificateFingerprint = fingerprint

            // Restart bridge
            try await bridgeService.startMonitoring()

            // Show success alert
            showAlert("Certificate regenerated successfully. Mobile clients will need to re-pair.")
        } catch {
            showAlert("Regeneration failed: \(error.localizedDescription)")
        }
    }
}
.buttonStyle(.bordered)
.foregroundColor(.orange)
```

---

**Document Status**: ✅ Complete
**Last Updated**: 2025-11-23
**Related**: [tofu-handshake.md](../contracts/tofu-handshake.md), [bonjour-broadcast.md](../contracts/bonjour-broadcast.md)
