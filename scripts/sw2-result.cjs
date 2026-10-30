#!/usr/bin/env node
'use strict';
/*
 * sw2-result.cjs - write result.json for one cycle and suggest a classification.
 *
 *   node sw2-result.cjs <evidence-dir> <candidate-dir> [forced-class reason] <sdk-dir>
 *
 * The script can only judge execution, not acceptance.  It suggests:
 *   no-run             blocked before anything touched the console
 *   transport-failure  the host failed before the app was entered
 *   failed             the app returned an error status, or the host failed after entry
 *   inconclusive       the watchdog ended the run, or evidence is missing
 *   app-ok             the app ran and returned HBX_OK: a person decides pass or
 *                      partial-pass against the case's acceptance criterion
 */
const fs = require('node:fs');
const path = require('node:path');
const {execFileSync} = require('node:child_process');

const [evidence, candidate, forced, reason, sdk] = process.argv.slice(2);
const read = file => { try { return fs.readFileSync(file, 'utf8'); } catch { return ''; } };
const meta = JSON.parse(read(path.join(candidate, 'CANDIDATE.json')) || '{}');

let sdkCommit = 'unknown';
try { sdkCommit = execFileSync('git', ['-C', sdk, 'describe', '--always', '--dirty'],
  {encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore']}).trim(); }
catch { const b = read(path.join(sdk, 'BUNDLE.json')); if (b) sdkCommit = JSON.parse(b).commit + ' (bundle)'; }

const lines = read(path.join(evidence, 'session.jsonl')).split('\n').filter(Boolean)
  .map(line => { try { return JSON.parse(line); } catch { return null; } }).filter(Boolean);
const find = (level, message) => lines.filter(e => e.level === level && e.message === message);
const launched = find('stage', 'launch').length > 0;
const finished = find('info', 'app finished').pop();
const failedLaunch = find('error', 'app launch failed').pop();
const errors = lines.filter(e => e.level === 'error').map(e => e.message + (e.data && e.data.error ? ': ' + e.data.error : ''));
const appLog = find('info', 'app log').map(e => e.data && e.data.text).filter(Boolean);

const hostExit = process.env.SW2_HOST_EXIT === undefined ? null : Number(process.env.SW2_HOST_EXIT);
const timedOut = process.env.SW2_TIMED_OUT === '1';
const appStatus = finished && finished.data ? finished.data.status : (failedLaunch ? 'launch-failed' : null);

let suggested = forced || '';
let why = reason || '';
if (!suggested) {
  if (timedOut) { suggested = 'inconclusive'; why = 'watchdog stopped the host'; }
  else if (!launched) { suggested = 'transport-failure'; why = 'host never entered the app'; }
  else if (failedLaunch) { suggested = 'failed'; why = 'launch failed: ' + (failedLaunch.data && failedLaunch.data.error); }
  else if (appStatus === 0 && hostExit === 0) { suggested = 'app-ok'; why = 'app returned HBX_OK; check the acceptance criterion'; }
  else if (appStatus !== null && appStatus !== 0) { suggested = 'failed'; why = `app returned status ${appStatus}`; }
  else { suggested = 'inconclusive'; why = `host exit ${hostExit}, no app status recorded`; }
}

const sums = read(path.join(candidate, 'SHA256SUMS')).split('\n').filter(Boolean)
  .map(line => ({sha256: line.slice(0, 64), file: line.slice(66)}));
const result = {
  format: 'sw2-cycle-result/1',
  at: new Date().toISOString(),
  candidate: {path: candidate, ...meta},
  files: sums,
  sdk: {path: sdk, commit: sdkCommit},
  host: {exit: hostExit, timedOut, elapsedSeconds: Number(process.env.SW2_ELAPSED || 0)},
  app: {status: appStatus, frames: finished && finished.data ? finished.data.frames : null,
    log: appLog.join('\n').slice(-4000)},
  errors: errors.slice(-20),
  suggested,
  why,
  classification: null,
  milestone: `- ${new Date().toISOString().slice(0, 10)} | G? | ${meta.sourceCommit || '?'} | ${meta.id || '?'}@${meta.version || '?'} | ` +
    `${suggested}: ${why} | ${path.relative(process.cwd(), evidence) || evidence} | next?`
};
fs.writeFileSync(path.join(evidence, 'result.json'), JSON.stringify(result, null, 2) + '\n');
