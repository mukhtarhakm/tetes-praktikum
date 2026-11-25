type Json = Record<string, unknown>;

const object = (value: unknown): value is Json =>
  value !== null && typeof value === 'object' && !Array.isArray(value);
const numberIn = (value: unknown, min: number, max: number) =>
  typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max;
const textIn = (value: unknown, max: number) =>
  typeof value === 'string' && value.length <= max;
const optionalText = (value: unknown, max: number) =>
  value === null || textIn(value, max);
const tags = (value: unknown, max: number) =>
  Array.isArray(value) && value.length <= max &&
  value.every((item) => textIn(item, 30));
const grinds = ['Halus', 'Sedang', 'Kasar'];

function validBrew(value: unknown): value is Json {
  if (!object(value) || !Array.isArray(value.stages) ||
      !Number.isInteger(value.pouring_count) ||
      !numberIn(value.pouring_count, 1, 5) ||
      (value.stages.length !== 0 &&
        value.stages.length !== value.pouring_count) ||
      !value.stages.every((stage) => object(stage) &&
        Number.isInteger(stage.duration_s) && numberIn(stage.duration_s, 5, 120) &&
        numberIn(stage.water_g, 0.01, 800))) return false;
  return numberIn(value.dose_g, 5, 40) && numberIn(value.ratio, 10, 20) &&
    Number.isInteger(value.temperature_c) && numberIn(value.temperature_c, 80, 100) &&
    grinds.includes(value.grind as string) &&
    Number.isInteger(value.score) && numberIn(value.score, 1, 5) &&
    tags(value.taste_tags, 14) && textIn(value.notes, 300) &&
    Number.isInteger(value.duration_s) && numberIn(value.duration_s, 0, 3600) &&
    Array.isArray(value.actual_water_g) && value.actual_water_g.length <= 6 &&
    value.actual_water_g.every((water) =>
      water === null || numberIn(water, 0, 800)) &&
    (value.drawdown_s === null || numberIn(value.drawdown_s, 0, 86400));
}

function validConstraints(value: unknown): value is Json {
  if (!object(value)) return false;
  const allowed = ['dose_g', 'ratio', 'temperature_c', 'grind', 'pouring_count'];
  return Object.keys(value).every((key) => allowed.includes(key)) &&
    (value.dose_g === undefined || numberIn(value.dose_g, 5, 40)) &&
    (value.ratio === undefined || numberIn(value.ratio, 10, 20)) &&
    (value.temperature_c === undefined ||
      (Number.isInteger(value.temperature_c) && numberIn(value.temperature_c, 80, 100))) &&
    (value.grind === undefined || grinds.includes(value.grind as string)) &&
    (value.pouring_count === undefined ||
      (Number.isInteger(value.pouring_count) && numberIn(value.pouring_count, 1, 5)));
}

export function validInput(body: unknown): body is Json {
  if (!object(body)) return false;
  if (body.type === 'recommend') {
    const bean = body.bean;
    return object(bean) && textIn(bean.name, 60) && textIn(bean.origin, 100) &&
      textIn(bean.tasting_notes, 300) && tags(bean.tasting_tags, 10) &&
      optionalText(bean.process, 40) && optionalText(bean.roast_level, 40) &&
      numberIn(bean.stock_g, 0, 1_000_000) &&
      Array.isArray(body.history) && body.history.length <= 8 &&
      body.history.every(validBrew) && textIn(body.goal, 200) &&
      validConstraints(body.constraints);
  }
  if (body.type === 'diagnose') {
    return validBrew(body.brew) && Array.isArray(body.good_history) &&
      body.good_history.length <= 3 && body.good_history.every(validBrew);
  }
  return false;
}

