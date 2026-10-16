// Records the live app for the demo video in one headed Chrome session and
// logs when each clip starts and ends (out/rec/marks.json). The edit cuts
// clips a to h from the recording by those marks.
//
// Three real checks: GlucoLeaf, the same video with the caption fixed (a
// re-check against the first), and the vitamin D borrowed-clip sample.

import fs from 'node:fs';
import path from 'node:path';
import { OUT, openApp, waitForHome } from './app.mjs';

const { context, page, t0 } = await openApp({ record: true });
const marks = {};
const log = [];
const now = () => (Date.now() - t0) / 1000;
const mark = (name) => { marks[name] = now(); console.log(name, marks[name].toFixed(1)); };
const save = () => fs.writeFileSync(path.join(OUT, 'rec', 'marks.json'), JSON.stringify({ marks, log }, null, 2));
const hold = (ms) => page.waitForTimeout(ms);
const snap = async (name) =>
  fs.writeFileSync(path.join(OUT, 'rec', `${name}.aria.txt`), await page.locator('body').ariaSnapshot());

/** Slow scroll: small wheel steps so the recording reads as a smooth pan. */
async function scroll(dy, ms) {
  // Wheel events go to whatever is under the pointer: keep it on the list.
  await page.mouse.move(206, 620);
  const steps = Math.max(1, Math.round(ms / 50));
  for (let i = 0; i < steps; i++) {
    await page.mouse.wheel(0, dy / steps);
    await page.waitForTimeout(50);
  }
}

/** The first button whose accessible name matches `re`. */
async function button(re) {
  for (const b of await page.getByRole('button').all()) {
    const name = (await b.getAttribute('aria-label')) || (await b.textContent()) || '';
    if (re.test(name)) return b;
  }
  return null;
}

/** A flag card (not the seek bar's tick for it): its name carries the
 * category and severity, the ticks read "... flag at 0:10". */
async function card(re) {
  const ok = (name) => re.test(name) && /·|needs a human look/.test(name) && !/flag at \d/.test(name);
  for (const b of await page.locator('flt-semantics[role="button"]').all()) {
    if (ok((await b.getAttribute('aria-label')) || (await b.textContent()) || '')) return b;
  }
  // An expanded card is a group named by its own label (never by the text
  // of everything inside it, which would match the whole list).
  for (const b of await page.locator('flt-semantics[role="group"][aria-label]').all()) {
    if (ok((await b.getAttribute('aria-label')) || '')) return b;
  }
  return null;
}

async function tryStep(name, fn) {
  try {
    await fn();
  } catch (error) {
    log.push(`${name}: ${String(error).slice(0, 200)}`);
    console.log('SKIP', name, String(error).slice(0, 200));
  }
}

async function chooseSample(title) {
  await page.getByRole('button', { name: 'Try a sample video' }).click();
  const tile = page.getByRole('button', { name: new RegExp(`^${title.replace(/[.*+?^${}()|[\]\\']/g, '\\$&')}\\.`) });
  await tile.waitFor({ timeout: 60000 });
  await hold(1500);
  await tile.click({ position: { x: 60, y: 40 } });
  await page.getByRole('button', { name: 'Run check' }).waitFor({ timeout: 30000 });
}

/** Waits for the report: its "Fix and re-upload" button appears. */
async function waitForReport() {
  await page.getByRole('button', { name: /Fix and re-upload/ }).waitFor({ timeout: 300000 });
}

/** Scrolls (visibly) until the element `find()` returns is on screen above
 * the bottom bar, then taps it with a real mouse click. Flutter rebuilds its
 * semantics nodes while scrolling, so the element is looked up each time. */
async function tap(find, { dx = 60, dy = 22, top = 150 } = {}) {
  for (let i = 0; i < 25; i++) {
    const el = await find();
    const box = el && (await el.boundingBox({ timeout: 3000 }).catch(() => null));
    if (!box) {
      await scroll(600, 400);
      continue;
    }
    const y = box.y + Math.min(dy, box.height / 2);
    if (process.env.DEBUG_TAP) console.log("tap y", Math.round(y), Math.round(box.height));
    if (y > top && y < 760) {
      await hold(500);
      await page.mouse.click(box.x + dx, y);
      return;
    }
    // Flutter moves the list about a third of the wheel delta.
    await scroll(Math.max(-900, Math.min(900, (y - 420) * 2)), 450);
  }
  throw new Error('could not bring it on screen');
}

