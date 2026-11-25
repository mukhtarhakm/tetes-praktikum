import assert from 'node:assert/strict';
import test from 'node:test';

import { outputText } from './openai_response.ts';

test('membaca teks JSON setelah item reasoning', () => {
  const text = '{"diagnosis":"Gilingan mungkin terlalu halus."}';
  assert.equal(outputText({
    status: 'completed',
    output: [
      { type: 'reasoning' },
      { type: 'message', content: [{ type: 'output_text', text }] },
    ],
  }), text);
});

test('menolak respons belum selesai atau tanpa teks', () => {
  assert.equal(outputText({ status: 'incomplete', output: [] }), null);
  assert.equal(outputText({
    status: 'completed',
    output: [{ type: 'message', content: [{ type: 'refusal', refusal: 'Tidak bisa.' }] }],
  }), null);
});
