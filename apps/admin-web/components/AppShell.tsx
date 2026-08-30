"use client";

import Link from "next/link";
import {usePathname, useRouter} from "next/navigation";
import {useMemo} from "react";
import {logout} from "../lib/client";
import {can, canAccessPath, permissions, roleLabels, type InternalRole} from "../lib/rbac";
import {queryErrorMessage} from "../lib/query";
import {useSessionUser} from "../lib/session";
import {useQueryClient} from "@tanstack/react-query";

const groups = [
  {label: "Overview", items: [["Dashboard", "/dashboard", "▦", permissions.backoffice]]},
  {
    label: "Publik & CMS",
    items: [
      ["Konten", "/content", "▤", permissions.contentRead],
      ["Kajian & Event", "/kajian", "◫", permissions.kajianRead],
      ["Donasi", "/donation", "◉", permissions.donationRead],
    ],
  },
  {
    label: "Santri",
    items: [
      ["Data Santri", "/students", "♙", permissions.studentsRead],
      ["Wali & Linking", "/guardians", "◎", permissions.guardiansRead],
      ["Tahfidz", "/tahfidz", "◈", permissions.tahfidzRead],
      ["Akademik & Report", "/academics", "▣", permissions.academicsRead],
      ["Kehadiran", "/attendance", "✓", permissions.attendanceRead],
    ],
  },
  {
    label: "Platform",
    items: [
      ["Notifikasi", "/notifications", "◌", permissions.notificationsRead],
      ["User & Access", "/access", "⚙", permissions.usersRead],
      ["Audit Log", "/audit", "≡", permissions.auditRead],
    ],
  },
] as const;

export default function AppShell({children}: {children: React.ReactNode}) {
  const path = usePathname();
  const router = useRouter();
  const queryClient = useQueryClient();
  const sessionQuery = useSessionUser();

  const user = sessionQuery.data ?? null;
  const visibleGroups = useMemo(
    () =>
      user
        ? groups
            .map(group => ({
              ...group,
              items: group.items.filter(item => can(user.role, item[3])),
            }))
            .filter(group => group.items.length)
        : [],
    [user],
  );

  async function handleLogout() {
    try {
      await logout();
    } finally {
      queryClient.clear();
      router.replace("/login");
      router.refresh();
    }
  }

  if (sessionQuery.isPending) {
    return <main className="centerState">Memverifikasi sesi dan hak akses...</main>;
  }

  if (!user) {
    const error = queryErrorMessage(sessionQuery.error);
    return (
      <main className="centerState">
        <div>
          <p>{error || "Sesi tidak tersedia."}</p>
          <button className="primary" onClick={() => router.replace("/login")}>
            Kembali ke login
          </button>
        </div>
      </main>
    );
  }

  const allowed = canAccessPath(user.role, path);

  return (
    <div className="appLayout">
      <aside className="sidebar">
        <div className="brand">
          <div className="brandMark small">Z</div>
          <div>
            <strong>Zabisa</strong>
            <span>Backoffice</span>
          </div>
        </div>

        <nav className="sideNav">
          {visibleGroups.map(group => (
            <div key={group.label}>
              <p className="navLabel">{group.label}</p>
              {group.items.map(([label, href, icon]) => (
                <Link
                  key={href}
                  href={href}
                  prefetch={false}
                  aria-label={label}
                  className={path === href ? "navItem active" : "navItem"}
                >
                  <span aria-hidden="true">{icon}</span>
                  {label}
                </Link>
              ))}
            </div>
          ))}
        </nav>

        <div className="sidebarFoot">
          <div className="staffCard">
            <strong>{user.name}</strong>
            <span>{roleLabels[user.role as InternalRole] || user.role}</span>
          </div>
          <button className="ghost full" onClick={handleLogout}>
            Keluar
          </button>
        </div>
      </aside>

      <main className="mainArea">
        <header className="topbar">
          <div>
            <p className="eyebrow">YAYASAN SUBULUSSALAM NUSANTARA</p>
            <strong>Zabisa Operations Console</strong>
          </div>
          <div className="topbarRight">
            <span className="roleBadge">
              {roleLabels[user.role as InternalRole] || user.role}
            </span>
            <div className="envBadge">LOCAL</div>
          </div>
        </header>

        <div className="pageBody">
          {allowed ? (
            children
          ) : (
            <section className="accessDenied">
              <span>403</span>
              <h1>Akses tidak diberikan</h1>
              <p>
                Role <strong>{user.role}</strong> tidak mempunyai izin untuk modul ini.
                Backend tetap menjadi authority utama untuk authorization.
              </p>
              <Link className="primary inlineButton" href="/dashboard" prefetch={false}>
                Kembali ke Dashboard
              </Link>
            </section>
          )}
        </div>
      </main>
    </div>
  );
}
