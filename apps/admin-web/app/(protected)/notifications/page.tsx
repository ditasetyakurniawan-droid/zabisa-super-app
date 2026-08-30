"use client";

import {FormEvent, useState} from "react";
import DataTable from "../../../components/DataTable";
import {Card, PageHeader, Pill} from "../../../components/Page";
import {api, dateTime} from "../../../lib/client";
import {queryErrorMessage, useApiQuery, useRefreshApi} from "../../../lib/query";
import {can, permissions} from "../../../lib/rbac";
import {useSessionUser} from "../../../lib/session";
import type {
  AdminNotification,
  NotificationCandidate,
  ScheduledNotification,
} from "../../../lib/types";

export default function NotificationsPage() {
  const notificationsQuery = useApiQuery<AdminNotification[]>("/v1/admin/notifications");
  const scheduledQuery =
    useApiQuery<ScheduledNotification[]>("/v1/admin/notifications/scheduled");
  const usersQuery = useApiQuery<NotificationCandidate[]>("/v1/admin/notification-candidates");
  const sessionQuery = useSessionUser();
  const refresh = useRefreshApi();
  const canWrite = sessionQuery.data ? can(sessionQuery.data.role, permissions.notificationsWrite) : false;
  const [message, setMessage] = useState("");

  const rows = notificationsQuery.data ?? [];
  const scheduled = scheduledQuery.data ?? [];
  const users = usersQuery.data ?? [];
  const errorMessage =
    message ||
    queryErrorMessage(
      notificationsQuery.error,
      scheduledQuery.error,
      usersQuery.error,
      sessionQuery.error,
    );

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (!canWrite) { setMessage("Role Anda hanya memiliki akses baca notifikasi."); return; }
    const formEl = event.currentTarget;
    const form = new FormData(formEl);
    const rawSchedule = String(form.get("scheduled_at") || "");
    const payload = {
      user_id: form.get("user_id"),
      type: form.get("type"),
      title: form.get("title"),
      message: form.get("message"),
      deep_link: form.get("deep_link"),
      scheduled_at: rawSchedule ? new Date(rawSchedule).toISOString() : "",
    };

    try {
      await api("/v1/admin/notifications", {
        method: "POST",
        body: JSON.stringify(payload),
      });
      formEl.reset();
      setMessage(rawSchedule ? "Notifikasi dijadwalkan." : "Notifikasi dibuat.");
      await refresh("/v1/admin/notifications", "/v1/admin/notifications/scheduled");
    } catch (error) {
      setMessage((error as Error).message);
    }
  }

  return (
    <>
      <PageHeader
        title="Notification Center"
        description="Compose, broadcast/target user, scheduling, inbox persistence, dan deep-link. Adapter FCM/APNs production tetap credential-driven."
      />

      {errorMessage && (
        <div
          role="status"
          aria-live="polite"
          className={
            /dibuat|dijadwalkan/.test(errorMessage) ? "alert success" : "alert error"
          }
        >
          {errorMessage}
        </div>
      )}

      <div className="split">
        <Card title="Compose">
          {canWrite ? (
          <form className="formGrid" onSubmit={submit}>
            <label>
              Audience
              <select name="user_id" defaultValue="" disabled={usersQuery.isPending}>
                <option value="">{usersQuery.isPending ? "Memuat audience..." : "Broadcast / semua user"}</option>
                {users.map(user => (
                  <option key={user.id} value={user.id}>
                    {user.display_name} · {user.role}
                  </option>
                ))}
              </select>
            </label>

            <label>
              Tipe
              <select name="type" defaultValue="ANNOUNCEMENT">
                <option>ANNOUNCEMENT</option>
                <option>KAJIAN</option>
                <option>NEWS</option>
                <option>DONATION</option>
                <option>ACADEMIC</option>
                <option>TAHFIDZ</option>
                <option>EMERGENCY</option>
              </select>
            </label>

            <label>
              Judul
              <input name="title" required />
            </label>
            <label>
              Pesan
              <textarea name="message" required />
            </label>
            <label>
              Deep link
              <input name="deep_link" placeholder="zabisa://..." />
            </label>
            <label>
              Jadwalkan (opsional)
              <input name="scheduled_at" type="datetime-local" />
            </label>

            <button className="primary">Kirim / jadwalkan</button>
          </form>
          ) : (
            <div className="permissionInfo"><strong>Mode read-only</strong><p>Role Anda dapat membaca history notifikasi tetapi tidak dapat membuat atau menjadwalkan notifikasi.</p></div>
          )}
        </Card>

        <Card title="Scheduled">
          <DataTable
            loading={scheduledQuery.isPending}
            rows={scheduled}
            columns={[
              {
                key: "scheduled_at",
                label: "Jadwal",
                render: row => dateTime(row.scheduled_at),
              },
              {key: "title", label: "Judul"},
              {key: "type", label: "Tipe"},
              {
                key: "processed_at",
                label: "Status",
                render: row => (
                  <Pill tone={row.processed_at ? "ok" : "warn"}>
                    {row.processed_at ? "Processed" : "Scheduled"}
                  </Pill>
                ),
              },
            ]}
          />
        </Card>
      </div>

      <Card title="Delivery / inbox history">
        <DataTable
          loading={notificationsQuery.isPending}
          rows={rows}
          columns={[
            {key: "created_at", label: "Waktu", render: row => dateTime(row.created_at)},
            {
              key: "type",
              label: "Tipe",
              render: row => <Pill tone="info">{row.type}</Pill>,
            },
            {key: "title", label: "Judul"},
            {key: "message", label: "Pesan"},
            {
              key: "user_id",
              label: "Audience",
              render: row => row.user_id || "Broadcast",
            },
          ]}
        />
      </Card>
    </>
  );
}
