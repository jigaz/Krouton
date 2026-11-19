cask "krouton" do
  version "1.0.0"
  sha256 :no_check

  url "https://github.com/krouton-app/krouton/releases/download/v#{version}/Krouton.app.zip"
  name "Krouton"
  desc "Native optical disc mastering, bad-sector rescue, and distributed burn-pool suite"
  homepage "https://krouton.app"

  depends_on macos: ">= :sonoma"
  depends_on formula: "ffmpeg"

  app "Krouton.app"

  zap trash: [
    "~/Library/Application Support/app.krouton",
    "~/Library/Caches/app.krouton",
    "~/Library/Preferences/app.krouton.plist",
  ]
end
