import {Platform} from 'react-native';
import * as Keychain from 'react-native-keychain';
import {runtimeConfig} from '../config/runtime';
import {ApiError} from './errors';

const SERVICE = 'zabisa.auth';
const REQUEST_TIMEOUT_MS = 15_000;
let sessionExpiredHandler: (() => void) | undefined;

export function configureSessionExpiredHandler(handler: () => void) {
  sessionExpiredHandler = handler;
}
export const API_URL = runtimeConfig.apiUrl.replace(/\/$/, '');

export type Session = {access_token: string; refresh_token: string; expires_in: number};
type Envelope<T> = {data: T; error: null} | {data?: never; error: {message: string; code?: string; trace_id?: string}};

export {ApiError, userMessage} from './errors';

export async function getSession() {
  const credential = await Keychain.getGenericPassword({service: SERVICE});
  if (!credential) return null;
  try {
    return JSON.parse(credential.password) as Session;
  } catch {
    await clearSession();
    return null;
  }
}

export async function saveSession(session: Session) {
  await Keychain.setGenericPassword('session', JSON.stringify(session), {service: SERVICE});
}

export async function clearSession() {
  await Keychain.resetGenericPassword({service: SERVICE});
}

async function request<T>(path: string, init: RequestInit = {}, allowRefresh = true): Promise<T> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const session = await getSession();
    const response = await fetch(`${API_URL}${path}`, {
      ...init,
      signal: controller.signal,
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        ...(session?.access_token ? {Authorization: `Bearer ${session.access_token}`} : {}),
        ...(init.headers ?? {}),
      },
    });

    const raw = await response.text();
    let body: Envelope<T> | undefined;
    try {
      body = raw ? JSON.parse(raw) as Envelope<T> : ({data: null, error: null} as Envelope<T>);
    } catch {
      throw new ApiError(response.ok ? 'Respons server tidak valid.' : `HTTP ${response.status}`, response.status);
    }

    if (response.status === 401 && allowRefresh && session?.refresh_token) {
      const refreshed = await refresh(session.refresh_token);
      if (refreshed) {
        await saveSession(refreshed);
        return request<T>(path, init, false);
      }
      await clearSession();
      sessionExpiredHandler?.();
    }

    if (!response.ok || body.error) {
      const err = body.error;
      throw new ApiError(err?.message ?? `HTTP ${response.status}`, response.status, err?.code, err?.trace_id);
    }
    return body.data as T;
  } finally {
    clearTimeout(timeout);
  }
}

async function refresh(refreshToken: string) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const response = await fetch(`${API_URL}/api/v1/auth/refresh`, {
      method: 'POST',
      signal: controller.signal,
      headers: {'Content-Type': 'application/json', Accept: 'application/json'},
      body: JSON.stringify({refresh_token: refreshToken}),
    });
    if (!response.ok) return null;
    const body = await response.json() as Envelope<Session>;
    return body.error ? null : body.data;
  } catch {
    return null;
  } finally {
    clearTimeout(timeout);
  }
}

export const api = request;

export async function signIn(email: string, password: string) {
  const data = await request<Session & {user: unknown}>('/api/v1/auth/login', {
    method: 'POST',
    body: JSON.stringify({email: email.trim().toLowerCase(), password, device_id: `mobile-${Platform.OS}`}),
  }, false);
  await saveSession(data);
  return data.user;
}

export async function signOut() {
  try {
    await request('/api/v1/auth/logout', {method: 'POST'});
  } catch {
    // Local session must still be removed even if the network is unavailable.
  } finally {
    await clearSession();
  }
}
