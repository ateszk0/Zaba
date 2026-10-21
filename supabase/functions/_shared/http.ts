// Small helpers shared by the Edge Functions. No remote imports on purpose: the
// functions start without a network and behave the same locally, on the
// self-hosted server and in the cloud.

import { pickKey } from './keys.ts';

/** The functions are called by the app with a bearer token, not with cookies, so any origin may call them. */
export const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

export function preflight(): Response {
  return new Response(null, { status: 204, headers: corsHeaders });
}

/**
 * The environment of a function, or null (after logging which one is missing,
 * never its value) if something is not set. A function without its secret must
 * refuse to work, never fall back to a default.
 */
export function readEnv<K extends string>(functionName: string, names: readonly K[]): Record<K, string> | null {
  const values = {} as Record<K, string>;
  for (const name of names) {
    const value = Deno.env.get(name);
    if (!value) {
      console.error(`${functionName}: ${name} is not set`);
      return null;
    }
    values[name] = value;
  }
  return values;
}

/**
 * The project's publishable (`which = 'publishable'`) or secret key: the new key
 * from the platform's dictionary variable if it has one, else the legacy
 * variable. Null (after logging which one is missing) if there is none.
 */
export function apiKey(functionName: string, which: 'publishable' | 'secret'): string | null {
  const [dictionary, legacy] = which === 'publishable'
    ? ['SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_ANON_KEY']
    : ['SUPABASE_SECRET_KEYS', 'SUPABASE_SERVICE_ROLE_KEY'];
  const key = pickKey(Deno.env.get(dictionary), Deno.env.get(legacy));
  if (!key) {
    console.error(`${functionName}: neither ${dictionary} nor ${legacy} is set`);
    return null;
  }
  return key;
}

/** Headers for a PostgREST call with [key]. A JWT also goes in Authorization; the newer sb_ keys must not. */
export function restHeaders(key: string, extra: Record<string, string> = {}): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    apikey: key,
    ...(key.startsWith('eyJ') ? { Authorization: `Bearer ${key}` } : {}),
    ...extra,
  };
}

/** The largest request body the functions read. Their bodies are a few hundred bytes. */
export const MAX_BODY_BYTES = 10_000;

/**
 * The text of a request body, or null if it is larger than [maxBytes]. The declared size
 * is checked first, and the body is then read piece by piece and given up as soon as it
 * goes over, so a request with a huge or a lying body never gets into memory whole.
 */
export async function readTextLimited(req: Request, maxBytes = MAX_BODY_BYTES): Promise<string | null> {
  const declared = Number(req.headers.get('content-length'));
  if (Number.isFinite(declared) && declared > maxBytes) {
    return null;
  }
  if (!req.body) {
    return '';
  }
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) {
      break;
    }
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

/** The body as a JSON object, or null if it is too large, not JSON, or not an object. */
export async function readJsonBody(req: Request, maxBytes = MAX_BODY_BYTES): Promise<Record<string, unknown> | null> {
  const text = await readTextLimited(req, maxBytes);
  if (text === null) {
    return null;
  }
  try {
    const value: unknown = JSON.parse(text);
    return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null;
  } catch {
    return null;
  }
}

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
