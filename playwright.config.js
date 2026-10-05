const { defineConfig } = require('@playwright/test');

const port = Number(process.env.IRIS_TEST_PORT || 4173);
const rpcPort = Number(process.env.IRIS_RPC_TEST_PORT || port + 1);

module.exports = defineConfig({
  testDir: './tests/browser',
  timeout: 30_000,
  use: {
    baseURL: `http://127.0.0.1:${port}`,
    trace: 'retain-on-failure'
  },
  webServer: [{
    command: `python3 -m http.server ${port} --bind 127.0.0.1`,
    url: `http://127.0.0.1:${port}`,
    reuseExistingServer: false
  }, {
    command: `python3 examples/client/server.py ${rpcPort}`,
    url: `http://127.0.0.1:${rpcPort}`,
    reuseExistingServer: false
  }]
});
