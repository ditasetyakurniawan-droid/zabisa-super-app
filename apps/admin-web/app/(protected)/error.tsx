"use client";

import {useEffect} from "react";

export default function ProtectedError({
  error,
  reset,
}: {
  error: Error & {digest?: string};
  reset: () => void;
}) {
  useEffect(() => {
    console.error("Backoffice route error", {digest: error.digest, message: error.message});
  }, [error]);

  return (
    <section className="accessDenied">
      <span>!</span>
      <h1>Halaman gagal dimuat</h1>
      <p>
        Backoffice tidak dapat menampilkan modul ini. Coba ulangi tanpa menghapus sesi atau
        data kerja Anda.
      </p>
      <button className="primary inlineButton" type="button" onClick={reset}>
        Coba lagi
      </button>
    </section>
  );
}
