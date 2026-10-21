// The platform gives a function its API keys twice: the new ones as a JSON
// dictionary (`SUPABASE_PUBLISHABLE_KEYS`, `SUPABASE_SECRET_KEYS`, for example
// `{"default": "sb_publishable_..."}`), and the legacy ones as plain variables
// (`SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`) that Supabase retires by the
// end of 2026. A function prefers the new key and falls back to the legacy one.
// No Deno API here, so it is tested under Node.

/** The key called [name] in the platform's JSON dictionary; empty or missing is no key. */
export function keyFromDictionary(json: string | undefined, name = 'default'): string | undefined {
  if (!json) {
    return undefined;
  }
  try {
    const dictionary: unknown = JSON.parse(json);
    if (typeof dictionary !== 'object' || dictionary === null) {
      return undefined;
    }
    const value = (dictionary as Record<string, unknown>)[name];
    return typeof value === 'string' && value.length > 0 ? value : undefined;
  } catch {
    return undefined;
  }
}

/** The new key if there is one, otherwise the legacy one. */
export function pickKey(dictionaryJson: string | undefined, legacy: string | undefined): string | undefined {
  return keyFromDictionary(dictionaryJson) ?? (legacy ? legacy : undefined);
}
