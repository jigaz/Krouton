class Krouton < Formula
  desc "Command-line tool for planning, inspecting and building CD, DVD and Blu-ray images"
  homepage "https://krouton.app/"
  # Set url and sha256 to the first tagged release; until then use `brew install --HEAD`.
  url "https://github.com/jigaz/Krouton/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/jigaz/Krouton.git", branch: "main"

  depends_on :macos => :sonoma

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release", "--product", "Krouton"
    bin.install ".build/release/Krouton"
    bin.install_symlink "Krouton" => "krouton"
    man1.install "Packaging/man/krouton.1"

    generate_completions_from_executable(bin/"krouton", "completions", shells: [:bash, :zsh, :fish])
  end

  test do
    assert_match "krouton 1.0.0", shell_output("#{bin}/krouton --version")
    formats_json = shell_output("#{bin}/krouton formats --json")
    assert_match "data-hybrid", formats_json
    assert_match "bd-on-dvd", formats_json
  end
end
