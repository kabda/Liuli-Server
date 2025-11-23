import Foundation
import SwiftData

/// Actor implementation for pairing repository using SwiftData
actor PairingRepositoryImpl: PairingRepositoryProtocol {
    private let modelContext: ModelContext
    private let loggingService: LoggingServiceProtocol

    init(modelContext: ModelContext, loggingService: LoggingServiceProtocol) {
        self.modelContext = modelContext
        self.loggingService = loggingService
    }

    func savePairingRecord(_ record: PairingRecord) async throws {
        await loggingService.logInfo(
            component: "PairingRepository",
            message: "Saving pairing record for device: \(record.deviceID)"
        )

        let model = PairingRecordModel.fromDomain(record)
        modelContext.insert(model)

        try modelContext.save()

        await loggingService.logInfo(
            component: "PairingRepository",
            message: "Pairing record saved successfully"
        )
    }

    func updatePairingRecord(_ record: PairingRecord) async throws {
        let descriptor = FetchDescriptor<PairingRecordModel>(
            predicate: #Predicate { $0.id == record.id }
        )

        guard let model = try modelContext.fetch(descriptor).first else {
            throw PairingError.notFound
        }

        // Update fields
        model.serverName = record.serverName
        model.lastConnectedAt = record.lastConnectedAt
        model.successfulConnectionCount = record.successfulConnectionCount
        model.failedConnectionCount = record.failedConnectionCount
        model.autoReconnectEnabled = record.autoReconnectEnabled
        model.pinnedCertificateHash = record.pinnedCertificateHash

        try modelContext.save()

        await loggingService.logInfo(
            component: "PairingRepository",
            message: "Pairing record updated for device: \(record.deviceID)"
        )
    }

    func getPairingRecord(serverID: UUID) async throws -> PairingRecord? {
        let descriptor = FetchDescriptor<PairingRecordModel>(
            predicate: #Predicate { $0.serverID == serverID }
        )

        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return model.toDomain()
    }

    func getAllPairingRecords() async throws -> [PairingRecord] {
        let descriptor = FetchDescriptor<PairingRecordModel>(
            sortBy: [SortDescriptor(\.lastConnectedAt, order: .reverse)]
        )

        let models = try modelContext.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    func getLastConnectedServer() async throws -> PairingRecord? {
        let descriptor = FetchDescriptor<PairingRecordModel>(
            predicate: #Predicate { $0.autoReconnectEnabled == true },
            sortBy: [SortDescriptor(\.lastConnectedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let model = try modelContext.fetch(descriptor).first else {
            return nil
        }

        return model.toDomain()
    }

    func deletePairingRecord(serverID: UUID) async throws {
        let descriptor = FetchDescriptor<PairingRecordModel>(
            predicate: #Predicate { $0.serverID == serverID }
        )

        guard let model = try modelContext.fetch(descriptor).first else {
            throw PairingError.notFound
        }

        await loggingService.logInfo(
            component: "PairingRepository",
            message: "Deleting pairing record for server: \(serverID.uuidString)"
        )

        modelContext.delete(model)
        try modelContext.save()

        await loggingService.logInfo(
            component: "PairingRepository",
            message: "Pairing record deleted"
        )
    }

    func purgeExpiredRecords() async throws -> Int {
        await loggingService.logInfo(
            component: "PairingRepository",
            message: "Purging expired pairing records (30+ days old)"
        )

        let descriptor = FetchDescriptor<PairingRecordModel>()
        let allModels = try modelContext.fetch(descriptor)

        let expiredModels = allModels.filter { $0.isExpired }

        for model in expiredModels {
            modelContext.delete(model)
        }

        if !expiredModels.isEmpty {
            try modelContext.save()
        }

        await loggingService.logInfo(
            component: "PairingRepository",
            message: "Purged \(expiredModels.count) expired pairing records"
        )

        return expiredModels.count
    }
}
