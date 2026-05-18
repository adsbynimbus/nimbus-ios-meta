//
//  NimbusMetaKitTests.swift
//  NimbusMetaKitTests
//
//  Created on 2/3/20.
//  Copyright © 2020 Nimbus Advertising Solutions Inc. All rights reserved.
//

@testable import NimbusKit
@testable import NimbusMetaKit
import XCTest

@MainActor
class NimbusRenderMetaKitTests: XCTestCase {

    func testEmptyMarkup_native_enabledTestMode() {
        Nimbus.configuration.testMode = true

        let ad = createNimbusAd(
            markupType: .native,
            markup: ""
        )
        let viewController = UIViewController()
        let view = UIView()

        let delegate = MockAdControllerDelegate()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: false,
            isRewarded: false,
            container: view,
            adPresentingViewController: viewController
        )
        controller.delegate = delegate
        controller.load()

        XCTAssertTrue(delegate.errors.isEmpty)

        XCTAssertNil(controller.fbAdView)
        XCTAssertNil(controller.fbInterstitialAd)
        XCTAssertNotNil(controller.fbNativeAd)
        XCTAssertNil(controller.fbRewardedVideoAd)
    }

    func testEmptyMarkup_static_enabledTestMode() {
        Nimbus.configuration.testMode = true

        let ad = createNimbusAd(
            markupType: .static,
            markup: ""
        )
        let viewController = UIViewController()
        let view = UIView()

        let delegate = MockAdControllerDelegate()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: false,
            isRewarded: false,
            container: view,
            adPresentingViewController: viewController
        )
        controller.delegate = delegate
        controller.load()

        XCTAssertTrue(delegate.errors.isEmpty)

        XCTAssertNotNil(controller.fbAdView)
        XCTAssertNil(controller.fbInterstitialAd)
        XCTAssertNil(controller.fbNativeAd)
        XCTAssertNil(controller.fbRewardedVideoAd)
    }

    func testEmptyMarkup_video_enabledTestMode() {
        Nimbus.configuration.testMode = true

        let ad = createNimbusAd(
            markupType: .video,
            markup: ""
        )
        let viewController = UIViewController()
        let view = UIView()

        let delegate = MockAdControllerDelegate()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: true,
            isRewarded: true,
            container: view,
            adPresentingViewController: viewController
        )
        controller.delegate = delegate
        controller.load()

        XCTAssertTrue(delegate.errors.isEmpty)

        XCTAssertNil(controller.fbAdView)
        XCTAssertNil(controller.fbInterstitialAd)
        XCTAssertNil(controller.fbNativeAd)
        XCTAssertNotNil(controller.fbRewardedVideoAd)
    }

    func testFBPlacementId() {
        Nimbus.configuration.testMode = false

        let ad = createNimbusAd(
            markupType: .native,
            markup: "nonEmptyMarkup",
            placementId: nil
        )
        let viewController = UIViewController()
        let view = UIView()

        let delegate = MockAdControllerDelegate()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: false,
            isRewarded: false,
            container: view,
            adPresentingViewController: viewController
        )
        controller.delegate = delegate
        controller.load()

        XCTAssertEqual(delegate.errors.count, 1)
        
        let error = delegate.errors[0]
        
        XCTAssertEqual(error.domain.rawValue, NimbusError.Domain.meta.rawValue)
        XCTAssertEqual(error.reason, .invalidState)
        XCTAssertEqual(error.stage, .render)
        XCTAssertEqual(error.detail, "Placement id is missing")
    }

    func testFBBannerAd() {
        Nimbus.configuration.testMode = false

        let ad = createNimbusAd(markupType: .static)
        let viewController = UIViewController()
        let view = UIView()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: false,
            isRewarded: false,
            container: view,
            adPresentingViewController: viewController
        )
        controller.load()

        XCTAssertNotNil(controller.fbAdView)
        XCTAssertNil(controller.fbInterstitialAd)
        XCTAssertNil(controller.fbNativeAd)
        XCTAssertNil(controller.fbRewardedVideoAd)
    }
    
    func testFBInterstitialAd_static() {
        Nimbus.configuration.testMode = false

        let ad = createNimbusAd(markupType: .static)
        let viewController = UIViewController()
        let view = UIView()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: true,
            isRewarded: false,
            container: view,
            adPresentingViewController: viewController
        )
        controller.load()

        XCTAssertNil(controller.fbAdView)
        XCTAssertNotNil(controller.fbInterstitialAd)
        XCTAssertNil(controller.fbNativeAd)
        XCTAssertNil(controller.fbRewardedVideoAd)
    }

    func testFBRewardedVideoAd_video() {
        Nimbus.configuration.testMode = false

        let ad = createNimbusAd(markupType: .video)
        let viewController = UIViewController()
        let view = UIView()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: true,
            isRewarded: true,
            container: view,
            adPresentingViewController: viewController
        )
        controller.load()

        XCTAssertNil(controller.fbAdView)
        XCTAssertNil(controller.fbInterstitialAd)
        XCTAssertNil(controller.fbNativeAd)
        XCTAssertNotNil(controller.fbRewardedVideoAd)
    }

    func testFBNativeAd() {
        Nimbus.configuration.testMode = false

        let ad = createNimbusAd(markupType: .native)
        let viewController = UIViewController()
        let view = UIView()

        let controller = NimbusMetaAdController(
            response: ad,
            isBlocking: false,
            isRewarded: false,
            container: view,
            adPresentingViewController: viewController
        )
        controller.load()

        XCTAssertNil(controller.fbAdView)
        XCTAssertNil(controller.fbInterstitialAd)
        XCTAssertNotNil(controller.fbNativeAd)
        XCTAssertNil(controller.fbRewardedVideoAd)
    }

    private func createNimbusAd(
        markupType: NimbusResponse.Bid.MarkupType,
        markup: String = "",
        placementId: String? = "placementId"
    ) -> NimbusResponse {
        NimbusResponse(
            id: "",
            bid: .init(
                mtype: markupType,
                adm: markup,
                price: 0,
                ext: .init(omp: .init(buyer: "facebook", buyerPlacementId: placementId))
            )
        )
    }
}

class MockAdControllerDelegate: AdController.Delegate {
    var errors: [NimbusError] = []

    func didRegisterImpressionForView() {}

    func didReceiveNimbusEvent(event: AdEvent) {}

    func didReceiveNimbusError(error: NimbusError) {
        errors.append(error)
    }
}
