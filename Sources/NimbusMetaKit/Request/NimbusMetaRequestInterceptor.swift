//
//  NimbusMetaRequestInterceptor.swift
//  NimbusMetaKit
//
//  Created on 10/4/19.
//  Copyright © 2019 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import FBAudienceNetwork
import AppTrackingTransparency

/// Enables Meta demand for NimbusRequest
/// Add an instance of this to `NimbusAdManager.requestInterceptors`
final class NimbusMetaRequestInterceptor {
    
    /// Force a test ad for Meta
    let forceTestAd: Bool
    
    /// Facebook app id
    private let appId: String
    
    private let bridge: MetaRequestBridgeType
    
    init(appId: String, forceTestAd: Bool = false, bridge: MetaRequestBridgeType = MetaRequestBridge()) {
        self.appId = appId
        self.forceTestAd = forceTestAd
        self.bridge = bridge
        
        if #available(iOS 14.5, *), ATTrackingManager.trackingAuthorizationStatus == .authorized {
            FBAdSettings.setAdvertiserTrackingEnabled(true)
        }
    }
    
    private var isAppendingTestPayload: Bool {
        get async {
            await Nimbus.configuration.testMode && forceTestAd
        }
    }
}

extension NimbusMetaRequestInterceptor: NimbusRequest.Interceptor {
    func modifyRequest(request: NimbusRequest) async throws -> [NimbusRequest.Delta] {
        var deltas: [NimbusRequest.Delta] = [
            .init(target: .user, key: "facebook_buyeruid", value: bridge.bidToken),
            .init(target: .impression, key: "facebook_app_id", value: appId),
        ]
        
        if await isAppendingTestPayload {
            deltas.append(.init(
                target: .impression,
                key: "facebook_test_ad_type",
                value: request.adUnitType.metaTestAdType)
            )
        }
        
        return deltas
    }
}

fileprivate extension AdUnitType {
    var metaTestAdType: String {
        switch self {
        case .rewarded: "VID_HD_9_16_39S_APP_INSTALL"
        default: "IMG_16_9_LINK"
        }
    }
}
