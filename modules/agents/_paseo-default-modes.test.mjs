import assert from "node:assert/strict";
import { createRequire } from "node:module";

const root = process.argv[2];
const require = createRequire(root + "/package.json");
const { AGENT_PROVIDER_DEFINITIONS } = require("@getpaseo/protocol/provider-manifest");
const { ProviderSnapshotManager } = await import(
  root + "/packages/server/dist/server/server/agent/provider-snapshot-manager.js"
);
const defaults = { codex: "full-access", claude: "bypassPermissions", omp: "full", pi: null };
const providers = AGENT_PROVIDER_DEFINITIONS.filter(({ id }) => Object.hasOwn(defaults, id));
const manager = new ProviderSnapshotManager({
  logger: require("pino")({ level: "silent" }),
  providerOverrides: { omp: { enabled: true } },
  extraClients: Object.fromEntries(
    providers.map(({ id, modes, defaultModeId }) => [
      id,
      {
        provider: id,
        isAvailable: async () => true,
        fetchCatalog: async () => ({ modes, models: [], defaultModeId }),
      },
    ]),
  ),
});

const cwd = process.cwd();
const mode = async (provider, requestedMode, parent) =>
  (await manager.resolveCreateConfig({ cwd, provider, requestedMode, parent, unattended: false })).modeId;

try {
  const initial = manager.getSnapshot(cwd).records;
  for (const [provider, expected] of Object.entries(defaults)) {
    assert.equal(initial.find(({ entry }) => entry.provider === provider)?.entry.defaultModeId, expected);
    const entry = await manager.getProvider({ cwd, provider, wait: true });
    assert.equal(entry.defaultModeId, expected);
    assert.equal(await mode(provider), expected ?? undefined);
  }
  const parent = { provider: "claude", currentModeId: "bypassPermissions", config: {} };
  assert.equal(await mode("codex", undefined, parent), "full-access");
  assert.equal(await mode("claude", "plan", parent), "plan");
  parent.currentModeId = "plan";
  assert.equal(await mode("claude", undefined, parent), "plan");
  await assert.rejects(mode("codex", undefined, parent), /cannot inherit mode/);
} finally {
  manager.destroy();
}
