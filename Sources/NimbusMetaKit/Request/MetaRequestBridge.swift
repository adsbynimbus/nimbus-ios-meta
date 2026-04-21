//
//  MetaRequestBridge.swift
//  NimbusMetaKit
//
//  Created on 2/3/26.
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import FBAudienceNetwork

protocol MetaRequestBridgeType: Sendable {
    var bidToken: String { get }
}

final class MetaRequestBridge: MetaRequestBridgeType {
    public var bidToken: String { FBAdSettings.bidderToken }
    
    @inlinable
    public static func set(coppa: Bool) {
        FBAdSettings.isMixedAudience = true
    }
    
    public init() {}
}
