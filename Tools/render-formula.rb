#!/usr/bin/env ruby
# Render the maintained formula template from the two completed release archives.
require "digest"

version = ARGV.first
abort "Usage: render-formula.rb VERSION" unless ARGV.length == 1 && version.match?(/\A\d+\.\d+\.\d+\z/)

root = File.expand_path("..", __dir__)
formula = File.read(File.join(root, "Formula/aws-auto-approve.rb.in"))
formula = formula.gsub("@VERSION@", version)
{ "arm64" => "@ARM64_SHA256@", "x86_64" => "@X86_64_SHA256@" }.each do |architecture, marker|
  archive = File.join(root, "dist/release/aws-auto-approve-#{version}-macos-#{architecture}.tar.gz")
  formula = formula.gsub(marker, Digest::SHA256.file(archive).hexdigest)
end
abort "Formula template contains an unresolved marker" if formula.match?(/@[A-Z0-9_]+@/)
puts formula
