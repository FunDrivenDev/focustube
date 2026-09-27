# The cask the Publish workflow writes into rlvdx/homebrew-tap, with its version and
# sha256 filled in.
cask "focustube" do
  version "0.0.0"
  sha256 :no_check

  url "https://github.com/rlvdx/homebrew-tap/releases/download/focustube-#{version}/focustube-#{version}-macos-arm64.zip"
  name "focustube"
  desc "Filters the noise on YouTube into a focused, learning-oriented feed of the channels and topics you choose."
  homepage "https://github.com/rlvdx/homebrew-tap"

  depends_on arch: :arm64
  depends_on macos: ">= :ventura"

  app "focustube.app"

  # focustube is ad-hoc signed, not signed with a Developer ID, so Gatekeeper would refuse
  # to open it while it carries the quarantine flag of the download.
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/focustube.app"]
  end

  zap trash: [
    "~/Library/Application Support/dev.fundrivendev.focustube",
    "~/Library/Caches/dev.fundrivendev.focustube",
    "~/Library/WebKit/dev.fundrivendev.focustube",
  ]
end
