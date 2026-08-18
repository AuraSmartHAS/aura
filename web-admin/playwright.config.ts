import { defineConfig, devices } from '@playwright/test';

/**
 * E2E do painel contra a API real — nada de mock: se o backend quebrar o contrato,
 * este teste cai. Reaproveita servidores já no ar; senão, sobe os dois.
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  timeout: 60_000,
  expect: { timeout: 15_000 },
  reporter: [['list']],
  use: {
    baseURL: 'http://localhost:4200',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
  webServer: [
    {
      command: 'JAVA_HOME=${JAVA_HOME:-/opt/homebrew/opt/openjdk@21} ./mvnw -q spring-boot:run',
      cwd: '../backend-spring',
      url: 'http://localhost:8080/api/v1/health',
      reuseExistingServer: true,
      timeout: 180_000,
    },
    {
      command: 'npm start',
      url: 'http://localhost:4200',
      reuseExistingServer: true,
      timeout: 120_000,
    },
  ],
});
