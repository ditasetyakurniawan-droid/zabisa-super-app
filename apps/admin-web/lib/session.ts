"use client";

import {useQuery} from "@tanstack/react-query";
import type {SessionResponse, SessionUser} from "./types";

export const sessionQueryKey = ["auth", "session"] as const;

export async function fetchSessionUser(): Promise<SessionUser> {
  const response = await fetch("/api/auth/session", {cache: "no-store"});
  const body = (await response.json()) as SessionResponse;
  if (!response.ok || !body.data) throw new Error("Session tidak valid.");
  return body.data;
}

export function useSessionUser() {
  return useQuery<SessionUser, Error>({
    queryKey: sessionQueryKey,
    queryFn: fetchSessionUser,
    retry: false,
    staleTime: 15_000,
  });
}
