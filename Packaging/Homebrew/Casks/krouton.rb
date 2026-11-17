cask "krouton" do
  version "1.0.0"
  sha256 "9dcc74f6169f40713e7f8ef10440b70efd4f0099c4fa07691db09d0e35c91698"

  url "https://github.com/used/krouton/releases/download/v#{version}/Krouton-#{version}-macOS.zip"
  name "Krouton"
  desc "Optical media mastering studio and CLI for CD, DVD, Blu-ray, BDXL, and archival media"
  homepage "https://github.com/used/krouton"

  depends_on macos: ">= :sonoma"

  app "Krouton.app"
  binary "#{appdir}/Krouton.app/Contents/MacOS/Krouton", target: "krouton"

  zap trash: [
    "~/Library/Application Support/Krouton",
    "~/Library/Caches/com.krouton.opticalstudio",
    "~/Library/Preferences/com.krouton.opticalstudio.plist",
    "~/Library/Saved Application State/com.krouton.opticalstudio.savedState",
  ]
end
