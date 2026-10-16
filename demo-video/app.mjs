// Shared Playwright setup for the demo recording: headed Chrome (so
// reCAPTCHA Enterprise and App Check pass), a phone viewport, and Flutter's
// semantics tree switched on so elements can be found by role and text.

import { chromium } from 'playwright';
import path from 'node:path';

export const SITE = 'https://contextlens-tekken.web.app/';
export const OUT = path.resolve('out');

export async function openApp({ record = false } = {}) {
  const context = await chromium.launchPersistentContext(path.join(OUT, 'profile'), {
    channel: 'chrome',
    headless: false,
    viewport: { width: 412, height: 915 },
    deviceScaleFactor: 2,
    isMobile: false,
    hasTouch: false,
    ...(record ? { recordVideo: { dir: path.join(OUT, 'rec'), size: { width: 824, height: 1830 } } } : {}),
  });
  const page = context.pages()[0] ?? (await context.newPage());
  const t0 = Date.now();
  await page.goto(SITE, { waitUntil: 'load' });
  await enableSemantics(page);
  return { context, page, t0 };
}

export async function enableSemantics(page) {
  const placeholder = page.locator('flt-semantics-placeholder');
  await placeholder.waitFor({ state: 'attached', timeout: 60000 });
  await placeholder.evaluate((el) => el.click());
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 20000 });
}

/// Anonymous sign-in is done once Home has loaded its history.
export async function waitForHome(page) {
  await page.getByRole('button', { name: 'Check a video' }).waitFor({ timeout: 60000 });
  await page.waitForTimeout(2500);
}

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
