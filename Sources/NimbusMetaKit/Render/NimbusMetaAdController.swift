//
//  NimbusMetaAdController.swift
//  NimbusMetaKit
//
//  Created on 1/30/20.
//  Copyright © 2020 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import FBAudienceNetwork

final class NimbusMetaAdController: AdController,
                                    @preconcurrency FBAdViewDelegate,
                                    @preconcurrency FBNativeAdDelegate,
                                    @preconcurrency FBInterstitialAdDelegate,
                                    @preconcurrency FBRewardedVideoAdDelegate {
    
    var fbAdView: FBAdView?
    var fbInterstitialAd: FBInterstitialAd?
    var fbNativeAd: FBNativeAd?
    var fbRewardedVideoAd: FBRewardedVideoAd?

    /// Determines whether ad has registered an impression
    private var hasRegisteredAdImpression = false

    private var isAdVisible = false
    
    private var is320by50Banner = false
    private var fbAdSize: FBAdSize?
    
    override class func setup(
        response: NimbusResponse,
        container: UIView,
        adPresentingViewController: UIViewController?
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: false,
            isRewarded: false,
            container: container,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override class func setupBlocking(
        response: NimbusResponse,
        isRewarded: Bool,
        adPresentingViewController: UIViewController
    ) -> AdController {
        let adController = Self.init(
            response: response,
            isBlocking: true,
            isRewarded: isRewarded,
            container: nil,
            adPresentingViewController: adPresentingViewController
        )
        
        return adController
    }
    
    override func load() {
        guard let placementId = response.bid.ext?.omp?.buyerPlacementId else {
            sendNimbusError(.meta(reason: .invalidState, stage: .render, detail: "Placement id is missing"))
            return
        }
        
        switch adRenderType {
        case .native:
            fbNativeAd = FBNativeAd(placementID: placementId)
            fbNativeAd?.delegate = self
            fbNativeAd?.loadAd(withBidPayload: response.bid.adm)

        case .interstitial:
            fbInterstitialAd = FBInterstitialAd(placementID: placementId)
            fbInterstitialAd?.delegate = self
            fbInterstitialAd?.load(withBidPayload: response.bid.adm)

        case .banner:
            switch response.bid.h {
            case 90: fbAdSize = kFBAdSizeHeight90Banner
            case 250: fbAdSize = kFBAdSizeHeight250Rectangle
            default:
                // Old integration also used to default to 320x50
                fbAdSize = kFBAdSizeHeight50Banner
                is320by50Banner = response.bid.w == 320 && response.bid.h == 50
            }
            
            loadBannerAd()
        case .rewarded:
            fbRewardedVideoAd = FBRewardedVideoAd(placementID: placementId)
            fbRewardedVideoAd?.delegate = self
            fbRewardedVideoAd?.load(withBidPayload: response.bid.adm)
        @unknown default:
            sendNimbusError(.meta(reason: .unsupported, stage: .render, detail: "adRenderType: \(adRenderType.rawValue)"))
        }
    }
    
    private func loadBannerAd() {
        // This is caught at init before this function ever gets called
        guard let placementId = response.bid.ext?.omp?.buyerPlacementId, let fbAdSize else {
            sendNimbusError(.meta(reason: .invalidState, stage: .render, detail: "Ad size is missing"))
            return
        }
        
        fbAdView = FBAdView(
            placementID: placementId,
            adSize: fbAdSize,
            rootViewController: adPresentingViewController
        )
        fbAdView?.delegate = self
        fbAdView?.loadAd(withBidPayload: response.bid.adm)
    }
    
    // MARK: - AdController overrides

    override func onStart() {
        presentIfNeeded()
    }
    
    override func onDestroy() {
        fbNativeAd?.unregisterView()
        
        fbAdView = nil
        fbNativeAd = nil
        fbInterstitialAd = nil
        fbRewardedVideoAd = nil
    }
    
    func presentIfNeeded() {
        guard started, adState == .ready else { return }
        
        adState = .resumed
        
        if let fbAdView, fbAdView.isAdValid {
            adView.addSubview(fbAdView)
            self.fbAdView = nil
        } else if let fbNativeAd, fbNativeAd.isAdValid {
            let fbNativeAdView: UIView
            if let customView = MetaExtension.nativeAdViewProvider {
                fbNativeAdView = customView(adView, fbNativeAd)
            } else {
                fbNativeAdView = FBNativeAdView(nativeAd: fbNativeAd, with: .dynamic)
            }
            
            fbNativeAdView.translatesAutoresizingMaskIntoConstraints = false
            adView.addSubview(fbNativeAdView)
            NSLayoutConstraint.activate([
                fbNativeAdView.leadingAnchor.constraint(equalTo: adView.leadingAnchor),
                fbNativeAdView.trailingAnchor.constraint(equalTo: adView.trailingAnchor),
                fbNativeAdView.topAnchor.constraint(equalTo: adView.topAnchor),
                fbNativeAdView.bottomAnchor.constraint(equalTo: adView.bottomAnchor)
            ])
            
            self.fbNativeAd = nil
        } else if let fbInterstitialAd, fbInterstitialAd.isAdValid {
            fbInterstitialAd.show(fromRootViewController: adPresentingViewController)
            self.fbInterstitialAd = nil
        } else if let fbRewardedVideoAd, let adPresentingViewController, fbRewardedVideoAd.isAdValid {
            fbRewardedVideoAd.show(fromRootViewController: adPresentingViewController)
            self.fbRewardedVideoAd = nil
        } else {
            sendNimbusError(.meta(reason: .invalidState, stage: .render, detail: "Ad \(adRenderType) is invalid and could not be presented."))
        }
    }

    // MARK: - FBAdViewDelegate
    
    func adViewDidLoad(_ adView: FBAdView) {
        adState = .ready
        sendNimbusEvent(.loaded)
        presentIfNeeded()
    }

    func adView(_ adView: FBAdView, didFailWithError error: Error) {
        if is320by50Banner {
            // Retry with the old banner size
            is320by50Banner = false
            fbAdSize = kFBAdSizeHeight50Banner
            loadBannerAd()
        } else {
            sendNimbusError(.meta(stage: .render, detail: error.localizedDescription))
        }
    }

    func adViewWillLogImpression(_ adView: FBAdView) {
        sendNimbusEvent(.impression)
    }

    func adViewDidClick(_ adView: FBAdView) {
        sendNimbusEvent(.clicked)
    }
    
    // MARK: - FBNativeAdDelegate
    
    func nativeAdDidLoad(_ nativeAd: FBNativeAd) {
        adState = .ready
        sendNimbusEvent(.loaded)
        presentIfNeeded()
    }

    func nativeAdWillLogImpression(_ nativeAd: FBNativeAd) {
        hasRegisteredAdImpression = true
        sendNimbusEvent(.impression)
    }

    func nativeAd(_ nativeAd: FBNativeAd, didFailWithError error: Error) {
        sendNimbusError(.meta(stage: .render, detail: error.localizedDescription))
    }

    func nativeAdDidClick(_ nativeAd: FBNativeAd) {
        sendNimbusEvent(.clicked)
    }
    
    // MARK: - FBInterstitialAdDelegate
    
    func interstitialAdDidLoad(_ interstitialAd: FBInterstitialAd) {
        adState = .ready
        sendNimbusEvent(.loaded)
        presentIfNeeded()
    }

    func interstitialAd(_ interstitialAd: FBInterstitialAd, didFailWithError error: Error) {
        sendNimbusError(.meta(stage: .render, detail: error.localizedDescription))
    }

    func interstitialAdWillLogImpression(_ interstitialAd: FBInterstitialAd) {
        sendNimbusEvent(.impression)
    }

    func interstitialAdDidClick(_ interstitialAd: FBInterstitialAd) {
        sendNimbusEvent(.clicked)
    }
    
    func interstitialAdDidClose(_ interstitialAd: FBInterstitialAd) {
        destroy()
    }
    
    // MARK: - FBRewardedVideoAdDelegate
    
    func rewardedVideoAdDidLoad(_ rewardedVideoAd: FBRewardedVideoAd) {
        adState = .ready
        sendNimbusEvent(.loaded)
        presentIfNeeded()
    }
    
    func rewardedVideoAd(_ rewardedVideoAd: FBRewardedVideoAd, didFailWithError error: Error) {
        sendNimbusError(.meta(stage: .render, detail: error.localizedDescription))
    }
    
    func rewardedVideoAdWillLogImpression(_ rewardedVideoAd: FBRewardedVideoAd) {
        sendNimbusEvent(.impression)
    }
    
    func rewardedVideoAdDidClick(_ rewardedVideoAd: FBRewardedVideoAd) {
        sendNimbusEvent(.clicked)
    }
    
    func rewardedVideoAdVideoComplete(_ rewardedVideoAd: FBRewardedVideoAd) {
        sendNimbusEvent(.completed)
    }
    
    func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        destroy()
    }
}

// Internal: Do NOT implement delegate conformance as separate extensions as the methods won't not be found in runtime when built as a static library
