// Small helpers shared by the Edge Functions. No remote imports on purpose: the
// functions start without a network and behave the same locally, on the
// self-hosted server and in the cloud.

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

/** Headers for a PostgREST call with [key]. A JWT also goes in Authorization; the newer sb_ keys must not. */
export function restHeaders(key: string, extra: Record<string, string> = {}): Record<string, string> {
  return {
    'Content-Type': 'application/json',
    apikey: key,
    ...(key.startsWith('eyJ') ? { Authorization: `Bearer ${key}` } : {}),
    ...extra,
  };
}

export const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