async function openFlag(re, detailScroll, endHold = 1500) {
  if (!(await card(re))) {
    // Cards below the fold aren't built yet: scroll until one appears.
    for (let i = 0; i < 10 && !(await card(re)); i++) await scroll(900, 500);
  }
  const found = await card(re);
  if (!found) throw new Error(`no flag ${re}`);
  if ((await found.getAttribute('role')) === 'button') {
    await tap(() => card(re));
    await hold(1500);
  }
  if (!(await button(/^Details$/))) {
    await snap('no_details');
    await page.screenshot({ path: path.join(OUT, 'rec', 'no_details.png') });
    throw new Error('no Details button');
  }
  await tap(() => button(/^Details$/), { dx: 30, dy: 15 });
  await hold(2000);
  await snap(`detail_${re.source.replace(/\W+/g, '_').slice(0, 30)}`);
  await scroll(detailScroll, 7000);
  await hold(endHold);
  await tap(() => button(/^Back/), { dx: 20, dy: 20, top: 0 });
  await hold(1500);
}

const mode = process.argv[2] ?? 'main';

/** Back to Home through the app (a reload would turn semantics off). */
async function home() {
  for (let i = 0; i < 4; i++) {
    if (await page.getByRole('button', { name: 'Check a video' }).isVisible().catch(() => false)) return;
    await page.getByRole('button', { name: /^Back/ }).first().click();
    await hold(1500);
  }
}

async function main() {
  await waitForHome(page);

  // a) Home.
  mark('a_start');
  await hold(6000);
  mark('a_end');

  // b) Try a sample, the declaration, Run check.
  mark('b_start');
  await hold(1000);
  await chooseSample('Gifted supplement with health claims');
  await hold(2500);
  await page.getByRole('switch', { name: /Paid or collab/ }).hover();
  await hold(1500);
  await scroll(350, 2500);
  await page.getByRole('button', { name: 'Health', exact: true }).hover();
  await hold(2500);
  await page.getByRole('button', { name: 'Run check' }).click();
  mark('b_end');

  // c) Upload and live progress until the report.
  mark('c_start');
  await waitForReport();
  mark('c_end');
  await hold(1500);
  const firstReport = page.url();
  await snap('report1');

  // d) The summary, then the flag list.
  mark('d_start');
  await hold(5000);
  await scroll(900, 7000);
  await hold(1000);
  await scroll(-900, 3000);
  await hold(1000);
  mark('d_end');

  // e) The disclosure flag.
  mark('e_start');
  await tryStep('disclosure', () => openFlag(/Ad label is buried|Ad label|No Ad label/, 900));
  mark('e_end');

  // f) A claims flag, a fact check, and an uncertain one if there is one.
  mark('f_claims_start');
  await tryStep('claims', () => openFlag(/diabetes|blood sugar|Claim/i, 900));
  mark('f_claims_end');
  mark('f_fact_start');
  await tryStep('factcheck', () => openFlag(/[Vv]itamin C|cold/, 900));
  mark('f_fact_end');
  await snap('report1_after');
  mark('f_uncertain_start');
  await tryStep('uncertain', async () => {
    await scroll(2500, 4000);
    await hold(1500);
    await snap('report1_bottom');
    await openFlag(/[Uu]ncertain|[Ii]nsufficient|lacks evidence/, 600);
  });
  mark('f_uncertain_end');
  save();

  // h) Fix and re-upload: the same sample with the caption fixed.
  await scroll(-4000, 1500);
  await page.getByRole('button', { name: /Fix and re-upload/ }).click();
  await hold(2500);
  await chooseSample('Gifted supplement with health claims');
  await hold(1000);
  const caption = page.getByRole('textbox', { name: 'Caption' });
  await caption.click();
  await page.keyboard.press('Control+A');
  await page.keyboard.type('Ad: My morning routine with GlucoLeaf, gifted by the brand. Code GLUCO15 #morning #health', { delay: 25 });
  await hold(1000);
  await page.getByRole('button', { name: 'Run check' }).click();
  mark('h_run_start');
  await waitForReport();
  mark('h_run_end');
  await hold(2000);
  await snap('report2');
  mark('h_report_start');
  await hold(6000);
  mark('h_report_end');
  // Home, where the re-check card says what was resolved.
  await home();
  mark('h_home_start');
  await hold(6000);
  await snap('home_after_fix');
  mark('h_home_end');
  save();

  // g) The borrowed clip.
  await chooseSample("Clip that drops the doctor's warning");
  await hold(1500);
  await page.getByRole('button', { name: 'Run check' }).click();
  mark('g_run_start');
  await waitForReport();
  mark('g_run_end');
  await hold(1500);
  await snap('report3');
  mark('g_start');
  await hold(2500);
  await tryStep('borrowed', () => openFlag(/leaves out|condition|Clip|borrowed/i, 1400));
  mark('g_end');
  save();
  console.log('first report', firstReport);
}

