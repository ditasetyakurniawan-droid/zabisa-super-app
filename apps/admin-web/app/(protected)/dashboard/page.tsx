"use client";

import {useQuery} from "@tanstack/react-query";
import Link from "next/link";
import {Card, PageHeader, Stat} from "../../../components/Page";
import {api, money} from "../../../lib/client";
import {can, permissions} from "../../../lib/rbac";
import type {DonationCampaign, RowRecord, SessionResponse} from "../../../lib/types";

type Metric = {
  label: string;
  value: string | number;
  href?: string;
};

async function loadDashboard() {
  const sessionResponse = await fetch("/api/auth/session", {cache: "no-store"});
  const session = (await sessionResponse.json()) as SessionResponse;
  if (!sessionResponse.ok || !session.data) {
    throw new Error("Session backoffice tidak valid.");
  }

  const role = session.data.role;
  const jobs: Promise<Metric>[] = [];

  if (can(role, permissions.studentsRead)) {
    jobs.push(
      api<RowRecord[]>("/v1/admin/students").then(rows => ({
        label: "Santri",
        value: rows.length,
        href: "/students",
      })),
    );
  }

  if (can(role, permissions.tahfidzRead)) {
    jobs.push(
      api<RowRecord[]>("/v1/tahfidz/entries").then(rows => ({
        label: "Setoran tahfidz",
        value: rows.length,
        href: "/tahfidz",
      })),
    );
  }

  if (can(role, permissions.kajianRead)) {
    jobs.push(
      api<RowRecord[]>("/v1/admin/kajian").then(rows => ({
        label: "Kajian",
        value: rows.length,
        href: "/kajian",
      })),
    );
  }

  if (can(role, permissions.donationRead)) {
    jobs.push(
      api<DonationCampaign[]>("/v1/admin/donation/campaigns")
        .then(campaigns => ({
          label: "Dana terverifikasi",
          value: money(
            campaigns.reduce(
              (total, campaign) => total + Number(campaign.collected_amount || 0),
              0,
            ),
          ),
          href: "/donation",
        }))
        .catch(() => ({label: "Donasi", value: "Tersedia", href: "/donation"})),
    );
  }

  if (can(role, permissions.usersRead)) {
    jobs.push(
      api<RowRecord[]>("/v1/admin/users").then(rows => ({
        label: "User",
        value: rows.length,
        href: "/access",
      })),
    );
  }

  if (can(role, permissions.notificationsRead)) {
    jobs.push(
      api<RowRecord[]>("/v1/admin/notifications").then(rows => ({
        label: "Notifikasi",
        value: rows.length,
        href: "/notifications",
      })),
    );
  }

  if (can(role, permissions.academicsRead)) {
    jobs.push(
      api<RowRecord[]>("/v1/admin/grades").then(rows => ({
        label: "Nilai",
        value: rows.length,
        href: "/academics",
      })),
    );
  }

  if (can(role, permissions.attendanceRead)) {
    jobs.push(
      api<RowRecord[]>("/v1/admin/attendance").then(rows => ({
        label: "Kehadiran",
        value: rows.length,
        href: "/attendance",
      })),
    );
  }

  return {role, metrics: await Promise.all(jobs)};
}

const links = [
  ["Kelola konten", "/content", permissions.contentRead],
  ["Kelola kajian", "/kajian", permissions.kajianRead],
  ["Verifikasi pembayaran", "/donation", permissions.donationRead],
  ["Kelola santri", "/students", permissions.studentsRead],
  ["Input tahfidz", "/tahfidz", permissions.tahfidzRead],
  ["Nilai & report", "/academics", permissions.academicsRead],
  ["Kehadiran", "/attendance", permissions.attendanceRead],
  ["User & Access", "/access", permissions.usersRead],
] as const;

export default function Dashboard() {
  const query = useQuery<{role: string; metrics: Metric[]}, Error>({
    queryKey: ["dashboard", "metrics"],
    queryFn: loadDashboard,
    staleTime: 10_000,
  });

  const role = query.data?.role ?? "";
  const metrics = query.data?.metrics ?? [];

  return (
    <>
      <PageHeader
        title="Dashboard"
        description="Ringkasan hanya menampilkan bounded context yang diizinkan role aktif. Unauthorized data tidak diminta dari browser."
      />

      {query.error && <div className="alert error">{query.error.message}</div>}

      <div className="statsGrid">
        {query.isPending ? (
          <Stat label="Memuat" value="..." />
        ) : (
          metrics.map(metric => (
            <Link key={metric.label} href={metric.href || "#"}>
              <Stat label={metric.label} value={metric.value} />
            </Link>
          ))
        )}
      </div>

      <div className="dashboardGrid">
        <Card title="Aksi sesuai role">
          <div className="quickLinks">
            {links
              .filter(link => can(role, link[2]))
              .map(([label, href]) => (
                <Link key={href} href={href}>
                  {label}
                  <strong>→</strong>
                </Link>
              ))}
          </div>
        </Card>

        <Card title="Security posture">
          <ul className="statusList">
            <li>
              <span className="dot ok" />
              Backend tetap authorization authority
            </li>
            <li>
              <span className="dot ok" />
              Sidebar dan route shell mengikuti RBAC
            </li>
            <li>
              <span className="dot ok" />
              Role/status change merevoke session target
            </li>
            <li>
              <span className="dot ok" />
              Last SUPER_ADMIN lockout protection
            </li>
            <li>
              <span className="dot warn" />
              ABAC assignment scope menyusul untuk kelas/unit
            </li>
          </ul>
        </Card>
      </div>
    </>
  );
}
