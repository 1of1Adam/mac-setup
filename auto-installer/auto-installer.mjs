import { spawn } from 'node:child_process';
import fs from 'node:fs/promises';
import fsSync from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const BIN = {
  hdiutil: '/usr/bin/hdiutil',
  plutil: '/usr/bin/plutil',
  sudo: '/usr/bin/sudo',
  ditto: '/usr/bin/ditto',
  xattr: '/usr/bin/xattr',
  open: '/usr/bin/open',
  find: '/usr/bin/find'
};

const APP_DIR = path.join(os.homedir(), 'Library', 'Application Support', 'AutoInstaller');
const DEFAULT_CONFIG_PATH = path.join(APP_DIR, 'config.json');
const DEFAULT_STATE_PATH = path.join(APP_DIR, 'state.json');

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}

function iso(ts = Date.now()) {
  return new Date(ts).toISOString();
}

function expandTilde(p) {
  if (!p) return p;
  if (p === '~') return os.homedir();
  if (p.startsWith('~/')) return path.join(os.homedir(), p.slice(2));
  return p;
}

async function pathExists(p) {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

async function runCmd(cmd, args, opts = {}) {
  const { stdin, timeoutMs } = opts;

  return await new Promise((resolve) => {
    let child;
    try {
      child = spawn(cmd, args, {
        stdio: ['pipe', 'pipe', 'pipe'],
        env: opts.env ?? process.env
      });
    } catch (e) {
      resolve({ code: 127, signal: null, stdout: '', stderr: String(e) });
      return;
    }

    const stdoutChunks = [];
    const stderrChunks = [];

    if (stdin != null) {
      child.stdin.write(stdin);
    }
    child.stdin.end();

    child.stdout.on('data', (d) => stdoutChunks.push(d));
    child.stderr.on('data', (d) => stderrChunks.push(d));

    let timeout;
    if (timeoutMs != null) {
      timeout = setTimeout(() => {
        child.kill('SIGKILL');
      }, timeoutMs);
    }

    child.on('close', (code, signal) => {
      if (timeout) clearTimeout(timeout);
      resolve({
        code: code ?? 0,
        signal: signal ?? null,
        stdout: Buffer.concat(stdoutChunks).toString('utf8'),
        stderr: Buffer.concat(stderrChunks).toString('utf8')
      });
    });
  });
}

function formatError(e) {
  if (!e) return { message: 'unknown error' };
  if (e instanceof Error) return { message: e.message, stack: e.stack };
  return { message: String(e) };
}

function isDmgOrIso(p) {
  const lower = p.toLowerCase();
  if (lower.endsWith('.dmg')) return true;

  // Accept .iso and common variants like .iso.cdr (hdiutil UDTO output).
  const base = path.basename(lower);
  if (base.endsWith('.iso')) return true;
  if (/\\.iso\\.[^./\\\\]+$/.test(base)) return true;
  return false;
}

function isTemporaryDownloadPath(p) {
  const lower = p.toLowerCase();
  return (
    lower.endsWith('.crdownload') ||
    lower.endsWith('.download') ||
    lower.endsWith('.part') ||
    lower.endsWith('.tmp') ||
    lower.endsWith('.aria2') ||
    lower.endsWith('.icloud')
  );
}

function choosePrimaryApp(appPaths) {
  const badWords = [
    'helper',
    'install',
    'installer',
    'uninstall',
    'update',
    'updater',
    'readme',
    'guide',
    'license',
    'support',
    'documentation'
  ];

  const scored = appPaths.map((p) => {
    const base = path.basename(p).toLowerCase();
    const name = base.endsWith('.app') ? base.slice(0, -4) : base;
    let score = 0;
    for (const w of badWords) {
      if (name.includes(w)) score -= 10;
    }
    // Extra penalty for helper-style bundles.
    if (name.includes('helper')) score -= 20;
    // Prefer simpler names.
    score -= Math.min(50, name.length) / 100;
    return { p, score, name };
  });

  scored.sort((a, b) => (b.score - a.score) || a.name.localeCompare(b.name));
  return scored[0]?.p ?? null;
}

async function safeStat(p) {
  try {
    return await fs.stat(p);
  } catch {
    return null;
  }
}

async function ensureDir(p) {
  await fs.mkdir(p, { recursive: true });
}

function defaultConfig() {
  return {
    downloadsDir: path.join(os.homedir(), 'Downloads'),
    installDir: '/Applications',
    fswatchPath: '/opt/homebrew/bin/fswatch',
    stabilityChecks: 4,
    stabilityIntervalMs: 1000,
    debounceMs: 800,
    unstableRetryDelayMs: 2000,
    rescanIntervalMs: 5 * 60 * 1000,
    maxAttemptsPerKey: 20,
    retryBaseDelayMs: 15000,
    retryMaxDelayMs: 5 * 60 * 1000,
    maxFindDepth: 3,
    removeQuarantine: true,
    openPolicy: 'primary', // primary | all | none
    deletePolicy: 'on_success',
    processPreexistingOnStartup: false,
    lockDir: '/tmp/com.adampeng.auto-installer.lock',
    logPath: path.join(os.homedir(), 'Library', 'Logs', 'auto-installer.log'),
    statePath: DEFAULT_STATE_PATH
  };
}

async function loadConfig(cfgPath) {
  const cfg = defaultConfig();
  if (!(await pathExists(cfgPath))) return cfg;

  try {
    const raw = await fs.readFile(cfgPath, 'utf8');
    const userCfg = JSON.parse(raw);
    const merged = { ...cfg, ...userCfg };
    merged.downloadsDir = expandTilde(merged.downloadsDir);
    merged.logPath = expandTilde(merged.logPath);
    merged.statePath = expandTilde(merged.statePath);
    merged.lockDir = expandTilde(merged.lockDir);
    merged.fswatchPath = expandTilde(merged.fswatchPath);
    return merged;
  } catch {
    return cfg;
  }
}

async function loadState(statePath) {
  const base = { version: 1, createdAt: '', updatedAt: '', entries: {} };
  if (!(await pathExists(statePath))) return base;
  try {
    const raw = await fs.readFile(statePath, 'utf8');
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return base;
    if (!parsed.entries || typeof parsed.entries !== 'object') return base;
    return { ...base, ...parsed, entries: parsed.entries };
  } catch {
    return base;
  }
}

async function saveStateAtomic(statePath, state) {
  const dir = path.dirname(statePath);
  await ensureDir(dir);

  const tmp = `${statePath}.tmp-${process.pid}-${Date.now()}`;
  const data = JSON.stringify(state, null, 2) + '\n';
  await fs.writeFile(tmp, data, 'utf8');
  await fs.rename(tmp, statePath);
}

function createLogger(logPath) {
  let lastWrite = Promise.resolve();

  async function writeLine(line) {
    const dir = path.dirname(logPath);
    await ensureDir(dir);
    await fs.appendFile(logPath, line + '\n', 'utf8');
  }

  function log(level, msg, extra) {
    const base = `[${iso()}] [${level}] ${msg}`;
    const line = extra ? `${base} ${JSON.stringify(extra)}` : base;

    // Serialize writes so logs remain ordered.
    lastWrite = lastWrite
      .then(() => writeLine(line))
      .catch(() => {});
  }

  return { log };
}

async function acquireLock(lockDir, logger) {
  const pidFile = path.join(lockDir, 'pid');

  async function removeStaleLockIfAny() {
    try {
      const raw = await fs.readFile(pidFile, 'utf8');
      const pid = Number(raw.trim());
      if (!Number.isFinite(pid) || pid <= 1) return;

      try {
        process.kill(pid, 0);
        // Process exists.
        return;
      } catch {
        // Stale.
        await fs.rm(lockDir, { recursive: true, force: true });
      }
    } catch {
      // Can't read pid file; treat as stale.
      await fs.rm(lockDir, { recursive: true, force: true });
    }
  }

  try {
    await fs.mkdir(lockDir);
  } catch (e) {
    if (e && typeof e === 'object' && e.code === 'EEXIST') {
      await removeStaleLockIfAny();
      try {
        await fs.mkdir(lockDir);
      } catch {
        logger.log('warn', 'Another instance appears to be running; exiting.', { lockDir });
        process.exit(0);
      }
    } else {
      throw e;
    }
  }

  await fs.writeFile(pidFile, String(process.pid), 'utf8');

  const cleanup = async () => {
    try {
      await fs.rm(lockDir, { recursive: true, force: true });
    } catch {}
  };

  const onExit = () => {
    cleanup().finally(() => process.exit(0));
  };

  process.on('SIGINT', onExit);
  process.on('SIGTERM', onExit);
  process.on('uncaughtException', (e) => {
    logger.log('error', 'Uncaught exception', formatError(e));
    onExit();
  });
  process.on('unhandledRejection', (e) => {
    logger.log('error', 'Unhandled rejection', formatError(e));
    onExit();
  });

  return { cleanup };
}

async function plistToJson(plistText) {
  const res = await runCmd(BIN.plutil, ['-convert', 'json', '-o', '-', '-'], { stdin: plistText });
  if (res.code !== 0) {
    throw new Error(`plutil failed (${res.code}): ${res.stderr || res.stdout}`);
  }
  return JSON.parse(res.stdout);
}

function normalizeDevEntry(devEntry) {
  if (!devEntry) return null;
  if (/^\/dev\/disk\d+$/.test(devEntry)) return devEntry;
  const m = devEntry.match(/^\/dev\/disk(\d+)s\d+$/);
  if (m) return `/dev/disk${m[1]}`;
  return devEntry;
}

async function hdiAttach(imagePath, logger) {
  const args = [
    'attach',
    '-nobrowse',
    '-noautoopen',
    '-plist',
    imagePath
  ];

  const res = await runCmd(BIN.hdiutil, args, { timeoutMs: 3 * 60 * 1000 });
  if (res.code !== 0) {
    throw new Error(`hdiutil attach failed (${res.code}): ${res.stderr || res.stdout}`);
  }

  const json = await plistToJson(res.stdout);
  const entities = Array.isArray(json['system-entities']) ? json['system-entities'] : [];

  const mountPoints = entities
    .map((e) => e && e['mount-point'])
    .filter((mp) => typeof mp === 'string' && mp.length > 0);

  const devEntriesRaw = entities
    .map((e) => e && e['dev-entry'])
    .filter((d) => typeof d === 'string' && d.length > 0);

  const devEntries = Array.from(new Set(devEntriesRaw.map(normalizeDevEntry).filter(Boolean)));

  // Prefer whole-disk /dev/diskN if present.
  const detachDev = devEntries.find((d) => /^\/dev\/disk\d+$/.test(d)) ?? devEntries[0] ?? null;

  logger.log('info', 'Mounted image', { imagePath, mountPoints, detachDev });
  return { mountPoints, detachDev };
}

async function hdiDetach(detachDev, logger) {
  if (!detachDev) return;

  const tryDetach = async (force) => {
    const args = ['detach', detachDev, '-quiet'];
    if (force) args.splice(2, 0, '-force');
    const res = await runCmd(BIN.hdiutil, args, { timeoutMs: 60 * 1000 });
    return res;
  };

  for (let i = 0; i < 3; i++) {
    const res = await tryDetach(false);
    if (res.code === 0) {
      logger.log('info', 'Detached image', { detachDev });
      return;
    }
    await sleep(2000);
  }

  const forced = await tryDetach(true);
  if (forced.code === 0) {
    logger.log('warn', 'Detached image with -force', { detachDev });
    return;
  }

  throw new Error(`hdiutil detach failed: ${forced.stderr || forced.stdout}`);
}

async function findAppsInMount(mountPoint, maxDepth) {
  const res = await runCmd(BIN.find, [
    mountPoint,
    '-maxdepth',
    String(maxDepth),
    '-name',
    '*.app',
    '-type',
    'd'
  ], { timeoutMs: 60 * 1000 });

  if (res.code !== 0) {
    return [];
  }

  const lines = res.stdout
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);

  return lines;
}

