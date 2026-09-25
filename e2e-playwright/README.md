# Deluzex ERP - Playwright Web E2E Testing

This directory contains browser end-to-end automation tests for the Deluzex ERP Flutter Web application.

## Prerequisites
1. Ensure the Flutter Web app is running:
   ```bash
   cd frontend
   flutter run -d web-server --web-port 8080
   ```
2. Install Playwright dependencies:
   ```bash
   cd e2e-playwright
   npm install
   npx playwright install chromium
   ```

## Running Tests
- **Headless mode (CI/CLI)**:
  ```bash
  npm test
  ```
- **Headed mode (watch browser click & type)**:
  ```bash
  npm run test:headed
  ```
- **Interactive UI Mode**:
  ```bash
  npm run test:ui
  ```