// Clips f and h again from the saved reports, without a new check: Home
// with the re-check card, run 2 with "1 of 3 resolved" and its verified fact
// check, then run 1's claims flag and an uncertain fact check.
async function history() {
  await waitForHome(page);
  await snap('home_history');
  mark('h_home_start');
  await hold(6000);
  mark('h_home_end');
  const run = page.locator('flt-semantics[role="button"]').filter({ hasText: /GlucoLeaf/ }).first();
  const runCard = (await run.count()) ? run : await button(/GlucoLeaf/);
  await runCard.click({ position: { x: 120, y: 40 } });
  await page.getByRole('button', { name: /Fix and re-upload/ }).waitFor({ timeout: 60000 });
  await hold(1500);
  await snap('history_report2');
  mark('h_report_start');
  await hold(5000);
  mark('h_report_end');
  mark('f_fact_start');
  await tryStep('factcheck', () => openFlag(/Fact check\s+·/, 900));
  mark('f_fact_end');
  await scroll(-3000, 800);
  await tap(() => button(/^See run 1/), { dx: 40, dy: 15 });
  await page.getByRole('button', { name: /Fix and re-upload/ }).waitFor({ timeout: 60000 });
  await hold(1500);
  // d) Run 1's summary, then its flag list.
  mark('d_start');
  await hold(5000);
  await scroll(900, 7000);
  await hold(1000);
  await scroll(-900, 3000);
  await hold(1000);
  mark('d_end');
  // e) The disclosure flag.
  mark('e_start');
  await tryStep('disclosure', () => openFlag(/Ad label is buried/, 900));
  mark('e_end');
  await scroll(-3000, 600);
  mark('f_claims_start');
  await tryStep('claims', () => openFlag(/Claims\s+·/, 900));
  mark('f_claims_end');
  await scroll(3000, 3000);
  await hold(1000);
  await snap('history_report1_bottom');
  mark('f_uncertain_start');
  await tryStep('uncertain', () => openFlag(/Vitamin C[\s\S]*needs a human look/, 700));
  mark('f_uncertain_end');
  save();
}

// Clip g: the vitamin D sample, a real check, then its borrowed-clip flag.
async function borrowed() {
  await waitForHome(page);
  await chooseSample("Clip that drops the doctor's warning");
  await hold(1500);
  await page.getByRole('button', { name: 'Run check' }).click();
  mark('g_run_start');
  await waitForReport();
  mark('g_run_end');
  await hold(1500);
  await snap('report3');
  mark('g_start');
  await hold(2500);
  await tryStep('borrowed', () => openFlag(/leaves out/, 3200, 6000));
  mark('g_end');
  save();
}

// Clip g again from the saved report: down to the highlighted words the
// clip left out, and a long hold there.
async function borrowedHistory() {
  await waitForHome(page);
  await tap(() => button(/[Dd]octor says/), { dx: 120, dy: 40 });
  await page.getByRole('button', { name: /Fix and re-upload/ }).waitFor({ timeout: 60000 });
  await hold(1500);
  mark('g_start');
  await hold(2500);
  await tryStep('borrowed', () => openFlag(/leaves out/, 3200, 6000));
  mark('g_end');
  save();
}

try {
  await { main, history, borrowed, borrowedHistory }[mode]();
} finally {
  save();
  await context.close();
  const video = fs.readdirSync(path.join(OUT, 'rec')).filter((f) => f.endsWith('.webm'))
    .map((f) => ({ f, t: fs.statSync(path.join(OUT, 'rec', f)).mtimeMs })).sort((a, b) => b.t - a.t)[0];
  console.log('video', video?.f);
}
