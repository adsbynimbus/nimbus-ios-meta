//
//  MetaExtension.swift
//  Nimbus
//  Created on 4/2/25
//  Copyright © 2025 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit
import UIKit
import FBAudienceNetwork
import AppTrackingTransparency

/// Nimbus extension for Meta.
///
/// Enables Meta rendering when included in `Nimbus.initialize(...)`.
/// Supports dynamic enable/disable at runtime.
///
/// ### Notes:
///   - Instantiate within the `Nimbus.initialize` block; the extension is installed and enabled automatically.
///   - Disable rendering with `MetaExtension.disable()`.
///   - Re-enable rendering with `MetaExtension.enable()`.
public struct MetaExtension: NimbusRequestExtension, NimbusRenderExtension {
    @_documentation(visibility: internal)
    public var enabled = true
    
    @_documentation(visibility: internal)
    public var network: String { "facebook" }
    
    @_documentation(visibility: internal)
    public var controllerType: AdController.Type { NimbusMetaAdController.self }
    
    @_documentation(visibility: internal)
    public let interceptor: any NimbusRequest.Interceptor
    
    /// Creates a Meta extension.
    ///
    /// - Parameters:
    ///   - appId: Meta App ID
    ///   - forceTestAd: Forces Meta test ad if true
    ///
    /// ##### Usage
    /// ```swift
    /// Nimbus.initialize(publisher: "<publisher>", apiKey: "<apiKey>") {
    ///     MetaExtension(appId: "<appId>") // Enables Meta rendering
    /// }
    /// ```
    public init(appId: String, forceTestAd: Bool = false) {
        self.interceptor = NimbusMetaRequestInterceptor(appId: appId, forceTestAd: forceTestAd)
        
        FBAdSettings.setMediationService("Ads By Nimbus")
        
        if #available(iOS 14.5, *), ATTrackingManager.trackingAuthorizationStatus == .authorized {
            FBAdSettings.setAdvertiserTrackingEnabled(true)
        }
    }
    
    @_documentation(visibility: internal)
    public func coppaDidChange(coppa: Bool) {
        MetaRequestBridge.set(coppa: coppa)
    }
}

public extension MetaExtension {
    /**
     The UIView returned from this method should have all of the data set from the native ad
     on children views such as the call to action, image data, title, privacy icon etc.
     The view returned from this method should not be attached to the container passed in as
     it will be attached at a later time during the rendering process.

     - Parameters:
       - container: The container the layout will be attached to
       - nativeAd: The Facebook native ad with the relevant ad information

     - Returns: Your custom UIView that will be attached to the container
     */
    @MainActor
    @preconcurrency
    static var nativeAdViewProvider: ((_ container: UIView, _ nativeAd: FBNativeAd) -> UIView)?
}
