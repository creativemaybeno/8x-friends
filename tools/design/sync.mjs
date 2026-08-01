#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// design/sync — deterministic helper for mirroring a Claude Design project
// into design/files/ and back.
//
// Why this exists
// ---------------
// The Claude Design MCP server has no local-file transport: `read_file` returns
// entity-escaped text and `write_files` only accepts inline `data`. That means
// bytes necessarily travel *through the agent* on every transfer, which is both
// expensive and the one place a mirror can silently corrupt.
//
// So the agent is only ever asked to do the one thing it cannot avoid — carry
// the payload — and every decision and every check around it lives here:
//
//   * plan    — diff local vs. remote vs. last-synced state; say what to move
//   * decode  — un-escape a staged payload without the agent transforming it
//   * verify  — assert decoded byte length equals the size the remote reported
//   * record  — commit a path to sync state only after it verified
//
// Zero dependencies, Node >= 18.
// ─────────────────────────────────────────────────────────────────────────────

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(fileURLToPath(import.meta.url), '../../..');
const CONFIG_PATH = path.join(ROOT, 'design', 'sync.json');
const TARGET_PATH = path.join(ROOT, 'design', 'target.local.json');
const STATE_DIR = path.join(ROOT, 'design', '.sync');
const STAGING_DIR = path.join(ROOT, 'design', '.staging');

// ── config ───────────────────────────────────────────────────────────────────

function loadConfig() {
  if (!fs.existsSync(CONFIG_PATH)) die(`missing ${rel(CONFIG_PATH)}`);
  const cfg = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  cfg.mirrorDir = path.join(ROOT, cfg.mirror ?? 'design/files');
  cfg.exclude ??= [];
  cfg.regenerate ??= [];
  cfg.projects ??= {};
  return cfg;
}

/**
 * Which Claude Design project does *this machine* sync with? Resolution order:
 *   1. $CLAUDE_DESIGN_PROJECT_ID          — explicit override, CI-friendly
 *   2. design/target.local.json           — gitignored per-user pin
 *   3. projects[*].git === git user.name  — zero-config for the usual case
 *   4. exactly one project configured     — solo repo
 */
function resolveTarget(cfg, explicitHandle) {
  const entries = Object.entries(cfg.projects);

  if (explicitHandle) {
    const found = cfg.projects[explicitHandle];
    if (!found) die(`unknown handle "${explicitHandle}" — known: ${entries.map(([h]) => h).join(', ') || '(none)'}`);
    if (!found.projectId) die(`handle "${explicitHandle}" has no projectId yet — run /design:bootstrap to create that person's project first`);
    return { handle: explicitHandle, ...found, via: 'argument' };
  }

  const envId = process.env.CLAUDE_DESIGN_PROJECT_ID;
  if (envId) {
    const hit = entries.find(([, p]) => p.projectId === envId);
    return hit
      ? { handle: hit[0], ...hit[1], via: 'CLAUDE_DESIGN_PROJECT_ID' }
      : { handle: '(env)', projectId: envId, via: 'CLAUDE_DESIGN_PROJECT_ID' };
  }

  if (fs.existsSync(TARGET_PATH)) {
    const { handle } = JSON.parse(fs.readFileSync(TARGET_PATH, 'utf8'));
    const found = cfg.projects[handle];
    if (!found) die(`${rel(TARGET_PATH)} names handle "${handle}", which is not in ${rel(CONFIG_PATH)}`);
    return { handle, ...found, via: rel(TARGET_PATH) };
  }

  let gitUser = '';
  try {
    gitUser = execFileSync('git', ['config', 'user.name'], { cwd: ROOT, encoding: 'utf8' }).trim();
  } catch { /* not fatal */ }
  const byGit = entries.filter(([, p]) => p.git && p.git === gitUser);
  if (byGit.length === 1) return { handle: byGit[0][0], ...byGit[0][1], via: `git user.name "${gitUser}"` };

  const unclaimed = entries.filter(([, p]) => p.projectId);
  if (unclaimed.length === 1) return { handle: unclaimed[0][0], ...unclaimed[0][1], via: 'only configured project' };

  die(
    'cannot tell which Claude Design project to sync with.\n' +
    `  Configured: ${entries.map(([h, p]) => `${h}${p.projectId ? '' : ' (no projectId)'}`).join(', ') || '(none)'}\n` +
    `  Fix: write ${rel(TARGET_PATH)} as {"handle": "<one of the above>"}, or run /design:bootstrap.`,
  );
}

