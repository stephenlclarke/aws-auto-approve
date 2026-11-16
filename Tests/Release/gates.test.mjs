import { test } from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";

const sha = "1".repeat(40);
const required = ["quality", "unit-tests", "ASAN", "TSAN", "CodeQL (Swift)",
  "CodeQL (JavaScript)", "CodeQL (Ruby)", "CodeQL (Actions)", "release-tools"];

for (const scenario of ["ready", "missing", "failed", "pending", "wrong-app", "stale", "truncated", "failed-rerun"]) {
  test(`release gate is closed unless every current-main check passed: ${scenario}`, () => {
    const root = mkdtempSync(join(tmpdir(), "aws-release-gate-"));
    try {
      mkdirSync(join(root, "bin"));
      const checks = required.map((name, id) => ({ id, name, status: "completed", conclusion: "success", app: { slug: "github-actions" } }));
      if (scenario === "missing") checks.pop();
      if (scenario === "failed") checks[0].conclusion = "failure";
      if (scenario === "pending") checks[0].status = "in_progress";
      if (scenario === "wrong-app") checks[0].app.slug = "untrusted";
      if (scenario === "failed-rerun") checks.push({ ...checks[0], id: 100, conclusion: "failure" });
      writeFileSync(join(root, "checks.json"), JSON.stringify({ total_count: scenario === "truncated" ? 101 : checks.length, check_runs: checks }));
      writeFileSync(join(root, "bin/gh"), `#!/bin/bash\nif [[ "$2" == */commits/main ]]; then printf '%s\\n' "$TEST_MAIN_SHA"; else cat "$RUNNER_TEMP/checks.json"; fi\n`, { mode: 0o755 });
      const environment = { ...process.env, PATH: `${join(root, "bin")}:${process.env.PATH}`, RUNNER_TEMP: root,
        GITHUB_REPOSITORY: "fixture/repository", TEST_MAIN_SHA: scenario === "stale" ? "2".repeat(40) : sha };
      delete environment.BASH_ENV;
      delete environment.ENV;
      const result = spawnSync("bash", ["Tools/release-ready.sh", sha], {
        encoding: "utf8",
        env: environment,
      });
      if (scenario === "truncated") assert.notEqual(result.status, 0);
      else {
        assert.equal(result.status, 0, result.stderr);
        assert.equal(result.stdout.trim(), scenario === "ready" ? "ready=true" : "ready=false");
      }
    } finally { rmSync(root, { recursive: true, force: true }); }
  });
}
