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
    private(set) var isPro = false
    /// True while a purchase or restore is in flight (drives the paywall spinner).
    private(set) var isWorking = false
    /// Last user-facing error, surfaced by the paywall. Cleared on the next action.
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    #if DEBUG
    /// Screenshot/demo builds unlock Pro so App Store shots show the gated views.
    /// Never compiled into a release build.
    private let forceUnlocked =
        ProcessInfo.processInfo.environment["FF_SCREENSHOT"]?.isEmpty == false
        || CommandLine.arguments.contains("--screenshot-inspect")
        || CommandLine.arguments.contains("--screenshot-demo")
    #endif

    /// Price string for UI, e.g. "$9.99". Falls back to a placeholder pre-load.
    var displayPrice: String { proProduct?.displayPrice ?? "$9.99" }

    /// Load the product, catch up on entitlements, and start listening for updates.
    /// Safe to call more than once; the updates listener is only started once.
    func start() async {
        #if DEBUG
        if forceUnlocked { isPro = true }
        #endif
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    await self?.handle(update)
                }
            }
        }
        await loadProduct()
        await refreshEntitlements()
    }

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
        #if DEBUG
        if forceUnlocked { isPro = true; return }
        #endif
        isPro = owned
    }
}
