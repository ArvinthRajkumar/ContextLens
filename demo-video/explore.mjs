// Prints the accessibility tree of Home, the sample gallery and New check,
// without running a check, so record.mjs can use real names.
import { openApp, waitForHome } from './app.mjs';
import fs from 'node:fs';

const { context, page } = await openApp();
const api = [];
page.on('response', (r) => { if (r.url().includes('run.app')) api.push(`${r.status()} ${new URL(r.url()).pathname}`); });
await waitForHome(page);
const dump = {};
await page.getByRole('button', { name: 'Try a sample video' }).click();
await page.getByText('Gifted supplement with health claims').waitFor({ timeout: 60000 });
await page.waitForTimeout(1500);
dump.sheet = await page.locator('body').ariaSnapshot();
await page.getByRole('button', { name: /^Gifted supplement with health claims\./ }).click({ position: { x: 60, y: 40 } });
await page.waitForTimeout(4000);
dump.compose = await page.locator('body').ariaSnapshot();
await page.screenshot({ path: 'out/explore_compose.png' });
await page.mouse.wheel(0, 600);
await page.waitForTimeout(1500);
dump.compose2 = await page.locator('body').ariaSnapshot();
dump.api = api;
fs.writeFileSync('out/explore.json', JSON.stringify(dump, null, 2));
await context.close();
console.log('ok');