async function sudoRun(cmd, args, timeoutMs) {
  const res = await runCmd(BIN.sudo, ['-n', cmd, ...args], { timeoutMs });
  if (res.code !== 0) {
    throw new Error(`sudo failed (${res.code}): ${res.stderr || res.stdout}`);
  }
}

async function installAppToApplications(srcAppPath, installDir, removeQuarantine, logger) {
  const appName = path.basename(srcAppPath);
  const target = path.join(installDir, appName);

  const targetExists = await pathExists(target);
  if (targetExists) {
    const ts = iso().replace(/[:.]/g, '-');
    const backup = `${target}.bak-${ts}`;
    logger.log('warn', 'Target app already exists; backing up', { target, backup });
    await sudoRun('/bin/mv', [target, backup], 60 * 1000);
  }

  logger.log('info', 'Copying app', { srcAppPath, target });
  await sudoRun(BIN.ditto, [srcAppPath, target], 10 * 60 * 1000);

  if (removeQuarantine) {
    try {
      await sudoRun(BIN.xattr, ['-dr', 'com.apple.quarantine', target], 60 * 1000);
      logger.log('info', 'Removed quarantine attribute', { target });
    } catch (e) {
      logger.log('warn', 'Failed to remove quarantine attribute', { target, error: formatError(e) });
    }
  }

  return target;
}

