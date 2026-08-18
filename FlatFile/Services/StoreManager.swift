//
//  StoreManager.swift
//  FlatFile
//
//  The single source of truth for the Pro unlock. FlatFile is free forever for
//  local CSV editing; the "power tools" (Inspect, Find & Replace, Column Stats)
//  are gated behind a one-time non-consumable purchase.
//
//  StoreKit 2. No receipts to parse, no server: entitlements come straight from
//  `Transaction.currentEntitlements`, and `Transaction.updates` keeps us live.
//

import StoreKit
import Observation

@MainActor
@Observable
final class StoreManager {
    /// Must match the In-App Purchase product ID created in App Store Connect
    /// (and the one in FlatFile.storekit used for local testing).
    static let proProductID = "aftrveil.FlatFile.pro"

    /// The loaded Pro product, or nil until `start()` finishes / on load failure.
    private(set) var proProduct: Product?
    /// The only thing the rest of the app reads to decide free vs Pro.
    /// FlatFile is now free forever — every tool is unlocked, so this is always
    /// true, the paywall is never presented, and no PRO badges render. The
    /// StoreKit machinery below is kept inert (unreachable) rather than deleted.
    private(set) var isPro = true
    /// True while a purchase or restore is in flight (drives the paywall spinner).
    private(set) var isWorking = false
    /// Last user-facing error, surfaced by the paywall. Cleared on the next action.
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    /// Price string for UI, e.g. "$9.99". Falls back to a placeholder pre-load.
    var displayPrice: String { proProduct?.displayPrice ?? "$9.99" }

    /// FlatFile is free, so there is nothing to load or listen for — Pro is
    /// already unlocked. Kept as a no-op so callers (FlatFileApp) still compile.
    func start() async {}

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            lastError = "Could not reach the App Store. Check your connection and try again."
        }
    }

    /// Recompute `isPro` from the current entitlements (the source of truth for a
    /// non-consumable — covers reinstalls and Family Sharing without a "restore").
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result,
               txn.productID == Self.proProductID,
               txn.revocationDate == nil {
                owned = true
            }
        }
        applyOwned(owned)
    }

    func purchase() async {
        guard let product = proProduct else {
            lastError = "The Pro upgrade is unavailable right now. Try again in a moment."
            return
        }
        lastError = nil
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let txn) = verification {
                    applyOwned(txn.revocationDate == nil)
                    await txn.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "The purchase didn't go through. \(error.localizedDescription)"
        }
    }

    /// Explicit "Restore Purchases" — syncs with the App Store, then re-reads
    /// entitlements. StoreKit normally restores automatically, but reviewers and
    /// users expect the button.
    func restore() async {
        lastError = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
        } catch {
            lastError = "Couldn't restore purchases. \(error.localizedDescription)"
        }
        await refreshEntitlements()
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let txn) = result else { return }
        if txn.productID == Self.proProductID {
            applyOwned(txn.revocationDate == nil)
        }
        await txn.finish()
    }

    private func applyOwned(_ owned: Bool) {
        // FlatFile is free — never downgrade from unlocked.
        isPro = true
    }
}