// Aplikasi yang sudah terpasang masih memakai kontrak saran awal versi pertama.
export function validLegacyInput(body: unknown): body is Json {
  if (!object(body)) return false;
  if (body.type === 'recommend' && !('constraints' in body)) {
    const bean = body.bean;
    return object(bean) && textIn(bean.name, 60) &&
      textIn(bean.origin, 100) && textIn(bean.tasting_notes, 300) &&
      Array.isArray(body.history) && body.history.length <= 3 &&
      body.history.every((row) => object(row) &&
        numberIn(row.dose_g, 5, 40) && numberIn(row.ratio, 10, 20) &&
        numberIn(row.temperature_c, 80, 100) && numberIn(row.score, 1, 5));
  }
  if (body.type === 'diagnose' && !('good_history' in body)) {
    const brew = body.brew;
    return object(brew) && numberIn(brew.dose_g, 5, 40) &&
      numberIn(brew.ratio, 10, 20) && numberIn(brew.temperature_c, 80, 100) &&
      numberIn(brew.score, 1, 5) && textIn(brew.notes, 300);
  }
  return false;
}

export function legacyRecommendation(value: unknown): Json | null {
  if (!object(value) || !numberIn(value.dose_g, 5, 40) ||
      !numberIn(value.ratio, 10, 20) ||
      !Number.isInteger(value.temperature_c) ||
      !numberIn(value.temperature_c, 80, 100) ||
      !textIn(value.note, 300) || !(value.note as string).trim()) return null;
  return {
    dose_g: value.dose_g, ratio: value.ratio,
    temperature_c: value.temperature_c, note: (value.note as string).trim(),
  };
}

function brewPlan(value: unknown): Json | null {
  if (!object(value) ||
      !numberIn(value.dose_g, 5, 40) || !numberIn(value.ratio, 10, 20) ||
      !Number.isInteger(value.temperature_c) ||
      !numberIn(value.temperature_c, 80, 100) ||
      !grinds.includes(value.grind as string) ||
      !Number.isInteger(value.pouring_count) ||
      !numberIn(value.pouring_count, 1, 5) ||
      !textIn(value.note, 300) || !(value.note as string).trim() ||
      !Array.isArray(value.stages) ||
      value.stages.length !== value.pouring_count) return null;
  const stages = value.stages as unknown[];
  if (!stages.every((stage) => object(stage) &&
      Number.isInteger(stage.duration_s) && numberIn(stage.duration_s, 5, 120) &&
      numberIn(stage.water_g, 0.01, 800))) return null;
  const total = (value.dose_g as number) * (value.ratio as number);
  const beforeLast = stages.slice(0, -1).reduce(
    (sum, stage) => sum + ((stage as Json).water_g as number), 0,
  );
  const lastWater = total - beforeLast;
  if (lastWater <= 0 ||
      Math.abs((stages.at(-1) as Json).water_g as number - lastWater) > 1) return null;
  return {
    dose_g: value.dose_g,
    ratio: value.ratio,
    temperature_c: value.temperature_c,
    grind: value.grind,
    pouring_count: value.pouring_count,
    stages: stages.map((stage, index) => ({
      duration_s: (stage as Json).duration_s,
      water_g: index === stages.length - 1 ? lastWater : (stage as Json).water_g,
    })),
    note: (value.note as string).trim(),
  };
}

export function recommendation(value: unknown, input: Json): Json | null {
  const plan = brewPlan(value);
  if (plan === null || !object(input.bean) || !object(input.constraints) ||
      (plan.dose_g as number) > (input.bean.stock_g as number)) return null;
  for (const [key, fixed] of Object.entries(input.constraints)) {
    if (typeof fixed === 'number') {
      if (typeof plan[key] !== 'number' || Math.abs((plan[key] as number) - fixed) > 0.01) return null;
    } else if (plan[key] !== fixed) return null;
  }
  return plan;
}

export function diagnosis(value: unknown): Json | null {
  if (!object(value) || !textIn(value.diagnosis, 400) ||
      !(value.diagnosis as string).trim()) return null;
  if (value.next_plan === undefined) {
    return { diagnosis: (value.diagnosis as string).trim() };
  }
  const nextPlan = brewPlan(value.next_plan);
  if (nextPlan === null) {
    return { diagnosis: (value.diagnosis as string).trim() };
  }
  return { diagnosis: (value.diagnosis as string).trim(), next_plan: nextPlan };
}
