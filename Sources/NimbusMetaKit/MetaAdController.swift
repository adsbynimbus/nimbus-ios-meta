//
//  MetaAdController.swift
//  NimbusMetaKit
//
//  Created on 1/30/20.
//  Copyright © 2020 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import FBAudienceNetwork

// Internal: Do NOT implement delegate conformance as separate extensions as the methods will not be found in runtime when built as a static library
final class MetaAdController: AdController,
                              @MainActor FBAdViewDelegate,
                              @MainActor FBNativeAdDelegate,
                              @MainActor FBInterstitialAdDelegate,
                              @MainActor FBRewardedVideoAdDelegate {
    
    var fbAdView: FBAdView?
    var fbInterstitialAd: FBInterstitialAd?
    var fbNativeAd: FBNativeAd?
    var fbRewardedVideoAd: FBRewardedVideoAd?
    
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
            let adSize = switch response.bid.h {
            case 50: kFBAdSizeHeight50Banner
            case 90: kFBAdSizeHeight90Banner
            case 250: kFBAdSizeHeight250Rectangle
            default: FBAdSize(size: response.bid.size)
            }
            
            fbAdView = FBAdView(
                placementID: placementId,
                adSize: adSize,
                rootViewController: adPresentingViewController
            )
            fbAdView?.delegate = self
            fbAdView?.loadAd(withBidPayload: response.bid.adm)
        case .rewarded:
            fbRewardedVideoAd = FBRewardedVideoAd(placementID: placementId)
            fbRewardedVideoAd?.delegate = self
            fbRewardedVideoAd?.load(withBidPayload: response.bid.adm)
        @unknown default:
            sendNimbusError(.meta(reason: .unsupported, stage: .render, detail: "adRenderType: \(adRenderType.rawValue)"))
        }
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
        } else if let fbInterstitialAd, fbInterstitialAd.isAdValid {
            fbInterstitialAd.show(fromRootViewController: adPresentingViewController)
        } else if let fbRewardedVideoAd, let adPresentingViewController, fbRewardedVideoAd.isAdValid {
            fbRewardedVideoAd.show(fromRootViewController: adPresentingViewController)
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
        sendNimbusError(.meta(stage: .render, detail: error.localizedDescription))
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
        
        // Meta uses video completion as the reward signal
        if adRenderType == .rewarded {
            sendNimbusEvent(.rewardEarned)
        }
    }
    
    func rewardedVideoAdDidClose(_ rewardedVideoAd: FBRewardedVideoAd) {
        destroy()
    }
}
