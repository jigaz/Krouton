# Homebrew cask for Krouton.app. Release zips come from Scripts/bundle-app.sh, one per architecture.
# For each release, update version and both sha256 values (bundle-app.sh prints them).
cask "krouton" do
  arch arm: "arm64", intel: "x86_64"

  version "1.0.0"
  sha256 arm:   :no_check,
         intel: :no_check

  url "https://github.com/jigaz/Krouton/releases/download/v#{version}/Krouton-#{version}-macOS-#{arch}.zip",
      verified: "github.com/jigaz/Krouton/"
  name "Krouton"
  desc "Burn, copy and label CDs, DVDs and Blu-ray discs"
  homepage "https://krouton.app/"

  depends_on macos: ">= :sonoma"

  app "Krouton.app"
  binary "#{appdir}/Krouton.app/Contents/MacOS/Krouton", target: "krouton"

  caveats <<~EOS
    Shrinking DVDs re-encodes video with ffmpeg, which is not installed with Krouton:
      brew install ffmpeg
  EOS

  zap trash: [
    "~/Library/Application Support/app.krouton",
    "~/Library/Caches/app.krouton",
    "~/Library/Preferences/app.krouton.plist",
    "~/Library/Saved Application State/app.krouton.savedState",
  ]
end