// ── mirror + state ───────────────────────────────────────────────────────────

const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');

/** Every mirrored file, as `path -> {sha256, bytes}`, keyed by project-relative path. */
function readMirror(cfg) {
  const out = {};
  if (!fs.existsSync(cfg.mirrorDir)) return out;
  const walk = (dir, prefix) => {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      const abs = path.join(dir, entry.name);
      const key = prefix ? `${prefix}/${entry.name}` : entry.name;
      if (entry.isDirectory()) walk(abs, key);
      else if (entry.isFile() && !isSkipped(cfg, key)) {
        const buf = fs.readFileSync(abs);
        out[key] = { sha256: sha256(buf), bytes: buf.length };
      }
    }
  };
  walk(cfg.mirrorDir, '');
  return out;
}

// Repo housekeeping that must never reach a Claude Design project, regardless
// of what design/sync.json says.
const ALWAYS_EXCLUDE = ['**/.gitkeep', '**/.gitignore', '**/.gitattributes', '**/.DS_Store', '.gitkeep', '.gitignore', '.gitattributes', '.DS_Store'];

/** `exclude` = never mirrored. `regenerate` = recreated remotely by an API call. */
function isSkipped(cfg, key) {
  return matchesAny(ALWAYS_EXCLUDE, key) || matchesAny(cfg.exclude, key) || matchesAny(cfg.regenerate, key);
}

function matchesAny(patterns, key) {
  return patterns.some((p) => globToRegExp(p).test(key));
}

function globToRegExp(glob) {
  const src = glob
    .split(/(\*\*\/|\*\*|\*|\?)/)
    .map((tok) => {
      if (tok === '**/') return '(?:.*/)?';
      if (tok === '**') return '.*';
      if (tok === '*') return '[^/]*';
      if (tok === '?') return '[^/]';
      return tok.replace(/[.+^${}()|[\]\\]/g, '\\$&');
    })
    .join('');
  return new RegExp(`^${src}$`);
}

const statePath = (projectId) => path.join(STATE_DIR, `${projectId}.json`);

function readState(projectId) {
  const p = statePath(projectId);
  if (!fs.existsSync(p)) return { projectId, files: {} };
  const s = JSON.parse(fs.readFileSync(p, 'utf8'));
  s.files ??= {};
  return s;
}

function writeState(state) {
  fs.mkdirSync(STATE_DIR, { recursive: true });
  const ordered = Object.fromEntries(Object.entries(state.files).sort(([a], [b]) => a.localeCompare(b)));
  fs.writeFileSync(statePath(state.projectId), `${JSON.stringify({ ...state, files: ordered }, null, 2)}\n`);
}

// ── commands ─────────────────────────────────────────────────────────────────

const commands = {};

commands.target = (args) => {
  const cfg = loadConfig();
  const t = resolveTarget(cfg, args.handle);
  emit(args, t, () => `${t.handle}\t${t.projectId}\t(resolved via ${t.via})`);
};

commands.manifest = (args) => {
  const cfg = loadConfig();
  const mirror = readMirror(cfg);
  emit(args, mirror, () =>
    Object.entries(mirror).map(([k, v]) => `${v.sha256.slice(0, 12)}  ${String(v.bytes).padStart(8)}  ${k}`).join('\n'));
};

/**
 * Three-way diff: mirror (local) x remote listing x last-synced state.
 * `--remote <file>` takes the raw JSON array returned by list_files.
 * Omit it to get a local-only view (what changed since the last sync).
 */
