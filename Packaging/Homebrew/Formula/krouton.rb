class Krouton < Formula
  desc "Optical media mastering suite and headless CLI for CD, DVD, Blu-ray, and BDXL"
  homepage "https://github.com/used/krouton"
  url "https://github.com/used/krouton/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"
  license "MIT"
  head "https://github.com/used/krouton.git", branch: "main"

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
    assert_match "data-universal", formats_json
    assert_match "bd-on-dvd", formats_json
  end
end
