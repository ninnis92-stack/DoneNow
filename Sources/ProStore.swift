import StoreKit
import SwiftUI

@MainActor
final class ProStore: ObservableObject {
    // This is the only product identifier used by the shipped app. The old
    // local.aelo identifier was a development product and must not grant Pro
    // access in TestFlight or production.
    static let productID = "com.naheeminnis.donenow.pro"
    static let productIDs = [productID]
    @Published private(set) var product: Product?
    @Published private(set) var hasPro = false
    @Published private(set) var entitlementLoaded = false
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchasing = false
    @Published var message: String?
    private var updates: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result { await transaction.finish() }
                await self.refreshEntitlement()
            }
        }
        loadTask = Task { [weak self] in
            await self?.load()
        }
    }

    deinit {
        updates?.cancel()
        loadTask?.cancel()
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: Self.productIDs)
            product = products.first(where: { $0.id == Self.productID })
            if product == nil {
                message = "Pro is not available in this App Store environment yet."
            } else {
                message = nil
            }
            await refreshEntitlement()
        } catch {
            message = "Pro is temporarily unavailable."
            await refreshEntitlement()
        }
    }

    func purchase() async {
        await ensureProductLoaded()
        guard let product else {
            message = "Pro is not available right now. Check your connection and try again."
            return
        }
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { message = "The purchase could not be verified."; return }
                await transaction.finish()
                await refreshEntitlement()
                if !hasPro { message = "Purchase completed; Pro access is still syncing. Please try Restore Purchases." }
                else { message = nil }
            case .pending: message = "The purchase is awaiting approval."
            case .userCancelled: message = nil
            @unknown default: message = "The purchase could not be completed."
            }
        } catch { message = "The purchase could not be completed." }
    }

    func restore() async {
        do { try await AppStore.sync(); await refreshEntitlement(); message = hasPro ? "Pro restored." : "No Pro purchase was found." }
        catch { message = "Purchases could not be restored." }
    }

    private func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        hasPro = entitled
        entitlementLoaded = true
    }

    private func ensureProductLoaded() async {
        if product != nil { return }
        if let loadTask {
            await loadTask.value
        }
        if product == nil { await load() }
    }
}
