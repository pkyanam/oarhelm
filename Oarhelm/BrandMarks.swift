import SwiftUI

/// An official provider mark when bundled; otherwise a neutral placeholder.
struct ProviderMark: View {
    let provider: String
    var size: CGFloat = 18

    private var asset: String? {
        switch provider.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
        case "capy": "BrandCapy"
        case "openai", "open ai": "BrandOpenAI"
        case "moonshotai", "moonshot", "moonshot ai", "kimi": "BrandKimi"
        case "zai", "z.ai": "BrandZai"
        case "minimax": "BrandMiniMax"
        case "nvidia": "BrandNVIDIA"
        case "meta", "llama": "BrandMeta"
        case "meituan": "BrandMeituan"
        case "particle": "BrandParticle"
        case "anthropic", "claude": "BrandAnthropic"
        case "google", "gemini": "BrandGoogle"
        case "xai", "x.ai": "BrandXAI"
        case "deepseek": "BrandDeepSeek"
        case "qwen", "alibaba": "BrandQwen"
        case "tencent": "BrandTencent"
        case "xiaomi": "BrandXiaomi"
        default: nil
        }
    }

    var body: some View {
        Group {
            if let asset {
                Image(asset)
                    .renderingMode(["BrandOpenAI", "BrandNVIDIA", "BrandMeta"].contains(asset) ? .template : .original)
                    .resizable().scaledToFit()
            } else {
                Image(systemName: "sparkles").resizable().scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(provider)
    }
}

struct CapyWordmark: View {
    var height: CGFloat = 18
    var body: some View {
        Image("BrandCapyWordmark").resizable().scaledToFit().frame(height: height)
            .accessibilityLabel("Capy")
    }
}
