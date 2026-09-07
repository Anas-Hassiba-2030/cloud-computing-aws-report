/**
 * Renders report.html (and slides.html) to PDF with headless Chrome.
 *
 * Chrome's `--print-to-pdf` command line flag cannot set a footer template, so
 * this drives the DevTools Protocol directly instead. That is what gives the
 * report a running footer with real page numbers while the document itself
 * still reflows automatically. Node 21+ ships a global WebSocket, so there is
 * no dependency to install.
 *
 *   node scripts/build-pdf.mjs
 *   node scripts/build-pdf.mjs report        (just the report)
 */

import { spawn } from 'node:child_process';
import { writeFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const PORT = 9222;

const CHROME_CANDIDATES = [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  process.env.LOCALAPPDATA + '/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
];

const FOOTER = (left) => `
<div style="width:100%;font-family:Cambria,Georgia,serif;font-size:8pt;color:#5a5a5a;
            padding:0 22mm;box-sizing:border-box;">
  <div style="border-top:0.5pt solid #c9c9c9;padding-top:2mm;display:flex;justify-content:space-between;">
    <span>${left}</span><span class="pageNumber"></span>
  </div>
</div>`;

const JOBS = {
  report: {
    file: 'report.html',
    out: 'Cloud-Computing-AWS-Report.pdf',
    opts: {
      paperWidth: 8.27, paperHeight: 11.69,          // A4
      marginTop: 0.83, marginBottom: 0.83,           // ~21mm, footer sits inside
      marginLeft: 0.87, marginRight: 0.87,           // ~22mm
      displayHeaderFooter: true,
      headerTemplate: '<span></span>',
      footerTemplate: FOOTER('Cloud Computing Project&nbsp;&nbsp;·&nbsp;&nbsp;Amazon Web Services'),
      printBackground: true,
      preferCSSPageSize: false,
    },
  },
  slides: {
    file: 'slides.html',
    out: 'Cloud-Computing-AWS-Slides.pdf',
    opts: {
      paperWidth: 11.69, paperHeight: 8.27,          // A4 landscape
      marginTop: 0.31, marginBottom: 0.31, marginLeft: 0.31, marginRight: 0.31,
      displayHeaderFooter: false,
      printBackground: true,
      preferCSSPageSize: false,
    },
  },
};

function findChrome() {
  const found = CHROME_CANDIDATES.find((p) => p && existsSync(p));
  if (!found) throw new Error('Chrome not found. Edit CHROME_CANDIDATES in this script.');
  return found;
}

async function waitForDevtools(tries = 60) {
  for (let i = 0; i < tries; i++) {
    try {
      const r = await fetch(`http://127.0.0.1:${PORT}/json/version`);
      if (r.ok) return (await r.json()).webSocketDebuggerUrl;
    } catch {}
    await new Promise((r) => setTimeout(r, 250));
  }
  throw new Error('Chrome DevTools endpoint never came up.');
}

/** Minimal CDP client: send(method, params) -> Promise<result>. */
function connect(url) {
  const ws = new WebSocket(url);
  const pending = new Map();
  const listeners = new Map();
  let id = 0;

  ws.addEventListener('message', (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve: ok, reject: no } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? no(new Error(msg.error.message)) : ok(msg.result);
    } else if (msg.method && listeners.has(msg.method)) {
      listeners.get(msg.method).forEach((fn) => fn(msg.params));
      listeners.delete(msg.method);
    }
  });

  const ready = new Promise((ok, no) => {
    ws.addEventListener('open', ok, { once: true });
    ws.addEventListener('error', () => no(new Error('WebSocket failed')), { once: true });
  });

  return {
    ready,
    send(method, params = {}, sessionId) {
      return new Promise((ok, no) => {
        const msgId = ++id;
        pending.set(msgId, { resolve: ok, reject: no });
        ws.send(JSON.stringify({ id: msgId, method, params, sessionId }));
      });
    },
    once(method) {
      return new Promise((ok) => {
        if (!listeners.has(method)) listeners.set(method, []);
        listeners.get(method).push(ok);
      });
    },
    close: () => ws.close(),
  };
}

const which = process.argv[2];
const jobs = which ? [JOBS[which]] : Object.values(JOBS);
if (jobs.some((j) => !j)) throw new Error(`Unknown job "${which}". Use: report | slides`);

const chrome = spawn(findChrome(), [
  '--headless=new',
  '--disable-gpu',
  `--remote-debugging-port=${PORT}`,
  '--no-first-run',
  '--user-data-dir=' + resolve(ROOT, '.chrome-pdf-profile'),
  'about:blank',
], { stdio: 'ignore' });

try {
  const client = connect(await waitForDevtools());
  await client.ready;

  for (const job of jobs) {
    const { targetId } = await client.send('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await client.send('Target.attachToTarget', { targetId, flatten: true });

    await client.send('Page.enable', {}, sessionId);
    const loaded = client.once('Page.loadEventFired');
    await client.send('Page.navigate', { url: pathToFileURL(resolve(ROOT, job.file)).href }, sessionId);
    await loaded;
    // Give web fonts and SVG layout a beat to settle before measuring pages.
    await new Promise((r) => setTimeout(r, 1200));

    const { data } = await client.send('Page.printToPDF', job.opts, sessionId);
    const out = resolve(ROOT, job.out);
    writeFileSync(out, Buffer.from(data, 'base64'));
    console.log(`${job.out}  ${(Buffer.from(data, 'base64').length / 1024).toFixed(0)} KB`);

    await client.send('Target.closeTarget', { targetId });
  }

  client.close();
} finally {
  chrome.kill();
}
