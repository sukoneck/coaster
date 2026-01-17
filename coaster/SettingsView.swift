import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("coingecko_tickers") private var savedTickers: String = "btc"
    @AppStorage("coingecko_api_key") private var savedAPIKey: String = ""

    @State private var draft: String = ""
    @State private var apiKeyDraft: String = ""
    @State private var errorText: String? = nil
    @State private var saving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        Text("TICKERS")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 62, alignment: .leading)

                        TextField("nock, btc, eth", text: $draft)
                            .textFieldStyle(.roundedBorder)
                            .disabled(saving)
                    }

                    GridRow {
                        Color.clear
                            .frame(width: 62, height: 1)

                        Text("Tickers (comma-separated)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    GridRow {
                        Color.clear.frame(width: 62, height: 6)
                        Color.clear.frame(height: 6)
                    }

                    GridRow {
                        Text("API KEY")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 62, alignment: .leading)

                        SecureField("optional", text: $apiKeyDraft)
                            .textFieldStyle(.roundedBorder)
                            .disabled(saving)
                    }

                    GridRow {
                        Color.clear
                            .frame(width: 62, height: 1)

                        HStack(spacing: 0) {
                            Text("CoinGecko API key is sent as x-cg-demo-api-key. ")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Link("Get a key ↗", destination: URL(string: "https://support.coingecko.com/hc/en-us/articles/21880397454233-User-Guide-How-to-sign-up-for-CoinGecko-Demo-API-and-generate-an-API-key")!)
                                .font(.footnote)
                        }
                    }

                    GridRow {
                        Color.clear.frame(width: 62, height: 6)
                        Color.clear.frame(height: 6)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primary.opacity(0.03))
            )

            if let errorText {
                HStack(alignment: .top, spacing: 8) {
                    Text("⚠︎")
                    Text(errorText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.footnote)
                .foregroundStyle(.red)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.08))
                )
            }

            HStack(spacing: 10) {
                if saving {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                }

                Button() {
                    NSWorkspace.shared.open(URL(string: "https://github.com/sukoneck/coaster")!)
                } label: {
                    Label("Contribute ", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Spacer()

                Button("Cancel") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(saving)

                Button(saving ? "Saving…" : "Save") {
                    Task { await save() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(saving)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 480)
        .onAppear {
            draft = savedTickers
            apiKeyDraft = savedAPIKey
        }
    }

    private func save() async {
        if saving { return }
        saving = true
        errorText = nil

        let tickers = draft
            .lowercased()
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tickers.isEmpty else {
            errorText = "Enter at least one ticker."
            saving = false
            return
        }

        let joined = tickers.joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?vs_currencies=usd&symbols=\(joined)") else {
            errorText = "Invalid tickers."
            saving = false
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                request.setValue(key, forHTTPHeaderField: "x-cg-demo-api-key")
            }

            let (data, resp) = try await URLSession.shared.data(for: request)

            guard let http = resp as? HTTPURLResponse else {
                errorText = "Validation failed: no HTTP response."
                saving = false
                return
            }

            switch http.statusCode {
            case 200...299:
                break
            case 429:
                errorText = "Rate limited (HTTP 429). Try again later or add an API key."
                saving = false
                return
            case 401, 403:
                errorText = "Unauthorized (HTTP \(http.statusCode)). Your API key may be invalid."
                saving = false
                return
            default:
                errorText = "Validation failed (HTTP \(http.statusCode))."
                saving = false
                return
            }

            let decoded: [String: [String: Double]]
            do {
                decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
            } catch {
                errorText = "Validation failed: unexpected response format."
                saving = false
                return
            }

            var missing: [String] = []
            var noUSD: [String] = []

            for id in tickers {
                let k = String(id)
                guard let entry = decoded[k] else {
                    missing.append(k)
                    continue
                }
                if entry["usd"] == nil {
                    noUSD.append(k)
                }
            }

            if !missing.isEmpty {
                errorText = "Unknown id(s): \(missing.joined(separator: ", "))."
                saving = false
                return
            }

            if !noUSD.isEmpty {
                errorText = "No USD price for: \(noUSD.joined(separator: ", "))."
                saving = false
                return
            }

            savedTickers = joined
            savedAPIKey = key
            saving = false
            NSApp.keyWindow?.close()
        } catch {
            errorText = "Validation failed: network error."
            saving = false
        }
    }
}
