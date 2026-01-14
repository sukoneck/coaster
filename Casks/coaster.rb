cask "coaster" do
  version :latest
  sha256 :no_check

  url "https://github.com/sukoneck/coaster/releases/latest/download/coaster-latest-macos.zip"
  name "Coaster"
  desc "Price tracker for macOS menu bar"
  homepage "https://github.com/sukoneck/coaster"

  app "coaster.app"

  caveats do
    <<~EOS
      This app is not signed/notarized, so macOS may block it.
      If macOS says it's damaged, run:

        xattr -dr com.apple.quarantine /Applications/coaster.app
    EOS
  end
end