async function openApp(appPath, logger) {
  const res = await runCmd(BIN.open, [appPath], { timeoutMs: 30 * 1000 });
  if (res.code !== 0) {
    throw new Error(`open failed (${res.code}): ${res.stderr || res.stdout}`);
  }
  logger.log('info', 'Opened app', { appPath });
}

async function moveToTrash(imagePath, logger) {
  const trashDir = path.join(os.homedir(), '.Trash');
  await ensureDir(trashDir);

  const base = path.basename(imagePath);
  const ext = path.extname(base);
  const stem = base.slice(0, base.length - ext.length);

  let dest = path.join(trashDir, base);
  if (await pathExists(dest)) {
    const ts = iso().replace(/[:.]/g, '-');
    dest = path.join(trashDir, `${stem} (${ts})${ext}`);
  }

  try {
    await fs.rename(imagePath, dest);
  } catch (e) {
    if (e && typeof e === 'object' && e.code === 'EXDEV') {
      await fs.copyFile(imagePath, dest);
      await fs.unlink(imagePath);
    } else {
      throw e;
    }
  }

  logger.log('info', 'Moved image to Trash', { imagePath, dest });
  return dest;
}

async function checkStable(pathToFile, checks, intervalMs) {
  let prev = null;
  for (let i = 0; i < checks; i++) {
    const st = await safeStat(pathToFile);
    if (!st || !st.isFile()) return { stable: false, stat: null };

    const cur = { size: st.size, mtimeMs: st.mtimeMs };
    if (prev && (cur.size !== prev.size || cur.mtimeMs !== prev.mtimeMs)) {
      return { stable: false, stat: null };
    }

    prev = cur;
    if (i !== checks - 1) await sleep(intervalMs);
  }

  const finalStat = await safeStat(pathToFile);
  if (!finalStat || !finalStat.isFile()) return { stable: false, stat: null };
  return { stable: true, stat: finalStat };
}

