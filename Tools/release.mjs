import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
import { analyzeCommits } from "@semantic-release/commit-analyzer";
import { generateNotes } from "@semantic-release/release-notes-generator";
import { inc, valid } from "semver";

const repository = "stephenlclarke/aws-auto-approve";
const repositoryUrl = `https://github.com/${repository}`;
const logger = { log() {}, error() {} };
const childEnvironment = { ...process.env };
delete childEnvironment.BASH_ENV;
delete childEnvironment.ENV;

/** Calculate the next version using semantic-release's Conventional Commit parser. */
export async function planRelease(commits, previousVersion = "0.0.0") {
  if (!valid(previousVersion)) throw new Error("Previous release version is invalid");
  const type = await analyzeCommits({ preset: "conventionalcommits" }, { commits, logger });
  return type ? { version: inc(previousVersion, type), type } : undefined;
}

/** Run a command without shell interpolation or exposing its environment. */
function command(program, args) {
  return execFileSync(program, args, { encoding: "utf8", env: childEnvironment }).trim();
}

/** Publish only the tested main commit; assemble assets while its release is a draft. */
async function main() {
  const args = process.argv.slice(2);
  if (args.length && (args.length !== 1 || args[0] !== "--dry-run")) throw new Error("Usage: node Tools/release.mjs [--dry-run]");
  const releases = JSON.parse(command("gh", ["release", "list", "--repo", repository,
    "--exclude-drafts", "--exclude-pre-releases", "--limit", "1", "--json", "tagName"]));
  const previousTag = releases[0]?.tagName;
  const previousVersion = previousTag?.replace(/^v/, "") ?? "0.0.0";
  if (previousTag && !/^v\d+\.\d+\.\d+$/.test(previousTag)) throw new Error("Latest release is not a stable version");
  const range = previousTag ? `${previousTag}..HEAD` : "HEAD";
  const records = command("git", ["log", "--format=%H%x00%B%x00", range]).split("\0");
  const commits = [];
  for (let index = 0; index + 1 < records.length; index += 2) {
    commits.push({ hash: records[index].trim(), message: records[index + 1].trim() });
  }
  const next = await planRelease(commits, previousVersion);
  if (!next) { console.log("No release is needed for these commits."); return; }
  const sha = command("git", ["rev-parse", "HEAD"]);
  const tag = `v${next.version}`;
  const context = {
    commits, logger, options: { repositoryUrl },
    lastRelease: previousTag ? { version: previousVersion, gitTag: previousTag } : {},
    nextRelease: { version: next.version, gitTag: tag, gitHead: sha },
  };
  const notes = await generateNotes({ preset: "conventionalcommits" }, context);
  if (args[0] === "--dry-run") {
    console.log(`Next release: ${tag} (${next.type}) at ${sha}`);
    console.log(notes);
    return;
  }
  execFileSync("bash", ["Tools/package-release.sh", next.version], { stdio: "inherit", env: childEnvironment });
  if (command("bash", ["Tools/release-ready.sh", sha]) !== "ready=true") {
    throw new Error("Release gates changed or main advanced; nothing was published");
  }
  writeFileSync("dist/release/notes.md", notes);
  const assets = ["arm64", "x86_64"].map(arch => `dist/release/aws-auto-approve-${next.version}-macos-${arch}.tar.gz`);
  assets.push("dist/release/SHA256SUMS", "dist/release/aws-auto-approve.rb");
  // Reuse only an unpublished draft for this exact commit after an interrupted upload.
  const drafts = JSON.parse(command("gh", ["release", "list", "--repo", repository,
    "--limit", "100", "--json", "tagName,isDraft"]));
  const draft = drafts.find(release => release.tagName === tag);
  if (draft) {
    const detail = JSON.parse(command("gh", ["api", `repos/${repository}/releases/tags/${tag}`]));
    if (!draft.isDraft || detail.target_commitish !== sha) throw new Error("Refusing to replace an existing release");
    execFileSync("gh", ["release", "upload", tag, "--repo", repository, "--clobber", ...assets], { stdio: "inherit", env: childEnvironment });
  } else {
    execFileSync("gh", ["release", "create", tag, "--repo", repository, "--target", sha, "--draft",
      "--title", tag, "--notes-file", "dist/release/notes.md", ...assets], { stdio: "inherit", env: childEnvironment });
  }
  execFileSync("gh", ["release", "edit", tag, "--repo", repository, "--draft=false", "--latest"], { stdio: "inherit", env: childEnvironment });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main().catch(error => { console.error(error.message); process.exitCode = 1; });
}
