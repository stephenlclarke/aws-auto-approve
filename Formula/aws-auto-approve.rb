class AwsAutoApprove < Formula
  desc "Native WebKit helper for locally initiated AWS SSO approval"
  homepage "https://github.com/stephenlclarke/aws-auto-approve"
  license "MIT"
  head "https://github.com/stephenlclarke/aws-auto-approve.git", branch: "main"

  depends_on macos: :sonoma
  depends_on xcode: ["16.0", :build]

  skip_clean "libexec/AWS Auto Approve.app"

  def install
    system "make", "bundle"
    libexec.install "dist/AWS Auto Approve.app"
    bin.install_symlink libexec/"AWS Auto Approve.app/Contents/MacOS/aws-auto-approve"
    bin.install "Integration/aws-auto-approve-login"
    zsh_completion.install "Completions/_aws-auto-approve", "Completions/_aws-auto-approve-login"
  end

  test do
    assert_match "Granted is not used", shell_output("#{bin}/aws-auto-approve-login --help")
    assert_match "Usage: aws-auto-approve", shell_output("#{bin}/aws-auto-approve --help")
  end
end
