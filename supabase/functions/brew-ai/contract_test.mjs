import assert from 'node:assert/strict';
import test from 'node:test';
import {
  diagnosis, legacyRecommendation, recommendation,
  validInput, validLegacyInput,
} from './contract.ts';

const brew = {
  dose_g: 15, ratio: 16, temperature_c: 92, grind: 'Sedang',
  pouring_count: 3, score: 5,
  stages: [
    { duration_s: 40, water_g: 45 },
    { duration_s: 30, water_g: 95 },
    { duration_s: 30, water_g: 100 },
  ],
  taste_tags: ['manis', 'floral'], notes: 'Enak dan seimbang',
  duration_s: 160, actual_water_g: [45, 94, 99], drawdown_s: 60,
};
const input = {
  type: 'recommend',
  bean: {
    name: 'Gayo Aceh', origin: 'Aceh', tasting_notes: 'floral',
    tasting_tags: ['floral'], process: 'Washed', roast_level: 'Light',
    stock_g: 100,
  },
  history: [brew, { ...brew, ratio: 15, score: 5 }],
  goal: 'Lebih manis', constraints: { dose_g: 15 },
};
const output = {
  dose_g: 15, ratio: 16, temperature_c: 92, grind: 'Sedang',
  pouring_count: 3, stages: brew.stages, note: 'Coba dan catat hasilnya.',
};

test('menerima beberapa riwayat beans dan tujuan rasa', () => {
  assert.equal(validInput(input), true);
  assert.equal(validInput({ ...input, history: [{ ...brew, stages: [] }] }), true);
  assert.equal(validInput({ ...input, history: Array(9).fill(brew) }), false);
});

test('menjaga isian terkunci dan total air tiap tuangan', () => {
  assert.deepEqual(recommendation(output, input)?.stages, brew.stages);
  assert.equal(recommendation({ ...output, dose_g: 18 }, input), null);
  assert.equal(recommendation({ ...output, stages: [
    { duration_s: 40, water_g: 45 },
    { duration_s: 30, water_g: 95 },
    { duration_s: 30, water_g: 110 },
  ] }, input), null);
});

test('diagnosis menerima tag rasa dan catatan setelah seduh', () => {
  assert.equal(validInput({ type: 'diagnose', brew, good_history: [brew] }), true);
  assert.deepEqual(diagnosis({ diagnosis: 'Coba giling sedikit lebih halus.' }), {
    diagnosis: 'Coba giling sedikit lebih halus.',
  });
  assert.deepEqual(diagnosis({
    diagnosis: 'Coba suhu lebih rendah.', next_plan: output,
  })?.next_plan, output);
  assert.deepEqual(diagnosis({
    diagnosis: 'Coba suhu lebih rendah.',
    next_plan: { ...output, stages: [{ duration_s: 40, water_g: 45 }] },
  }), { diagnosis: 'Coba suhu lebih rendah.' });
});

test('permintaan aplikasi lama tetap diterima', () => {
  const old = {
    type: 'recommend',
    bean: { name: 'Gayo Aceh', origin: 'Aceh', tasting_notes: 'floral' },
    history: [{ dose_g: 15, ratio: 16, temperature_c: 92, score: 5 }],
  };
  assert.equal(validLegacyInput(old), true);
  assert.deepEqual(legacyRecommendation({
    dose_g: 15, ratio: 16, temperature_c: 92, note: 'Coba dulu.',
  }), { dose_g: 15, ratio: 16, temperature_c: 92, note: 'Coba dulu.' });
});
