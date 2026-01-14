import SwiftUI
import Combine
import AppKit

extension Notification.Name {
    static let openSettingsWindow = Notification.Name("OpenSettingsWindow")
    static let resizePopover = Notification.Name("ResizePopover")
}

struct TokenPriceRow: Identifiable {
    let coinID: String
    let symbol: String
    let priceText: String

    var id: String { coinID }
}

@MainActor
final class PriceModel: ObservableObject {
    @AppStorage("coingecko_ids") private var idsRaw: String = "nockchain"
    @AppStorage("coingecko_api_key") private var apiKey: String = ""

    @Published var statusText: String = "Click the icon to refresh"
    @Published var rows: [TokenPriceRow] = []
    @Published var isError: Bool = false
    @Published var isLoading: Bool = false

    private var idsList: [String] {
        idsRaw
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var idsQueryValue: String {
        idsList.joined(separator: ",")
    }

    private var url: URL? {
        let ids = idsQueryValue
        guard !ids.isEmpty else { return nil }
        return URL(string: "https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&ids=\(ids)")
    }

    func fetch() async {
        isError = false
        isLoading = true
        statusText = "Loading…"

        guard let url else {
            isLoading = false
            statusText = "Set ids in Settings"
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                request.setValue(key, forHTTPHeaderField: "x-cg-demo-api-key")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                isError = true
                isLoading = false
                statusText = "HTTP error"
                return
            }

            let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)

            let ids = idsList
            rows = ids.map { id in
                if let usd = decoded[id]?["usd"] {
                    return TokenPriceRow(coinID: id, symbol: id.uppercased(), priceText: formatUSD(usd))
                } else {
                    return TokenPriceRow(coinID: id, symbol: id.uppercased(), priceText: "—")
                }
            }

            isLoading = false
            statusText = ""
        } catch {
            isError = true
            isLoading = false
            statusText = "Network error"
        }
    }

    private func formatUSD(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"

        if value >= 1000 {
            f.maximumFractionDigits = 0
        } else if value >= 1 {
            f.maximumFractionDigits = 2
        } else {
            f.maximumFractionDigits = 4
        }

        return f.string(from: NSNumber(value: value)) ?? "$\(value)"
    }
}

private struct PriceRowView: View {
    let row: TokenPriceRow
    let isHovered: Bool
    let isJustCopied: Bool
    let priceColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Text(row.symbol)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .frame(minWidth: 84, alignment: .leading)

            Spacer(minLength: 0)

            Text(row.priceText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .frame(width: priceColumnWidth, alignment: .trailing)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isJustCopied ? Color.primary.opacity(0.14) : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
        )
        .contentShape(Rectangle())
    }
}

struct PriceView: View {
    @EnvironmentObject private var model: PriceModel
    @State private var hoveredID: String? = nil
    @State private var showCopiedToast = false
    @State private var copiedID: String? = nil

    private let width: CGFloat = 300
    private let emptyMinHeight: CGFloat = 140
    private let maxHeight: CGFloat = 380

    private let priceColumnWidth: CGFloat = 124

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            main
                .overlay(alignment: .bottomTrailing) {
                    if showCopiedToast {
                        Text("Copied")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.primary.opacity(0.10))
                            )
                            .padding(.trailing, 6)
                            .padding(.bottom, 6)
                            .transition(.opacity)
                    }
                }
        }
    }

    private var main: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Group {
                if model.rows.isEmpty {
                    emptyState
                } else {
                    listCard
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: width, height: desiredHeight(), alignment: .topLeading)
        .onAppear { postResize() }
        .onChange(of: model.rows.count) { _, _ in postResize() }
        .onChange(of: model.isError) { _, _ in postResize() }
        .onChange(of: model.statusText) { _, _ in postResize() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Link("🎢", destination: URL(string: "https://github.com/sukoneck/coaster")!)
                .font(.system(size: 12, weight: .bold))

            Spacer()

            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 14, height: 14)   // fixed size avoids AppKit intrinsic sizing warnings
                    .help("Loading…")
            }

            Button {
                Task { await model.fetch() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button {
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("—")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if model.isError {
                HStack(spacing: 6) {
                    Text("⚠︎")
                    Text(model.statusText)
                }
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var listCard: some View {
        VStack(spacing: 2) {
            rowsList
        }
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var rowsList: some View {
        let useScroll = desiredHeightUnclamped() > maxHeight

        return Group {
            if useScroll {
                ScrollView {
                    VStack(spacing: 2) { rowsStack }
                        .padding(.bottom, 2)
                }
                .frame(maxHeight: maxHeight - 46)
            } else {
                VStack(spacing: 2) { rowsStack }
                    .padding(.bottom, 2)
            }
        }
    }

    private var rowsStack: some View {
        ForEach(model.rows) { row in
            PriceRowView(
                row: row,
                isHovered: hoveredID == row.id,
                isJustCopied: copiedID == row.id,
                priceColumnWidth: priceColumnWidth
            )
            .onHover { inside in
                hoveredID = inside ? row.id : (hoveredID == row.id ? nil : hoveredID)
            }
            .onTapGesture {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(row.priceText, forType: .string)

                copiedID = row.id

                withAnimation(.easeOut(duration: 0.12)) {
                    showCopiedToast = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    copiedID = nil
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.12)) {
                        showCopiedToast = false
                    }
                }
            }

            Divider()
                .opacity(0.14)
        }
    }

    private func desiredHeightUnclamped() -> CGFloat {
        let outerPadding: CGFloat = 16
        let header: CGFloat = 18
        let gapAfterHeader: CGFloat = 8

        if model.rows.isEmpty {
            let emptyBody: CGFloat = 92
            return outerPadding + header + gapAfterHeader + emptyBody
        }

        let rowHeight: CGFloat = 34
        let dividerHeight: CGFloat = 1
        let stackSpacing: CGFloat = 2
        let cardPadding: CGFloat = 8

        let n = CGFloat(model.rows.count)
        let itemCount = n * 2
        let spacingCount = max(0, itemCount - 1)

        let rowsBlock =
            cardPadding +
            n * rowHeight +
            n * dividerHeight +
            spacingCount * stackSpacing +
            2

        return outerPadding + header + gapAfterHeader + rowsBlock
    }

    private func desiredHeight() -> CGFloat {
        let h = desiredHeightUnclamped()
        if model.rows.isEmpty {
            return min(max(h, emptyMinHeight), maxHeight)
        } else {
            return min(h, maxHeight)
        }
    }

    private func postResize() {
        let h = desiredHeight()
        NotificationCenter.default.post(name: .resizePopover, object: nil, userInfo: ["height": Double(h)])
    }
}
