import { chromium } from 'playwright-core';
import fs from 'fs';

(async () => {
  const browser = await chromium.launch({ executablePath: 'C:\Users\SAMEER\AppData\Local\ms-playwright\chromium-1009\chrome-win64\chrome.exe', headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  const errors = [];
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()); });
  page.on('pageerror', e => errors.push(e.message));
  const path = fs.realpathSync('./index.html');
  await page.goto('file://' + path, { waitUntil: 'networkidle', timeout: 60000 });
  await page.waitForTimeout(700);

  const routes = ['overview','data','quality','benford','review','peers','validation','export'];
  const title = await page.innerText('title');
  const bodyChars = await page.evaluate(() => document.body.innerText.length);
  const activeSrc = await page.textContent('#activeSource');
  const traySel = await page.$eval('#tray', el => el.querySelectorAll('.tool.is-active').length);
  const qs = await page.evaluate(() => {
    const nav = document.getElementById('kit');
    const links = nav.querySelectorAll('[data-route]');
    return Array.from(links).map(l => ({href: location.toString().replace(/[?#].*$/,''), route: l.dataset.route}));
  });
  console.log('=== head != loaded.html');
  console.log('page title:', title);
  console.log('body chars:', bodyChars);
  console.log('active source:', activeSrc.replace(/\u00a0/g,' ').trim().slice(0, 120));
  console.log('active tool:', traySel);
  console.log('nav routes:', qs.map(r => r.route));

  // navigate each route
  for (const r of routes) {
    await page.goto('file://' + path + '#' + r, { waitUntil: 'networkidle', timeout: 40000 });
    await page.waitForTimeout(500);
    const h2 = await page.textContent('header.page-head h2').catch(() => '');
    const navTool = await page.$eval('#tray', el => el.querySelectorAll('.tool.is-active span.tool-name').length);
    const errsHere = errors.slice(errors.length - 2).join(' || ');
    console.log('route', r, 'h2:', h2 ? h2.trim().slice(0, 80) : 'none', 'active-tools:', navTool, 'errs:', errsHere || '-');
  }
  // test staging flow
  await page.goto('file://' + path + '#data', { waitUntil: 'networkidle' });
  const ok = await page.$eval('#dropzone', el => el.isVisible());
  // test drawer open and dataset selection
  await page.click('[data-stage="usaspending"]');
  await page.waitForSelector('.drawer.is-open', { timeout: 3000 });
  const nam = await page.$eval('#drawerTitle', el => el.textContent.trim());
  console.log('drawer opened dataset preview:', nam);
  await page.click('#drawerClose');
  await page.waitForTimeout(200);
  const drawerClosed = await page.$eval('#drawer', el => !el.classList.contains('is-open'));
  console.log('drawer closed:', drawerClosed);
  // test keyboard
  await page.keyboard.press('d');
  await page.waitForTimeout(200);
  const curRoute = await page.evaluate(() => location.hash.replace(/^#\/?/, '').split('/')[0]);
  console.log('keyboard D -> route:', curRoute);
  await page.keyboard.press('1');
  await page.waitForTimeout(200);
  const cur1 = await page.evaluate(() => location.hash.replace(/^#\/?/, '').split('/')[0]);
  console.log('keyboard 1 -> route:', cur1);
  await page.close();
  await browser.close();
  console.log('=== ERRORS ===');
  for (const e of errors) console.log(e);
  console.log('TOTAL ERRORS:', errors.length);
  console.log('PASS:', errors.length === 0 ? 'console clean' : 'check errors above');
})().catch(e => { console.error('CRASH:', e); process.exit(1); });