commands.plan = (args) => {
  const cfg = loadConfig();
  const target = resolveTarget(cfg, args.handle);
  const state = readState(target.projectId);
  const local = readMirror(cfg);

  let remote = null;
  if (args.remote) {
    const raw = JSON.parse(fs.readFileSync(path.resolve(args.remote), 'utf8'));
    remote = {};
    for (const e of Array.isArray(raw) ? raw : raw.files ?? []) {
      if (e.type && e.type !== 'file') continue;
      if (isSkipped(cfg, e.path)) continue;
      remote[e.path] = { etag: String(e.etag), bytes: e.size };
    }
  }

  const plan = {
    project: { handle: target.handle, projectId: target.projectId, resolvedVia: target.via },
    hasRemote: remote !== null,
    pull: [], push: [], conflict: [], deleteLocal: [], deleteRemote: [], inSync: [],
    regenerate: cfg.regenerate,
  };

  const paths = new Set([...Object.keys(local), ...Object.keys(remote ?? {}), ...Object.keys(state.files)]);
  for (const p of [...paths].sort()) {
    const l = local[p], r = remote?.[p], s = state.files[p];
    const localChanged = l ? l.sha256 !== s?.sha256 : Boolean(s);
    const remoteChanged = remote === null ? false : r ? String(r.etag) !== s?.etag : Boolean(s);

    if (remote === null) {
      if (localChanged) plan.push.push({ path: p, bytes: l?.bytes ?? 0, reason: l ? (s ? 'local edit' : 'new locally') : 'deleted locally' });
      else plan.inSync.push(p);
      continue;
    }

    if (!l && !r) continue;                                              // stale state entry
    if (l && !r) plan[s ? 'deleteLocal' : 'push'].push({ path: p, bytes: l.bytes, reason: s ? 'removed on remote' : 'new locally' });
    else if (!l && r) plan[s ? 'deleteRemote' : 'pull'].push({ path: p, etag: r.etag, bytes: r.bytes, reason: s ? 'deleted locally' : 'new on remote' });
    else if (localChanged && remoteChanged) plan.conflict.push({ path: p, etag: r.etag, remoteBytes: r.bytes, localBytes: l.bytes, reason: 'edited on both sides' });
    else if (remoteChanged) plan.pull.push({ path: p, etag: r.etag, bytes: r.bytes, reason: 'changed on remote' });
    else if (localChanged) plan.push.push({ path: p, bytes: l.bytes, etag: s?.etag ?? r.etag, reason: 'changed locally' });
    else plan.inSync.push(p);
  }

  emit(args, plan, () => renderPlan(plan));
};

function renderPlan(plan) {
  const lines = [`project ${plan.project.handle} · ${plan.project.projectId}  (via ${plan.project.resolvedVia})`];
  const section = (label, items, fmt) => {
    if (!items.length) return;
    lines.push(`\n${label} (${items.length})`);
    for (const i of items) lines.push(`  ${fmt(i)}`);
  };
  section('PULL  remote → design/files', plan.pull, (i) => `${i.path}  [${i.bytes} B, etag ${i.etag}]  — ${i.reason}`);
  section('PUSH  design/files → remote', plan.push, (i) => `${i.path}  [${i.bytes} B]  — ${i.reason}`);
  section('CONFLICT — resolve by hand', plan.conflict, (i) => `${i.path}  local ${i.localBytes} B / remote ${i.remoteBytes} B`);
  section('DELETE locally', plan.deleteLocal, (i) => i.path);
  section('DELETE on remote', plan.deleteRemote, (i) => i.path);
  if (!plan.hasRemote) lines.push('\n(no --remote listing supplied: local-only view)');
  if (plan.inSync.length) lines.push(`\nin sync: ${plan.inSync.length} file(s)`);
  if (plan.regenerate.length) lines.push(`regenerated server-side, never mirrored: ${plan.regenerate.join(', ')}`);
  return lines.join('\n');
}

/**
 * Decode a staged payload written verbatim from read_file output.
 *
 * read_file escapes exactly three characters — & < > — so decoding is a single
 * left-to-right pass. It MUST be one pass: decoding `&amp;` before `&lt;` would
 * turn a literal `&amp;lt;` in the source into `<` instead of `&lt;`.
 */
