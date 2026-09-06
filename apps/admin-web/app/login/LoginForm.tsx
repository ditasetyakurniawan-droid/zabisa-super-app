"use client";

import { SyntheticEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { login } from "../../lib/client";

export default function LoginForm() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: SyntheticEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");

    try {
      await login(email, password);
      router.replace("/dashboard");
      router.refresh();
    } catch (cause) {
      setError((cause as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="loginPage">
      <section className="loginCard">
        <div className="brandMark">Z</div>
        <div>
          <p className="eyebrow">ZABISA PLATFORM</p>
          <h1>Backoffice</h1>
          <p className="muted">
            Kelola pesantren, santri, tahfidz, akademik, konten, donasi, dan
            notifikasi dari satu konsol.
          </p>
        </div>
        <form onSubmit={submit} className="stack">
          <label>
            Email
            <input
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              type="email"
              autoComplete="username"
              required
            />
          </label>
          <label>
            Password
            <input
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              type="password"
              autoComplete="current-password"
              required
            />
          </label>
          <button className="primary" disabled={busy}>
            {busy ? "Memverifikasi..." : "Masuk"}
          </button>
          {error && <div className="alert error">{error}</div>}
        </form>
      </section>
    </main>
  );
}
