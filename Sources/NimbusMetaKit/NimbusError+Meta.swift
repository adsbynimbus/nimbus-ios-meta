//
//  NimbusError+Meta.swift
//  NimbusMetaKit
//
//  Created on 2/23/26.
//  Copyright © 2026 Nimbus Advertising Solutions Inc. All rights reserved.
//

import NimbusKit

extension NimbusError.Domain {
    static let meta = Self(rawValue: "meta")
}

extension NimbusError {
    static func meta(reason: Reason = .failure, stage: Stage, detail: String? = nil) -> NimbusError {
        NimbusError(reason: reason, domain: .meta, stage: stage, detail: detail)
    }
}
