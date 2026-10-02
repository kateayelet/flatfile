#!/usr/bin/env node
/**
 * Frame FlatFile App Store screenshots using FlatNote's frame.html / mac-frame.html.
 * Usage: node render-frames.mjs
 */
import { chromium } from 'playwright';
import path from 'path';
import fs from 'fs';
import { fileURLToPath, pathToFileURL } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = __dirname;
const RAW = path.join(ROOT, 'screenshots', 'raw');
const OUT = {
  iphone: path.join(ROOT, 'screenshots', 'iphone-6.9'),
  ipad: path.join(ROOT, 'screenshots', 'ipad-13'),
  mac: path.join(ROOT, 'screenshots', 'mac'),
};
for (const d of Object.values(OUT)) fs.mkdirSync(d, { recursive: true });

const FOOTER = 'Made for Mom by Kate Benediktsson';

function q(obj) {
  return Object.entries(obj)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(String(v))}`)
    .join('&');
}

async function shot(page, htmlFile, params, outPath, w, h) {
  const url = pathToFileURL(path.join(ROOT, htmlFile)).href + '?' + q(params);
  await page.setViewportSize({ width: w, height: h });
  await page.goto(url, { waitUntil: 'networkidle' });
  // wait for img if present
  const hasImg = await page.locator('img').count();
  if (hasImg) {
    await page.waitForSelector('img', { state: 'visible' });
    await page.locator('img').evaluate(img => img.complete || new Promise(r => { img.onload = r; }));
    await page.waitForTimeout(200);
  } else {
    await page.waitForTimeout(100);
  }
  await page.screenshot({ path: outPath, type: 'png' });
  // strip alpha by redrawing on opaque bg via canvas? ASC wants no alpha.
  // Playwright PNG may have alpha on edges; flatten with a second pass using page bg.
  console.log('wrote', outPath);
}

async function main() {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  // --- iPhone 6.9 ---
  const iphone = [
    { file: 'iphone-1-grid.png', img: 'iphone-6.9/grid.png', h1: 'The grid is the .csv.', sub: 'Plain files in a folder you choose.' },
    { file: 'iphone-2-templates.png', img: 'iphone-6.9/templates.png', h1: 'Start from something human.', sub: 'Blank, People, Budget, Stuff I own, To-do, Notes.' },
    { file: 'iphone-3-folder.png', img: 'iphone-6.9/folder.png', h1: 'Your folder. Your files.', sub: 'Open a directory of CSVs — no app vault.' },
    { file: 'iphone-4-inspect.png', img: 'iphone-6.9/inspect.png', h1: 'Never guesses your data.', sub: 'Inspect flags issues. It never auto-fixes.' },
    { file: 'iphone-5-paperclip.png', img: 'iphone-6.9/paperclip.png', h1: 'Tables next to notes.', sub: 'Same name, .csv + .md — tap the paperclip.' },
  ];
  for (const s of iphone) {
    const imgPath = pathToFileURL(path.join(RAW, s.img)).href;
    await shot(page, 'frame.html', {
      kind: 'shot', w: 1320, h: 2868, h1: s.h1, sub: s.sub, img: imgPath,
    }, path.join(OUT.iphone, s.file), 1320, 2868);
  }
  await shot(page, 'frame.html', {
    kind: 'thesis', w: 1320, h: 2868,
    h1: 'No account needed.',
    sub: 'There is no account, because there is nothing an account would do for you. No ads, no tracking, no analytics. Your tables are ordinary CSV files.',
    footer: FOOTER,
  }, path.join(OUT.iphone, 'iphone-6-thesis.png'), 1320, 2868);

  // --- iPad 13 ---
  const ipad = [
    { file: 'ipad-1-grid.png', img: 'ipad-13/grid.png', h1: 'The grid is the .csv.', sub: 'Same files on the bigger canvas.' },
    { file: 'ipad-2-templates.png', img: 'ipad-13/templates.png', h1: 'Start from something human.', sub: 'Six plain templates.' },
    { file: 'ipad-3-inspect.png', img: 'ipad-13/inspect.png', h1: 'Never guesses your data.', sub: 'Findings stay visible over the table.' },
    { file: 'ipad-4-paperclip.png', img: 'ipad-13/paperclip.png', h1: 'Tables next to notes.', sub: 'FlatFile + FlatNote, same folder.' },
  ];
  for (const s of ipad) {
    const imgPath = pathToFileURL(path.join(RAW, s.img)).href;
    await shot(page, 'frame.html', {
      kind: 'shot', w: 2064, h: 2752, h1: s.h1, sub: s.sub, img: imgPath,
      // iPad bezel slightly less rounded
      radius: 80,
    }, path.join(OUT.ipad, s.file), 2064, 2752);
  }

  // --- Mac 2880x1800 ---
  const mac = [
    { file: 'mac-1-grid.png', img: 'mac/grid.png', h1: 'The grid is the .csv.', sub: 'Sidebar, table, your folder.' },
    { file: 'mac-2-raw.png', img: 'mac/raw.png', h1: 'See the file itself.', sub: 'Table and raw CSV, same truth.' },
    { file: 'mac-3-inspect.png', img: 'mac/inspect.png', h1: 'Never guesses your data.', sub: 'Inspect on the desktop.' },
  ];
  for (const s of mac) {
    const imgPath = pathToFileURL(path.join(RAW, s.img)).href;
    await shot(page, 'mac-frame.html', {
      w: 2880, h: 1800, h1: s.h1, sub: s.sub, img: imgPath, shotw: 2200,
    }, path.join(OUT.mac, s.file), 2880, 1800);
  }

  await browser.close();
  console.log('All FlatFile frames done.');
}

main().catch(e => { console.error(e); process.exit(1); });