/**
 * Strip the wrapper off a read_file tool result that the harness spilled to
 * disk (it does that whenever a result is too large for the model's context).
 *
 * This is the good path: the payload goes remote → disk → decode without the
 * agent ever transcribing a byte, which removes the entire corruption class
 * that `decode --expect-bytes` exists to catch. Prefer it for anything big.
 *
 * The wrapper is:
 *     <untrusted-project-content path="…" etag="…" lines="A-B" total_lines="N">
 *     <body, entity-escaped>
 *     </untrusted-project-content>
 *     (trailing advisory line)
 *
 * The body is everything between the first newline and the newline that
 * immediately precedes the closing tag — sliced by byte offset, not by line
 * count, so a body whose last line is blank survives intact.
 */
commands.extract = (args) => {
  const src = path.resolve(args._[0] ?? die('usage: extract <tool-result-file> --out <staged.escaped>'));
  const dest = path.resolve(args.out ?? die('--out is required'));
  const raw = fs.readFileSync(src, 'utf8');

  const open = raw.match(/^<untrusted-project-content([^>]*)>\n/);
  if (!open) die(`${rel(src)} does not start with an <untrusted-project-content> wrapper`);
  const close = raw.lastIndexOf('\n</untrusted-project-content>');
  if (close < 0) die(`${rel(src)} has no closing </untrusted-project-content> tag`);

  const attr = (name) => (open[1].match(new RegExp(`${name}="([^"]*)"`)) ?? [])[1];

  // Slice up to — but NOT including — the newline that precedes the closing
  // tag. That newline belongs to the wrapper, not the file: the body already
  // carries its own last-line terminator. Keeping it injected one spurious
  // byte per window, which only showed up as a +N size mismatch once two
  // windows were joined.
  const body = raw.slice(open[0].length, close);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, body);

  const info = {
    staged: rel(dest), escapedBytes: Buffer.byteLength(body),
    path: attr('path'), etag: attr('etag'), lines: attr('lines'), totalLines: Number(attr('total_lines')),
  };
  emit(args, info, () =>
    `ok  ${info.path}  lines ${info.lines} of ${info.totalLines}  etag ${info.etag}\n    staged ${info.staged} (${info.escapedBytes} B escaped)`);
};

commands.decode = (args) => {
  if (!args._.length) die('usage: decode <staged-part>... --out <dest> [--verbatim] [--expect-bytes N] [--fix-trailing]');
  const dest = path.resolve(args.out ?? die('--out is required'));

  const parts = args._.map((p) => fs.readFileSync(path.resolve(p), 'utf8'));

  // Two joining modes, because the two staging routes differ:
  //  --verbatim  parts came from `extract`, so each already carries the exact
  //              bytes of its window including the newline that terminates its
  //              last line. Concatenate and change nothing.
  //  default     parts were transcribed by the agent, where a trailing newline
  //              is not reliably preserved. Drop one per part and re-join on
  //              the line boundary the windows were split on. Requires window
  //              boundaries to fall on non-blank lines.
  let text = args.verbatim || parts.length === 1
    ? parts.join('')
    : parts.map((s) => s.replace(/\n$/, '')).join('\n');

  text = text.replace(/&(lt|gt|amp);/g, (_, e) => ({ lt: '<', gt: '>', amp: '&' })[e]);
  let buf = Buffer.from(text, 'utf8');
  let fixed = null;

  if (args['expect-bytes'] !== undefined) {
    const want = Number(args['expect-bytes']);
    const delta = buf.length - want;

    // A ±1 trailing-newline discrepancy is the one transport artefact worth
    // repairing automatically — and only when explicitly opted into, so it can
    // never mask a real truncation.
    if (delta !== 0 && args['fix-trailing'] && Math.abs(delta) === 1) {
      if (delta === 1 && text.endsWith('\n')) { text = text.slice(0, -1); fixed = 'removed trailing newline'; }
      else if (delta === -1) { text += '\n'; fixed = 'added trailing newline'; }
      buf = Buffer.from(text, 'utf8');
    }

    if (buf.length !== want) {
      const d = buf.length - want;
      die(
        `SIZE MISMATCH for ${rel(dest)}: decoded ${buf.length} B, remote reported ${want} B (${d > 0 ? '+' : ''}${d}).\n` +
        (Math.abs(d) === 1
          ? '  Off by one — if this is just a trailing newline, re-run with --fix-trailing.\n'
          : '  The payload was transcribed incompletely or altered. Do NOT record this file.\n' +
            '  Re-read the remote file (in line windows if it is long) and stage every window verbatim,\n' +
            '  passing the parts to decode in order. Never hand-edit the escaped text.\n'),
      );
    }
  }

  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, buf);
  const info = { path: rel(dest), bytes: buf.length, sha256: sha256(buf), parts: parts.length, fixed };
  emit(args, info, () =>
    `ok  ${rel(dest)}  ${buf.length} B  sha256 ${sha256(buf).slice(0, 12)}` +
    (parts.length > 1 ? `  (${parts.length} parts joined)` : '') + (fixed ? `  [${fixed}]` : ''));
};

