//
//  MetaAdControllerTests.swift
//  NimbusMetaKit
//  Created on 10/21/26
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import Testing
@testable import NimbusMetaKit
@testable import NimbusKit
import UIKit
import FBAudienceNetwork

private let placementId = "test-placement-id"

/// These tests call `load()` on real FBAudienceNetwork objects, like `NimbusRenderMetaKitTests`. Loading
/// an empty bid payload never calls back synchronously, so every callback in a test is one we fire.
@Suite("Meta AdController tests")
@MainActor
struct MetaAdControllerTests {

    // MARK: - Banner

    @Test func bannerAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.banner)
        adController.load()

        #expect(adController.fbNativeAd == nil)
        #expect(adController.fbInterstitialAd == nil)
        #expect(adController.fbRewardedVideoAd == nil)

        let banner = try #require(adController.fbAdView)
        let meta = try #require(banner.delegate, "banner delegate not wired")
        #expect(meta === adController)

        meta.adViewDidLoad?(banner)
        #expect(delegate.events == [.loaded])

        let isAdValid = stubIsAdValid(FBAdView.self)
        defer { isAdValid.restore() }

        #expect(adController.adView.subviews.isEmpty)
        adController.start()
        #expect(adController.adView.subviews.first === banner)

        meta.adViewWillLogImpression?(banner)
        #expect(delegate.events == [.loaded, .impression])

        meta.adViewDidClick?(banner)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)
    }

    @Test func bannerAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.banner, width: 300, height: 250)
        adController.load()

        let banner = try #require(adController.fbAdView)
        let meta = try #require(banner.delegate, "banner delegate not wired")

        meta.adView?(banner, didFailWithError: metaError)

        expectMetaError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Native

    @Test func nativeAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.native)
        adController.load()

        #expect(adController.fbAdView == nil)
        #expect(adController.fbInterstitialAd == nil)
        #expect(adController.fbRewardedVideoAd == nil)

        let native = try #require(adController.fbNativeAd)
        let meta = try #require(native.delegate, "native delegate not wired")
        #expect(meta === adController)

        let nativeView = UIView()
        var providedAd: FBNativeAd?
        MetaExtension.nativeAdViewProvider = { _, ad in
            providedAd = ad
            return nativeView
        }
        defer { MetaExtension.nativeAdViewProvider = nil }

        let isAdValid = stubIsAdValid(FBNativeAd.self)
        defer { isAdValid.restore() }

        meta.nativeAdDidLoad?(native)
        #expect(delegate.events == [.loaded])
        #expect(adController.adView.subviews.isEmpty)

        adController.start()
        #expect(adController.adView.subviews.first === nativeView)
        #expect(providedAd === native)
        // Still referenced while on screen so callbacks keep arriving and unregisterView runs on destroy
        #expect(adController.fbNativeAd === native)

        meta.nativeAdWillLogImpression?(native)
        #expect(delegate.events == [.loaded, .impression])

        meta.nativeAdDidClick?(native)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)
    }

    @Test func nativeAdUnregistersViewOnDestroy() throws {
        let (adController, delegate) = makeAdController(.native)
        adController.load()

        let native = try #require(adController.fbNativeAd)
        let meta = try #require(native.delegate, "native delegate not wired")

        MetaExtension.nativeAdViewProvider = { _, _ in UIView() }
        defer { MetaExtension.nativeAdViewProvider = nil }

        let isAdValid = stubIsAdValid(FBNativeAd.self)
        defer { isAdValid.restore() }

        let unregistered = CallRecorder()
        let unregisterView = MethodStub(FBNativeAd.self, "unregisterView", with: {
            (_: AnyObject) in unregistered.calls += 1
        } as @convention(block) (AnyObject) -> Void)
        defer { unregisterView.restore() }

        meta.nativeAdDidLoad?(native)
        adController.start()
        #expect(unregistered.calls == 0)

        adController.destroy()
        #expect(unregistered.calls == 1)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func nativeAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.native)
        adController.load()

        let native = try #require(adController.fbNativeAd)
        let meta = try #require(native.delegate, "native delegate not wired")

        meta.nativeAd?(native, didFailWithError: metaError)

        expectMetaError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Interstitial

    @Test func interstitialAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        adController.load()

        #expect(adController.fbAdView == nil)
        #expect(adController.fbNativeAd == nil)
        #expect(adController.fbRewardedVideoAd == nil)

        let interstitial = try #require(adController.fbInterstitialAd)
        let meta = try #require(interstitial.delegate, "interstitial delegate not wired")
        #expect(meta === adController)

        let isAdValid = stubIsAdValid(FBInterstitialAd.self)
        defer { isAdValid.restore() }
        let presented = PresentationRecorder()
        let show = stubShow(FBInterstitialAd.self, recordingInto: presented)
        defer { show.restore() }

        meta.interstitialAdDidLoad?(interstitial)
        #expect(delegate.events == [.loaded])
        #expect(presented.viewController == nil)

        adController.start()
        #expect(presented.viewController === presenter)
        // Still referenced while on screen so the close callback can arrive
        #expect(adController.fbInterstitialAd === interstitial)

        meta.interstitialAdWillLogImpression?(interstitial)
        #expect(delegate.events == [.loaded, .impression])

        meta.interstitialAdDidClick?(interstitial)
        #expect(delegate.events == [.loaded, .impression, .clicked])
        #expect(delegate.lastError == nil)

        meta.interstitialAdDidClose?(interstitial)
        #expect(delegate.lastError == nil)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
        #expect(adController.fbInterstitialAd == nil)
    }

    @Test func interstitialAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        adController.load()

        let interstitial = try #require(adController.fbInterstitialAd)
        let meta = try #require(interstitial.delegate, "interstitial delegate not wired")

        meta.interstitialAd?(interstitial, didFailWithError: metaError)

        expectMetaError(delegate)
        #expect(delegate.events.last == .destroyed)
    }

    @Test func invalidInterstitialIsNotPresented() throws {
        let (adController, delegate) = makeAdController(.interstitial)
        adController.load()

        let interstitial = try #require(adController.fbInterstitialAd)
        let meta = try #require(interstitial.delegate, "interstitial delegate not wired")

        let presented = PresentationRecorder()
        let show = stubShow(FBInterstitialAd.self, recordingInto: presented)
        defer { show.restore() }

        // isAdValid is left unstubbed: the unloaded SDK object reports it is not valid
        meta.interstitialAdDidLoad?(interstitial)
        adController.start()

        #expect(presented.viewController == nil)
        #expect(delegate.lastError?.reason == .invalidState)
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Rewarded

    @Test func rewardedAdEventsGetFired() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        adController.load()

        #expect(adController.fbAdView == nil)
        #expect(adController.fbNativeAd == nil)
        #expect(adController.fbInterstitialAd == nil)

        let rewarded = try #require(adController.fbRewardedVideoAd)
        let meta = try #require(rewarded.delegate, "rewarded delegate not wired")
        #expect(meta === adController)

        let isAdValid = stubIsAdValid(FBRewardedVideoAd.self)
        defer { isAdValid.restore() }
        let presented = PresentationRecorder()
        let show = stubShow(FBRewardedVideoAd.self, recordingInto: presented)
        defer { show.restore() }

        meta.rewardedVideoAdDidLoad?(rewarded)
        #expect(delegate.events == [.loaded])

        adController.start()
        #expect(presented.viewController === presenter)
        // Meta: keep the rewarded ad alive until its callbacks have fired
        #expect(adController.fbRewardedVideoAd === rewarded)

        meta.rewardedVideoAdWillLogImpression?(rewarded)
        #expect(delegate.events == [.loaded, .impression])

        meta.rewardedVideoAdDidClick?(rewarded)
        #expect(delegate.events == [.loaded, .impression, .clicked])

        meta.rewardedVideoAdVideoComplete?(rewarded)
        #expect(delegate.events == [.loaded, .impression, .clicked, .completed, .rewardEarned])
        #expect(delegate.lastError == nil)

        meta.rewardedVideoAdDidClose?(rewarded)
        #expect(delegate.lastError == nil)
        #expect(delegate.events.last == .destroyed)
        #expect(adController.fbRewardedVideoAd == nil)
    }

    @Test func rewardedAdGetsDestroyedOnLoadError() throws {
        let (adController, delegate) = makeAdController(.rewarded)
        adController.load()

        let rewarded = try #require(adController.fbRewardedVideoAd)
        let meta = try #require(rewarded.delegate, "rewarded delegate not wired")

        meta.rewardedVideoAd?(rewarded, didFailWithError: metaError)

        expectMetaError(delegate)
        #expect(!delegate.events.contains(.rewardEarned))
        #expect(delegate.events.last == .destroyed)
    }
    
    @Test func loadFailsWithoutPlacementId() {
        let adController = MetaAdController(
            response: NimbusResponse(id: "", bid: .init(mtype: .native, adm: "", price: 0, ext: .init())),
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: presenter
        )
        let delegate = MockDelegate()
        adController.delegate = delegate

        adController.load()

        #expect(adController.fbNativeAd == nil)
        #expect(delegate.lastError?.reason == .invalidState)
        #expect(delegate.lastError?.detail == "Placement id is missing")
        #expect(delegate.events.last == .destroyed)
    }

    // MARK: - Helpers

    /// Fresh per test: Swift Testing creates a new suite instance for every @Test.
    private let container = UIView()

    /// AdController holds adPresentingViewController weakly, so it must outlive the test body.
    private let presenter = UIViewController()

    private let metaError = NSError(
        domain: "com.facebook.ads.sdk",
        code: 1001,
        userInfo: [NSLocalizedDescriptionKey: "Meta test error"]
    )

    enum Format { case banner, native, interstitial, rewarded }

    private func makeAdController(
        _ format: Format,
        width: Int? = nil,
        height: Int? = nil
    ) -> (MetaAdController, MockDelegate) {
        let mtype: NimbusResponse.Bid.MarkupType = switch format {
        case .banner, .interstitial: .static
        case .native: .native
        case .rewarded: .video
        }

        let bid = NimbusResponse.Bid(
            mtype: mtype,
            adm: "",
            price: 0,
            ext: .init(omp: .init(buyer: "facebook", buyerPlacementId: placementId)),
            w: width,
            h: height
        )

        let adController = MetaAdController(
            response: NimbusResponse(id: "", bid: bid),
            isBlocking: format == .interstitial || format == .rewarded,
            isRewarded: format == .rewarded,
            container: container,
            adPresentingViewController: presenter
        )
        let delegate = MockDelegate()
        adController.delegate = delegate
        return (adController, delegate)
    }

    private func expectMetaError(_ delegate: MockDelegate, sourceLocation: SourceLocation = #_sourceLocation) {
        let error = delegate.lastError
        #expect(error != nil, sourceLocation: sourceLocation)
        #expect(error!.domain == NimbusError.Domain(rawValue: "meta"), sourceLocation: sourceLocation)
        #expect(error!.detail == "Meta test error", sourceLocation: sourceLocation)
    }

    /// Makes `isAdValid` return true for every instance of `cls` until restored.
    private func stubIsAdValid(_ cls: AnyClass) -> MethodStub {
        MethodStub(cls, "isAdValid", with: { (_: AnyObject) -> Bool in true } as @convention(block) (AnyObject) -> Bool)
    }

    /// Replaces `showAdFromRootViewController:` so nothing is really presented, recording the root view controller.
    private func stubShow(_ cls: AnyClass, recordingInto recorder: PresentationRecorder) -> MethodStub {
        MethodStub(cls, "showAdFromRootViewController:", with: {
            (_: AnyObject, viewController: UIViewController?) -> Bool in
            recorder.viewController = viewController
            return true
        } as @convention(block) (AnyObject, UIViewController?) -> Bool)
    }
}

// MARK: - Mocks

class MockDelegate: AdController.Delegate {
    var events: [AdEvent] = []
    var lastError: NimbusError?

    func didReceiveNimbusEvent(event: NimbusKit.AdEvent) {
        events.append(event)
    }

    func didReceiveNimbusError(error: NimbusKit.NimbusError) {
        lastError = error
    }
}

final class PresentationRecorder {
    weak var viewController: UIViewController?
}

final class CallRecorder {
    var calls = 0
}

/// Swaps an Objective-C method implementation for the duration of a test.
///
/// FBAudienceNetwork classes can't reliably be mocked by subclassing, and an SDK object that never
/// loaded reports `isAdValid == false`, so the tests stub the few methods presentation depends on.
/// Always `restore()` (use `defer`), since the swap applies to every instance of the class.
final class MethodStub {
    private let method: Method
    private let original: IMP

    init(_ cls: AnyClass, _ selector: String, with block: Any) {
        method = class_getInstanceMethod(cls, NSSelectorFromString(selector))!
        original = method_setImplementation(method, imp_implementationWithBlock(block))
    }

    func restore() {
        method_setImplementation(method, original)
    }
}
