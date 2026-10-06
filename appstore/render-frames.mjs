#!/usr/bin/env node
/**
 * Frame FlatFile App Store screenshots using FlatNote's frame.html / mac-frame.html.
 * Copy: ASC v3 (2026-10-05) + Kate lock Fancy look for iPhone shot 1.
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
  const hasImg = await page.locator('img').count();
  if (hasImg) {
    await page.waitForSelector('img', { state: 'visible' });
    await page.locator('img').evaluate(img => img.complete || new Promise(r => { img.onload = r; }));
    await page.waitForTimeout(200);
  } else {
    await page.waitForTimeout(100);
  }
  await page.screenshot({ path: outPath, type: 'png' });
  console.log('wrote', outPath);
}

async function main() {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  // --- iPhone 6.9 — Kate lock Oct 5 (Fancy look shot 1) + v3 ---
  const iphone = [
    { file: 'iphone-1-grid.png', img: 'iphone-6.9/grid.png', h1: 'Fancy look. Forever file.', sub: 'Easy on the eyes, saved as a .csv any computer can read.' },
    { file: 'iphone-2-templates.png', img: 'iphone-6.9/templates.png', h1: 'Start simple.', sub: 'Stuff I own, Budget, People, a few plain columns and you\'re going.' },
    { file: 'iphone-3-folder.png', img: 'iphone-6.9/folder.png', h1: 'Your folder, your files.', sub: 'Your CSVs sit where you put them, never locked inside an app.' },
    { file: 'iphone-4-inspect.png', img: 'iphone-6.9/inspect.png', h1: 'You stay in charge.', sub: 'Inspect shows odd cells, you decide what to change.' },
    { file: 'iphone-5-paperclip.png', img: 'iphone-6.9/paperclip.png', h1: 'Tables next to notes.', sub: 'Same name, .csv and .md side by side, tap the paperclip.' },
  ];
  for (const s of iphone) {
    const imgPath = pathToFileURL(path.join(RAW, s.img)).href;
    await shot(page, 'frame.html', {
      kind: 'shot', w: 1320, h: 2868, h1: s.h1, sub: s.sub, img: imgPath,
    }, path.join(OUT.iphone, s.file), 1320, 2868);
  }
  await shot(page, 'frame.html', {
    kind: 'thesis', w: 1320, h: 2868,
    h1: 'No fee, no lock-in.',
    sub: 'No account, no monthly charge, no strange file types. Plain .csv, always.',
    footer: FOOTER,
  }, path.join(OUT.iphone, 'iphone-6-thesis.png'), 1320, 2868);

  // --- iPad 13 — v3 hero + matching beats ---
  const ipad = [
    { file: 'ipad-1-grid.png', img: 'ipad-13/grid.png', h1: 'Looks great. Lasts forever.', sub: 'Room to see the whole table, still a plain .csv underneath.' },
    { file: 'ipad-2-templates.png', img: 'ipad-13/templates.png', h1: 'Start simple.', sub: 'Stuff I own, Budget, People, a few plain columns and you\'re going.' },
    { file: 'ipad-3-inspect.png', img: 'ipad-13/inspect.png', h1: 'You stay in charge.', sub: 'Inspect shows odd cells, you decide what to change.' },
    { file: 'ipad-4-paperclip.png', img: 'ipad-13/paperclip.png', h1: 'Tables next to notes.', sub: 'Same name, .csv and .md side by side, tap the paperclip.' },
  ];
  for (const s of ipad) {
    const imgPath = pathToFileURL(path.join(RAW, s.img)).href;
    await shot(page, 'frame.html', {
      kind: 'shot', w: 2064, h: 2752, h1: s.h1, sub: s.sub, img: imgPath,
      radius: 80,
    }, path.join(OUT.ipad, s.file), 2064, 2752);
  }

  // --- Mac 2880x1800 — v3 beautiful grid ---
  const mac = [
    { file: 'mac-1-grid.png', img: 'mac/grid.png', h1: 'Looks great. Lasts forever.', sub: 'A beautiful grid for real CSV files.' },
    { file: 'mac-2-raw.png', img: 'mac/raw.png', h1: 'A beautiful grid for real CSV files.', sub: 'Open it, edit it, save it, it stays a .csv forever.' },
    { file: 'mac-3-inspect.png', img: 'mac/inspect.png', h1: 'You stay in charge.', sub: 'Inspect shows odd cells, you decide what to change.' },
  ];
  for (const s of mac) {
    const imgPath = pathToFileURL(path.join(RAW, s.img)).href;
    await shot(page, 'mac-frame.html', {
      w: 2880, h: 1800, h1: s.h1, sub: s.sub, img: imgPath, shotw: 2200,
    }, path.join(OUT.mac, s.file), 2880, 1800);
  }

  await browser.close();
  console.log('All FlatFile frames done (v3 + Fancy look).');
}

main().catch(e => { console.error(e); process.exit(1); });
