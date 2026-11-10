class AwsAutoApprove < Formula
  desc "Native WebKit helper for locally initiated AWS SSO approval"
  homepage "https://github.com/stephenlclarke/aws-auto-approve"
  head "https://github.com/stephenlclarke/aws-auto-approve.git", branch: "main"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["16.0", :build]

  def install
    system "make", "bundle"
    prefix.install "dist/AWS Auto Approve.app"
    bin.install_symlink prefix/"AWS Auto Approve.app/Contents/MacOS/aws-auto-approve"
  end

  test do
    assert_match "Usage: aws-auto-approve", shell_output("#{bin}/aws-auto-approve --help")
  end
end