/** Assert an already-written mirror file matches the byte size the remote reported. */
commands.verify = (args) => {
  const cfg = loadConfig();
  const key = args.path ?? die('--path <project-relative path> is required');
  const abs = path.join(cfg.mirrorDir, key);
  if (!fs.existsSync(abs)) die(`not in mirror: ${key}`);
  const buf = fs.readFileSync(abs);
  const want = Number(args['expect-bytes'] ?? die('--expect-bytes <n> is required'));
  if (buf.length !== want) die(`SIZE MISMATCH for ${key}: local ${buf.length} B vs remote ${want} B`);
  emit(args, { path: key, bytes: buf.length, sha256: sha256(buf) }, () => `ok  ${key}  ${buf.length} B`);
};

/** Mark a path as successfully synced. Only ever call this after verify passed. */
commands.record = (args) => {
  const cfg = loadConfig();
  const target = resolveTarget(cfg, args.handle);
  const state = readState(target.projectId);
  const key = args.path ?? die('--path is required');
  const etag = args.etag ?? die('--etag is required (from read_file / list_files / write_files)');
  const abs = path.join(cfg.mirrorDir, key);
  if (!fs.existsSync(abs)) die(`not in mirror: ${key}`);
  const buf = fs.readFileSync(abs);
  if (args['expect-bytes'] !== undefined && buf.length !== Number(args['expect-bytes'])) {
    die(`refusing to record ${key}: local ${buf.length} B vs expected ${args['expect-bytes']} B`);
  }
  state.files[key] = { etag: String(etag), sha256: sha256(buf), bytes: buf.length };
  writeState(state);
  emit(args, state.files[key], () => `recorded  ${key}  ${buf.length} B  etag ${etag}`);
};

/** Drop a path from sync state (after it was deleted on one side). */
commands.forget = (args) => {
  const cfg = loadConfig();
  const target = resolveTarget(cfg, args.handle);
  const state = readState(target.projectId);
  const key = args.path ?? die('--path is required');
  delete state.files[key];
  writeState(state);
  emit(args, { forgotten: key }, () => `forgot  ${key}`);
};

/** Forget every recorded etag, keeping files. Forces the next plan to treat all as new. */
commands.reset = (args) => {
  const cfg = loadConfig();
  const target = resolveTarget(cfg, args.handle);
  writeState({ projectId: target.projectId, files: {} });
  emit(args, { reset: target.projectId }, () => `reset sync state for ${target.handle} (${target.projectId})`);
};

/** Absolute path for staging a raw read_file payload before decode. */
commands.stage = (args) => {
  const key = args.path ?? die('--path is required');
  const dest = path.join(STAGING_DIR, `${key}.escaped`);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  emit(args, { staging: dest }, () => dest);
};

