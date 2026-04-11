//
//  Color+Adaptive.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/3/1.
//

import SwiftUI

extension Color {
    static func adaptive(light: Color, dark: Color, opacity: Double = 1.0) -> Color {
        Color(uiColor: UIColor { traitCollection in
            let resolvedColor = traitCollection.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
            let baseAlpha = resolvedColor.cgColor.alpha
            return resolvedColor.withAlphaComponent(baseAlpha * CGFloat(opacity))
        })
    }
}
