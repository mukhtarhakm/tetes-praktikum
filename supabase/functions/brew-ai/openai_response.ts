type Json = Record<string, unknown>;

export function outputText(response: unknown): string | null {
  if (!response || typeof response !== 'object') return null;
  const body = response as Json;
  if (body.status !== 'completed' || !Array.isArray(body.output)) return null;
  for (const item of body.output) {
    if (!item || typeof item !== 'object') continue;
    const message = item as Json;
    if (message.type !== 'message' || !Array.isArray(message.content)) continue;
    for (const item of message.content) {
      if (!item || typeof item !== 'object') continue;
      const part = item as Json;
      if (part.type === 'output_text' && typeof part.text === 'string') return part.text;
    }
  }
  return null;
}