/** Sanity-check the whole configuration. */
commands.doctor = (args) => {
  const problems = [], warnings = [], notes = [];
  const cfg = loadConfig();
  notes.push(`mirror: ${rel(cfg.mirrorDir)}`);
  if (!fs.existsSync(cfg.mirrorDir)) problems.push(`mirror directory does not exist: ${rel(cfg.mirrorDir)}`);

  const entries = Object.entries(cfg.projects);
  if (!entries.length) problems.push('design/sync.json has no projects configured');
  for (const [handle, p] of entries) {
    if (!p.projectId) notes.push(`${handle}: no projectId yet — run /design:bootstrap as that person`);
    else if (!/^[0-9a-f-]{36}$/.test(p.projectId)) problems.push(`${handle}: projectId is not a UUID: ${p.projectId}`);
  }
  const ids = entries.filter(([, p]) => p.projectId).map(([, p]) => p.projectId);
  if (new Set(ids).size !== ids.length) problems.push('two handles share the same projectId — each person needs their own project');

  // Whether a target resolves is a property of *this machine*, not of the
  // configuration — CI has no git user.name and no target.local.json. So it is
  // a warning by default, and only fatal under --strict.
  try {
    const t = resolveTarget(cfg, args.handle);
    notes.push(`target: ${t.handle} → ${t.projectId} (via ${t.via})`);
    const state = readState(t.projectId);
    notes.push(`sync state: ${Object.keys(state.files).length} file(s) recorded`);
  } catch (e) {
    warnings.push(String(e.message ?? e));
  }

  const local = readMirror(cfg);
  notes.push(`mirrored files: ${Object.keys(local).length}`);
  if (fs.existsSync(STAGING_DIR) && fs.readdirSync(STAGING_DIR).length) {
    problems.push('design/.staging/ is not empty — a previous pull did not finish; inspect it, then delete it');
  }

  if (args.strict) problems.push(...warnings.splice(0));
  const result = { ok: problems.length === 0, problems, warnings, notes };
  emit(args, result, () => [
    ...notes.map((n) => `  ${n}`),
    ...warnings.map((w) => `  ! ${w}`),
    ...problems.map((p) => `  ✗ ${p}`),
    problems.length ? '' : '  ✓ configuration looks good',
  ].join('\n'));
  if (problems.length) process.exitCode = 1;
};

// ── plumbing ─────────────────────────────────────────────────────────────────

function rel(p) { return path.relative(ROOT, p) || '.'; }

class SyncError extends Error {}

/**
 * Abort the current command. Throws rather than calling process.exit so that
 * callers which legitimately want to survive a failure — `doctor` probing
 * whether a target resolves — can catch it.
 */
function die(msg) {
  throw new SyncError(msg);
}

function emit(args, obj, text) {
  process.stdout.write(args.json ? `${JSON.stringify(obj, null, 2)}\n` : `${text()}\n`);
}

function parseArgs(argv) {
  const args = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const [k, inline] = a.slice(2).split(/=(.*)/s);
      if (inline !== undefined) args[k] = inline;
      else if (argv[i + 1] === undefined || argv[i + 1].startsWith('--')) args[k] = true;
      else args[k] = argv[++i];
    } else args._.push(a);
  }
  return args;
}

const [cmd, ...rest] = process.argv.slice(2);
if (!cmd || cmd === '--help' || cmd === '-h' || !commands[cmd]) {
  process.stdout.write(`design/sync — Claude Design ⇄ Git mirror helper

  node tools/design/sync.mjs <command> [--json]

  doctor [--strict]                         validate config, target and state
  target                                    show which Claude Design project this machine syncs with
  manifest                                  sha256 + size of every mirrored file
  plan   [--remote listing.json]            three-way diff: local x remote x last-synced
  stage  --path <p>                         print where to stage a raw read_file payload
  extract <tool-result-file> --out <staged>    strip the read_file wrapper from a spilled result
  decode <part>... --out <f> [--verbatim] [--expect-bytes N] [--fix-trailing]
                                            un-escape a staged payload, refuse on size mismatch
  verify --path <p> --expect-bytes <n>      re-check a mirrored file against the remote size
  record --path <p> --etag <e> [--expect-bytes N]
                                            mark a path synced (only after it verified)
  forget --path <p>                         drop a path from sync state
  reset                                     clear sync state for the current project

  --handle <h>   override which configured project to act on
  --strict       (doctor) treat machine-local warnings as failures
  --json         machine-readable output
`);
  process.exit(cmd && cmd !== '--help' && cmd !== '-h' ? 1 : 0);
}

try {
  commands[cmd](parseArgs(rest));
} catch (e) {
  if (!(e instanceof SyncError)) throw e;
  process.stderr.write(`design/sync: ${e.message}\n`);
  process.exit(1);
}
