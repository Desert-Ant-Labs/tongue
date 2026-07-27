import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

import { UsageClient } from "../dist/usage.js";
import { Tongue } from "../dist/index.js";

// Replays the shared turnstile contract. The Kotlin port replays the identical
// file against its own hand-ported client; the Swift SDK uses desert-ant-core's
// client directly, which is where this behaviour comes from. See docs/USAGE.md.
const here = dirname(fileURLToPath(import.meta.url));
const vectors = JSON.parse(readFileSync(join(here, "usage_vectors.json"), "utf8"));

test("turnstile matches the shared contract", () => {
  for (const c of vectors.cases) {
    let state = { lastActiveAt: c.stateLastActiveAt, carryCallCount: c.stateCarry };
    let now = 0;
    const sends = [];

    const client = new UsageClient({
      deviceId: "device-under-test",
      platform: "test",
      version: "0.0.0",
      windowMs: vectors.windowMs,
      now: () => now,
      loadState: () => state,
      saveState: (next) => {
        state = next;
      },
      send: (body) => sends.push(body),
    });

    c.stepKinds.forEach((kind, i) => {
      now = c.stepAt[i];
      if (kind === "start") client.start();
      else if (kind === "flush") client.flush();
      else if (kind === "record") client.recordCall(c.stepN[i]);
      else throw new Error(`unknown step ${kind}`);
    });

    assert.equal(sends.length, c.sendCounts.length, `${c.name}: send count`);
    c.sendCounts.forEach((expected, i) => {
      const event = sends[i].events[0];
      assert.equal(event.name, "load", `${c.name}: event name`);
      assert.equal(event.deviceId, "device-under-test", `${c.name}: deviceId`);
      assert.equal(event.callCount ?? -1, expected, `${c.name}: callCount[${i}]`);
    });
    assert.equal(state.lastActiveAt, c.finalLastActiveAt, `${c.name}: final lastActiveAt`);
    assert.equal(state.carryCallCount, c.finalCarry, `${c.name}: final carry`);
  }
});

test("detection still works with reporting switched off", async () => {
  // The suite runs with DAL_USAGE_DISABLED=1, so no client is wired up at all.
  const tongue = await Tongue.load();
  assert.equal(tongue.detect("kann ich das haben").language, "de");
});
