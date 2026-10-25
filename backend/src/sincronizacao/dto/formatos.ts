// Data (sem hora): 2026-10-20
export const FORMATO_DATA = /^\d{4}-\d{2}-\d{2}$/;

// Data e hora ISO 8601 COM fuso explícito (Z ou +/-hh:mm): 2026-10-20T18:30:00.000Z
export const FORMATO_DATA_HORA =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$/;

export const MSG_DATA_HORA =
  'deve ser data e hora ISO 8601 com fuso (ex.: 2026-10-20T18:30:00.000Z)';