function makeImageKey(st, fullPath) {
  // Include path for easier debugging; core uniqueness comes from dev+ino.
  return `${st.dev}:${st.ino}:${st.size}:${Math.round(st.mtimeMs)}:${path.basename(fullPath)}`;
}

function pruneState(state, maxEntries = 800) {
  const keys = Object.keys(state.entries);
  if (keys.length <= maxEntries) return;

  keys.sort((a, b) => {
    const at = Date.parse(state.entries[a]?.lastTriedAt ?? '') || 0;
    const bt = Date.parse(state.entries[b]?.lastTriedAt ?? '') || 0;
    return bt - at;
  });

  for (let i = maxEntries; i < keys.length; i++) {
    delete state.entries[keys[i]];
  }
}

async function main() {
  const args = process.argv.slice(2);
  const once = args.includes('--once');
  const dryRun = args.includes('--dry-run');
  const processPreexisting = args.includes('--process-preexisting');

  const cfg = await loadConfig(DEFAULT_CONFIG_PATH);
  const logger = createLogger(cfg.logPath);

  if (!(await pathExists(cfg.fswatchPath))) {
    logger.log('error', 'fswatch not found', { fswatchPath: cfg.fswatchPath });
    process.exit(1);
  }

  await ensureDir(APP_DIR);

  const daemonStartMs = Date.now();
  logger.log('info', 'AutoInstaller starting', {
    once,
    dryRun,
    downloadsDir: cfg.downloadsDir,
    installDir: cfg.installDir,
    processPreexistingOnStartup: cfg.processPreexistingOnStartup,
    daemonStart: iso(daemonStartMs)
  });

  const state = await loadState(cfg.statePath);
  if (!state.createdAt) state.createdAt = iso();

  const { cleanup: cleanupLock } = await acquireLock(cfg.lockDir, logger);

  let processing = false;
  const queue = [];
  const queued = new Set();
  const unstableLogAt = new Map();
  const retryTimers = new Map();

  function scheduleRetry(p, delayMs, reason) {
    if (!p) return;
    const delay = Math.max(250, Number(delayMs) || 0);

    const existing = retryTimers.get(p);
    const when = Date.now() + delay;
    if (existing) {
      // Keep the earlier retry to avoid delaying progress.
      if (existing.when <= when) return;
      clearTimeout(existing.id);
    }

    const id = setTimeout(() => {
      retryTimers.delete(p);
      enqueue(p, reason);
    }, delay);

    retryTimers.set(p, { id, when });
  }

  async function writeState() {
    state.updatedAt = iso();
    pruneState(state);
    await saveStateAtomic(cfg.statePath, state);
  }

  function shouldConsiderFromRescan(st) {
    if (processPreexisting || cfg.processPreexistingOnStartup) return true;

    // Only process files that are new/modified since daemon start.
    const birth = Number(st.birthtimeMs ?? 0);
    const mtime = Number(st.mtimeMs ?? 0);
    const cutoff = daemonStartMs - 2000;
    return birth >= cutoff || mtime >= cutoff;
  }

  function enqueue(p, reason) {
    if (!p) return;
    if (isTemporaryDownloadPath(p)) return;
    if (!isDmgOrIso(p)) return;

    if (queued.has(p)) return;

    queued.add(p);
    queue.push({ p, reason, enqueuedAt: Date.now() });
    void drain();
  }

  async function drain() {
    if (processing) return;
    processing = true;
    try {
      while (queue.length > 0) {
        const { p, reason } = queue.shift();
        queued.delete(p);
        await handleOne(p, reason);
      }
    } finally {
      processing = false;
    }
  }

  async function handleOne(imagePath, reason) {
    const st0 = await safeStat(imagePath);
    if (!st0 || !st0.isFile()) return;

    const stable = await checkStable(imagePath, cfg.stabilityChecks, cfg.stabilityIntervalMs);
    if (!stable.stable) {
      const last = unstableLogAt.get(imagePath) ?? 0;
      const now = Date.now();
      if (now - last > 15000) {
        unstableLogAt.set(imagePath, now);
        logger.log('info', 'Image not stable yet; will retry soon', { imagePath, reason });
      }
      scheduleRetry(imagePath, cfg.unstableRetryDelayMs, 'unstable-retry');
      return;
    }

    const st = stable.stat;
    const key = makeImageKey(st, imagePath);

    const prev = state.entries[key];
    if (prev && prev.status === 'success') return;

    const nowMs = Date.now();
    const prevAttempts = Number(prev?.attempts ?? 0) || 0;
    const nextRetryMs = Date.parse(prev?.nextRetryAt ?? '') || 0;

    if (prev && prev.status === 'running') return;
    if (prev && prev.status === 'fail') {
      if (prevAttempts >= cfg.maxAttemptsPerKey) return;
      if (nextRetryMs && nowMs < nextRetryMs) return;
    }

    const attempts = prevAttempts + 1;

    state.entries[key] = {
      path: imagePath,
      status: 'running',
      attempts,
      nextRetryAt: '',
      firstSeenAt: prev?.firstSeenAt ?? iso(),
      lastTriedAt: iso(),
      reason,
      result: {}
    };
    await writeState();

    if (dryRun) {
      logger.log('info', 'Dry-run: would process image', { imagePath, key });
      state.entries[key].status = 'success';
      state.entries[key].result = { dryRun: true };
      await writeState();
      return;
    }

    let detachDev = null;
    let installedAppPaths = [];
    let openedAppPaths = [];
    let primaryAppPath = null;
    let trashedPath = null;

    try {
      const attachInfo = await hdiAttach(imagePath, logger);
      detachDev = attachInfo.detachDev;

      const apps = [];
      for (const mp of attachInfo.mountPoints) {
        const found = await findAppsInMount(mp, cfg.maxFindDepth);
        for (const f of found) apps.push(f);
      }

      const uniqueApps = Array.from(new Set(apps)).sort();

      if (uniqueApps.length === 0) {
        throw new Error('No .app found in mounted image');
      }

      const primarySrc = choosePrimaryApp(uniqueApps) ?? uniqueApps[0];
      if (uniqueApps.length > 1) {
        logger.log('info', 'Multiple .app found; will install all', {
          imagePath,
          primarySrc,
          count: uniqueApps.length,
          apps: uniqueApps.slice(0, 20)
        });
      }

      const installedPairs = [];
      for (const srcAppPath of uniqueApps) {
        const target = await installAppToApplications(srcAppPath, cfg.installDir, cfg.removeQuarantine, logger);
        installedPairs.push({ srcAppPath, target });
      }

      installedAppPaths = installedPairs.map((p) => p.target);
      primaryAppPath = installedPairs.find((p) => p.srcAppPath === primarySrc)?.target ?? installedPairs[0]?.target ?? null;

      if (cfg.openPolicy !== 'none') {
        if (cfg.openPolicy === 'all') {
          for (const p of installedPairs) {
            await openApp(p.target, logger);
            openedAppPaths.push(p.target);
          }
        } else {
          if (!primaryAppPath) throw new Error('No installed app path to open');
          await openApp(primaryAppPath, logger);
          openedAppPaths.push(primaryAppPath);
        }
      }

      await hdiDetach(detachDev, logger);
      detachDev = null;

      if (cfg.deletePolicy === 'on_success') {
        trashedPath = await moveToTrash(imagePath, logger);
      }

      state.entries[key].status = 'success';
      state.entries[key].nextRetryAt = '';
      state.entries[key].result = { installedAppPaths, openedAppPaths, primaryAppPath, trashedPath };
      await writeState();
    } catch (e) {
      const err = formatError(e);
      logger.log('error', 'Failed to process image', { imagePath, error: formatError(e) });

      state.entries[key].status = 'fail';
      state.entries[key].result = { installedAppPaths, openedAppPaths, primaryAppPath, trashedPath, error: err };

      // Most common failure mode is an incomplete download; retry a few times.
      const msg = String(err.message || '');
      const retryable = msg.includes('hdiutil attach failed') || msg.includes('plutil failed');
      if (retryable && attempts < cfg.maxAttemptsPerKey) {
        const exp = Math.min(6, Math.max(0, attempts - 1));
        const delayMs = Math.min(cfg.retryMaxDelayMs, cfg.retryBaseDelayMs * (2 ** exp));
        state.entries[key].nextRetryAt = iso(Date.now() + delayMs);
        scheduleRetry(imagePath, delayMs, 'retry');
      } else {
        state.entries[key].nextRetryAt = '';
      }

      await writeState();

      // Best-effort cleanup.
      if (detachDev) {
        try {
          await hdiDetach(detachDev, logger);
        } catch (e2) {
          logger.log('error', 'Failed to detach during cleanup', { detachDev, error: formatError(e2) });
        }
      }
    }
  }

  const debounceTimers = new Map();

  function onFsPath(rawPath) {
    // fswatch may output relative paths in some setups; normalize.
    const p = path.isAbsolute(rawPath) ? rawPath : path.join(cfg.downloadsDir, rawPath);

    if (isTemporaryDownloadPath(p)) return;
    if (!isDmgOrIso(p)) return;

    const existing = debounceTimers.get(p);
    if (existing) clearTimeout(existing);

    const t = setTimeout(() => {
      debounceTimers.delete(p);
      enqueue(p, 'fswatch');
    }, cfg.debounceMs);

    debounceTimers.set(p, t);
  }

  async function rescan(reason) {
    let entries;
    try {
      entries = await fs.readdir(cfg.downloadsDir, { withFileTypes: true });
    } catch (e) {
      logger.log('error', 'Failed to read downloads dir', { downloadsDir: cfg.downloadsDir, error: formatError(e) });
      return;
    }

    for (const ent of entries) {
      if (!ent.isFile()) continue;
      const full = path.join(cfg.downloadsDir, ent.name);
      if (isTemporaryDownloadPath(full)) continue;
      if (!isDmgOrIso(full)) continue;

      const st = await safeStat(full);
      if (!st || !st.isFile()) continue;
      if (!shouldConsiderFromRescan(st)) continue;

      enqueue(full, reason);
    }
  }

  // Initial rescan.
  await rescan('startup');

  if (once) {
    // Let queue drain then exit.
    await drain();
    await cleanupLock();
    return;
  }

  // Periodic rescan to avoid missing events.
  setInterval(() => {
    void rescan('periodic');
  }, cfg.rescanIntervalMs);

  function startFswatch() {
    logger.log('info', 'Starting fswatch', { fswatchPath: cfg.fswatchPath, downloadsDir: cfg.downloadsDir });

    const child = spawn(cfg.fswatchPath, [
      '-0',
      '--latency',
      '0.2',
      '--event',
      'Created',
      '--event',
      'Updated',
      '--event',
      'Renamed',
      '--event',
      'MovedTo',
      cfg.downloadsDir
    ], {
      stdio: ['ignore', 'pipe', 'pipe']
    });

    let buf = Buffer.alloc(0);

    child.stdout.on('data', (chunk) => {
      buf = Buffer.concat([buf, chunk]);
      while (true) {
        const idx = buf.indexOf(0);
        if (idx === -1) break;
        const part = buf.slice(0, idx);
        buf = buf.slice(idx + 1);
        const p = part.toString('utf8').trim();
        if (p) onFsPath(p);
      }
    });

    child.stderr.on('data', (d) => {
      const s = d.toString('utf8').trim();
      if (s) logger.log('warn', 'fswatch stderr', { message: s.slice(0, 2000) });
    });

    child.on('close', (code, signal) => {
      logger.log('error', 'fswatch exited; will restart', { code, signal });
      setTimeout(startFswatch, 2000);
    });
  }

  startFswatch();
}

await main();
