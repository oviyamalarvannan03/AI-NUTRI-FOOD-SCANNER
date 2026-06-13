const { Builder, By, until } = require('selenium-webdriver');
const chrome = require('selenium-webdriver/chrome');
const assert = require('assert');

describe('NutriAI Web E2E Login Test', function () {
  this.timeout(30000); // 30 seconds timeout
  let driver;

  before(async function () {
    let options = new chrome.Options();
    options.addArguments('--headless'); // run headless in CI
    options.addArguments('--no-sandbox');
    options.addArguments('--disable-dev-shm-usage');
    
    driver = await new Builder()
      .forBrowser('chrome')
      .setChromeOptions(options)
      .build();
  });

  after(async function () {
    if (driver) {
      await driver.quit();
    }
  });

  it('should successfully load login screen and handle inputs', async function () {
    // Navigate to local or production site (in CI we can load index.html or target the live app URL)
    await driver.get('https://nutri-ai-scanner.web.app');

    // Wait for splash screen / onboarding / login elements
    await driver.wait(until.elementLocated(By.id('loginEmail')), 15000);

    const emailInput = await driver.findElement(By.id('loginEmail'));
    const passwordInput = await driver.findElement(By.id('loginPassword'));
    const loginBtn = await driver.findElement(By.id('loginBtn'));

    assert(emailInput && passwordInput && loginBtn, 'Form fields should be present');

    // Input dummy credentials
    await emailInput.sendKeys('test@example.com');
    await passwordInput.sendKeys('password123');

    // Field values should match inputs
    const emailVal = await emailInput.getAttribute('value');
    assert.strictEqual(emailVal, 'test@example.com');
  });
});
