#!/usr/bin/env node

import {readFileSync} from 'node:fs';

const reportPath = process.argv[2];
if (!reportPath) {
  console.error('[npm-audit] ERROR: usage: verify-npm-audit.mjs <npm-audit.json>');
  process.exit(64);
}

let report;
try {
  report = JSON.parse(readFileSync(reportPath, 'utf8'));
} catch (error) {
  console.error(`[npm-audit] ERROR: cannot parse ${reportPath}: ${error.message}`);
  process.exit(1);
}

if (report.error) {
  console.error(`[npm-audit] ERROR: audit service failed: ${report.error.code || report.error.summary || 'unknown error'}`);
  process.exit(1);
}

const vulnerabilities = report.vulnerabilities;
if (!vulnerabilities || typeof vulnerabilities !== 'object') {
  console.error('[npm-audit] ERROR: report has no npm v2 vulnerability map.');
  process.exit(1);
}

const blockingSeverities = new Set(['high', 'critical']);
const acceptedAdvisories = new Map([
  ['GHSA-W3RX-R6R6-PGPR', {
    packageName: 'image-size',
    expires: '2026-12-01',
    reason: 'No patched upstream release; transitive React Native Metro build-time parser.',
  }],
  ['GHSA-5P2G-FCMC-QVQQ', {
    packageName: 'image-size',
    expires: '2026-12-01',
    reason: 'No patched upstream release; transitive React Native Metro build-time parser.',
  }],
]);

function rootAdvisories(packageName, visited = new Set()) {
  if (visited.has(packageName)) return [];
  const vulnerability = vulnerabilities[packageName];
  if (!vulnerability) return [];

  const nextVisited = new Set(visited);
  nextVisited.add(packageName);

  return (vulnerability.via || []).flatMap(via => {
    if (typeof via === 'string') return rootAdvisories(via, nextVisited);
    return via && typeof via === 'object' ? [via] : [];
  });
}

function advisoryID(advisory) {
  const value = `${advisory.url || ''} ${advisory.title || ''}`;
  return value.match(/GHSA-[0-9a-z-]+/i)?.[0]?.toUpperCase() || '';
}

function isExpired(expires) {
  const endOfDay = Date.parse(`${expires}T23:59:59Z`);
  return !Number.isFinite(endOfDay) || Date.now() > endOfDay;
}

const blockers = [];
const accepted = new Map();

for (const [packageName, vulnerability] of Object.entries(vulnerabilities)) {
  if (!blockingSeverities.has(vulnerability.severity)) continue;

  const advisories = rootAdvisories(packageName).filter(advisory =>
    blockingSeverities.has(advisory.severity),
  );

  if (advisories.length === 0) {
    blockers.push(`${packageName}: ${vulnerability.severity} vulnerability has no auditable root advisory`);
    continue;
  }

  for (const advisory of advisories) {
    const id = advisoryID(advisory);
    const policy = acceptedAdvisories.get(id);
    const advisoryPackage = advisory.name || advisory.dependency || '';

    if (!policy) {
      blockers.push(`${packageName}: unapproved ${advisory.severity} advisory ${id || advisory.title || 'unknown'}`);
      continue;
    }
    if (policy.packageName !== advisoryPackage) {
      blockers.push(`${packageName}: ${id} package mismatch (${advisoryPackage || 'unknown'})`);
      continue;
    }
    if (isExpired(policy.expires)) {
      blockers.push(`${packageName}: accepted advisory ${id} expired on ${policy.expires}`);
      continue;
    }

    if (!accepted.has(id)) accepted.set(id, {...policy, affectedPackages: new Set()});
    accepted.get(id).affectedPackages.add(packageName);
  }
}

for (const [id, policy] of accepted) {
  const affectedPackages = [...policy.affectedPackages].sort().join(', ');
  console.warn(`[npm-audit] ACCEPTED: ${id} until ${policy.expires}; affects ${affectedPackages}`);
  console.warn(`[npm-audit] RATIONALE: ${policy.reason}`);
}

if (blockers.length > 0) {
  for (const blocker of [...new Set(blockers)].sort()) {
    console.error(`[npm-audit] BLOCKED: ${blocker}`);
  }
  process.exit(1);
}

const counts = report.metadata?.vulnerabilities || {};
console.log(`[npm-audit] PASS: no unapproved high/critical advisories. Report totals: ${counts.critical || 0} critical, ${counts.high || 0} high, ${counts.moderate || 0} moderate.`);
