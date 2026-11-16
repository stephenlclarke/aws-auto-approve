import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import { planRelease } from "../../Tools/release.mjs";

for (const [message, expected] of [
  ["feat: add an installer", "minor"],
  ["fix(auth): preserve failures", "patch"],
  ["feat!: change the approval contract", "major"],
  ["fix: change contract\n\nBREAKING CHANGE: remove the old interface", "major"],
  ["docs: clarify setup", null],
]) {
  test(`release decision for ${message.split("\n")[0]}`, async () => {
    assert.equal((await planRelease([{ message }], "1.2.3"))?.type ?? null, expected);
  });
}

test("squash title validation accepts scoped breaking changes and rejects ordinary prose", () => {
  for (const title of ["feat: add setup", "fix(auth)!: change contract", "chore(deps): update action"]) {
    execFileSync("bash", ["Tools/check-commit.sh", title]);
  }
  assert.equal(spawnSync("bash", ["Tools/check-commit.sh", "Update installer"]).status, 1);
});

test("the first feature release starts at 0.1.0, then fixes increment the patch", async () => {
  assert.equal((await planRelease([{ message: "feat: add setup" }])).version, "0.1.0");
  assert.equal((await planRelease([{ message: "fix: repair setup" }], "0.1.0")).version, "0.1.1");
  assert.equal((await planRelease([{ message: "feat!: new interface" }], "0.1.0")).version, "1.0.0");
});
