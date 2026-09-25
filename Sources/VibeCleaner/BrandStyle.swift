// Copyright 2026 soumessias
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import AppKit
import SwiftUI

enum VibePalette {
    static let accent = Color(nsColor: NSColor(name: nil) { appearance in
        let match = appearance.bestMatch(from: [.aqua, .darkAqua])
        if match == .darkAqua {
            return NSColor(srgbRed: 0.42, green: 0.83, blue: 0.98, alpha: 1)
        }
        return NSColor(srgbRed: 0.03, green: 0.36, blue: 0.70, alpha: 1)
    })

    static let action = Color(nsColor: .systemBlue)
    static let review = Color(nsColor: .systemOrange)
}

enum VibeBrand {
    static let logo: NSImage? = {
        guard let url = Bundle.module.url(forResource: "VibeCleanerLogo", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        image.isTemplate = false
        return image
    }()
}

enum VibeCreator {
    static let name = "soumessias"
    static let website = URL(string: "https://soumessias.com")!
}
