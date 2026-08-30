"use client";

import {useQuery, useQueryClient} from "@tanstack/react-query";
import {useCallback} from "react";
import {api} from "./client";

export const apiQueryKey = (path: string) => ["api", path] as const;

export function useApiQuery<T>(path: string) {
  return useQuery<T, Error>({
    queryKey: apiQueryKey(path),
    queryFn: () => api<T>(path),
  });
}

export function useRefreshApi() {
  const queryClient = useQueryClient();
  return useCallback(
    async (...paths: string[]) => {
      await Promise.all(
        paths.map(path => queryClient.invalidateQueries({queryKey: apiQueryKey(path)})),
      );
    },
    [queryClient],
  );
}

export function queryErrorMessage(...errors: Array<Error | null | undefined>) {
  return errors.find(Boolean)?.message ?? "";
}
