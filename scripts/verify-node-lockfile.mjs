#!/usr/bin/env node

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = process.cwd();
const manifestPath = path.join(root, 'package.json');
const lockPath = path.join(root, 'package-lock.json');

function fail(message) {
  console.error(`[node-lock] ERROR: ${message}`);
  process.exitCode = 1;
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, 'utf8'));
  } catch (error) {
    console.error(`[node-lock] ERROR: cannot parse ${path.relative(root, file)}: ${error.message}`);
    process.exit(1);
  }
}

function sameArray(a = [], b = []) {
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

function expandWorkspacePattern(pattern) {
  // The repository currently uses one-level workspace globs (apps/*, packages/*).
  // Keep this verifier dependency-free and fail closed if a more complex pattern appears.
  const parts = pattern.split('/');
  const starCount = parts.filter((part) => part === '*').length;
  if (starCount !== 1 || parts.at(-1) !== '*') {
    fail(`unsupported workspace pattern ${JSON.stringify(pattern)}; update verifier before changing workspace topology`);
    return [];
  }

  const base = path.join(root, ...parts.slice(0, -1));
  if (!fs.existsSync(base)) return [];

  return fs.readdirSync(base, {withFileTypes: true})
    .filter((entry) => entry.isDirectory())
    .map((entry) => path.join(base, entry.name))
    .filter((dir) => fs.existsSync(path.join(dir, 'package.json')))
    .map((dir) => path.relative(root, dir).split(path.sep).join('/'))
    .sort();
}

const manifest = readJson(manifestPath);
const lock = readJson(lockPath);

if (lock.lockfileVersion !== 3) {
  fail(`package-lock.json must use lockfileVersion 3; found ${lock.lockfileVersion ?? 'missing'}`);
}

if (!lock.packages || typeof lock.packages !== 'object') {
  fail('package-lock.json packages map is missing');
}

const rootLock = lock.packages?.[''];
if (!rootLock) {
  fail('package-lock.json root package entry is missing');
} else {
  if (rootLock.name !== manifest.name) {
    fail(`root package name mismatch: package.json=${manifest.name}, lock=${rootLock.name}`);
  }
  const manifestWorkspaces = manifest.workspaces ?? [];
  const lockWorkspaces = rootLock.workspaces ?? [];
  if (!sameArray(manifestWorkspaces, lockWorkspaces)) {
    fail(`workspace declarations differ between package.json and package-lock.json`);
  }
}

const workspacePatterns = manifest.workspaces ?? [];
const workspaceDirs = [...new Set(workspacePatterns.flatMap(expandWorkspacePattern))].sort();
if (workspaceDirs.length === 0) {
  fail('no Node workspaces discovered');
}

const dependencySections = ['dependencies', 'devDependencies', 'optionalDependencies', 'peerDependencies'];
for (const workspaceDir of workspaceDirs) {
  const workspaceManifest = readJson(path.join(root, workspaceDir, 'package.json'));
  const lockEntry = lock.packages?.[workspaceDir];
  if (!lockEntry) {
    fail(`lock entry missing for workspace ${workspaceDir}`);
    continue;
  }

  if (lockEntry.name !== workspaceManifest.name) {
    fail(`${workspaceDir}: name mismatch package.json=${workspaceManifest.name}, lock=${lockEntry.name}`);
  }

  for (const section of dependencySections) {
    const wanted = workspaceManifest[section] ?? {};
    const lockedSpec = lockEntry[section] ?? {};
    const wantedKeys = Object.keys(wanted).sort();
    const lockedKeys = Object.keys(lockedSpec).sort();

    if (!sameArray(wantedKeys, lockedKeys)) {
      fail(`${workspaceDir}: ${section} dependency names differ from package-lock.json`);
      continue;
    }

    for (const name of wantedKeys) {
      if (wanted[name] !== lockedSpec[name]) {
        fail(`${workspaceDir}: ${section}.${name} spec mismatch package.json=${wanted[name]} lock=${lockedSpec[name]}`);
      }
    }
  }
}

if (process.exitCode) {
  process.exit(process.exitCode);
}

console.log(`[node-lock] PASS: package-lock.json is structurally synchronized with ${workspaceDirs.length} Node workspaces.`);
