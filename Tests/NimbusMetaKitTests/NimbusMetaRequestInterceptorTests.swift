//
//  NimbusMetaRequestInterceptorTests.swift
//  NimbusMetaKitTests
//
//  Created on 10/4/19.
//  Copyright © 2019 Nimbus Advertising Solutions Inc. All rights reserved.
//

@testable import NimbusMetaKit
@testable import NimbusKit
import Testing

@Suite("Meta request interceptor tests")
struct NimbusFANRequestInterceptorTests {
    @Test func fanTokenDataIsReturned() async throws {
        let interceptor = NimbusMetaRequestInterceptor(appId: "appId", bridge: MockMetaRequestBridge())
        let info = try await NimbusRequest(from: Nimbus.bannerAd(position: "test", size: .banner).adRequest!.request)
        let deltas = try await interceptor.modifyRequest(request: info)
        
        #expect(deltas.count == 2)
        
        #expect(deltas[0].target == .user)
        #expect(deltas[0].key == "facebook_buyeruid")
        #expect(deltas[0].value as? String == "bidderToken")
        
        #expect(deltas[1].target == .impression)
        #expect(deltas[1].key == "facebook_app_id")
        #expect(deltas[1].value as? String == "appId")
    }
    
    @MainActor
    @Test func fanTokenDataIsReturnedIncludingTestAdType() async throws {
        let tmp = Nimbus.configuration.testMode
        
        let interceptor = NimbusMetaRequestInterceptor(appId: "appId", forceTestAd: true, bridge: MockMetaRequestBridge())
        Nimbus.configuration.testMode = true
        
        let info = try NimbusRequest(from: Nimbus.bannerAd(position: "test", size: .banner).adRequest!.request)
        let deltas = try await interceptor.modifyRequest(request: info)
        
        #expect(deltas.count == 3)
        
        #expect(deltas[0].target == .user)
        #expect(deltas[0].key == "facebook_buyeruid")
        #expect(deltas[0].value as? String == "bidderToken")
        
        #expect(deltas[1].target == .impression)
        #expect(deltas[1].key == "facebook_app_id")
        #expect(deltas[1].value as? String == "appId")
        
        #expect(deltas[2].target == .impression)
        #expect(deltas[2].key == "facebook_test_ad_type")
        #expect(deltas[2].value as? String == "IMG_16_9_LINK")
        
        Nimbus.configuration.testMode = tmp
    }
    
    @Test
    @MainActor
    func fanTokenDataGetsInsertedIntoRequest() async throws {
        let interceptor = NimbusMetaRequestInterceptor(appId: "appId", bridge: MockMetaRequestBridge())
        
        let ad = try Nimbus.rewardedAd(position: "test")
        ad.adRequest!.request.interceptors = [interceptor]
        
        try await ad.adRequest!.request.modifyRequestWithExtras(
            configuration: Nimbus.configuration,
            vendorId: "",
            appVersion: "1.0.0"
        )
        
        #expect(ad.adRequest!.request.impressions[0].ext.extras["facebook_app_id"] as? String == "appId")
        #expect(ad.adRequest!.request.user?.ext?.extras["facebook_buyeruid"] as? String == "bidderToken")
    }
}

fileprivate final class MockMetaRequestBridge: MetaRequestBridgeType {
    var bidToken: String { "bidderToken" }
}
