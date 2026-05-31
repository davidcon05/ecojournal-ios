//
//  LocalImageView.swift
//  EcoJournal
//
//  Created by David Contreras on 5/25/26.
//

import SwiftUI
import UIKit

/// A view that loads local images directly from file URLs without AsyncImage caching
/// This ensures Dashboard updates when photos change by bypassing URLCache
struct LocalImageView<Placeholder: View>: View {
    let url: URL
    let placeholder: Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage = uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: url.absoluteString) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard url.isFileURL else { return }

        let url = url
        let loaded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data) else { return nil }
            // Pre-decode so the first frame isn't decoded on the main thread
            return await image.byPreparingForDisplay()
        }.value

        uiImage = loaded
    }
}
