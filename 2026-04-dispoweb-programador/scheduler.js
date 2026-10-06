const connection = require('./db');
const { executePlaywrightScript } = require('./playwright-script');

// Almacenar los trabajos programados
const jobs = {};

/**
 * Carga los objetivos de la base de datos y configura la ejecución
 */
function loadTargetsAndSchedule() {
  connection.query('SELECT internal_id, id, url, active, last_run, interval_ms, execute_at FROM targets', async (err, targets) => {
    if (err) {
      console.error('Error cargando objetivos:', err);
      return;
    }

    console.log(`[${new Date().toISOString()}] Cargando ${targets.length} objetivos...`);

    for (const target of targets) {
      scheduleTarget(target);
    }
  });
}

/**
 * Programa un objetivo específico
 * @param {object} target - Objetivo con: internal_id, id, url, active, interval_ms, last_run
 */
function scheduleTarget(target) {
  const jobKey = `job_${target.internal_id}`;

  // Cancelar trabajo existente si existe
  if (jobs[jobKey]) {
    clearTimeout(jobs[jobKey].timeout);
    clearInterval(jobs[jobKey].interval);
    delete jobs[jobKey];
  }

  if (!target.active) {
    console.log(`[${target.id}] Objetivo desactivado, no será programado`);
    return;
  }

  if (!target.interval_ms || target.interval_ms <= 0) {
    console.log(`[${target.id}] Intervalo inválido (${target.interval_ms}), no será programado`);
    return;
  }

  const intervalMs = target.interval_ms * 60 * 1000;

  let nextRun;
  const lastRun = target.last_run ? new Date(target.last_run) : null;
  const executeAt = target.execute_at ? new Date(target.execute_at) : null;

  console.log(`[${target.id}] Última ejecución fue: ${target.last_run}`);
  console.log(`[${target.id}] execute_at: ${target.execute_at}`);

  // 1. Si hay execute_at y está en el futuro → usarlo
  if (executeAt && executeAt.getTime() > Date.now()) {
    nextRun = executeAt;
    console.log(`[${target.id}] Usando execute_at como próxima ejecución`);
  }
  // 2. Si no, usar lógica basada en last_run + interval
  else {
    nextRun = new Date();

    if (lastRun) {
      const timeSinceLastRun = Date.now() - lastRun.getTime();
      if (timeSinceLastRun < intervalMs) {
        const waitMs = intervalMs - timeSinceLastRun;
        nextRun = new Date(Date.now() + waitMs);
      }
    }
  }

  console.log(
    `[${target.id}] Programado para ejecutarse el ${target.interval_ms} minutos. Próxima ejecución: ${nextRun.toISOString()}`
  );

  const delay = nextRun.getTime() - Date.now();

  // Programar primera ejecución
  const timeout = setTimeout(async () => {
    await executeTarget(target);

    // Programar ejecuciones recurrentes
    const interval = setInterval(async () => {
      await executeTarget(target);
    }, intervalMs);

    jobs[jobKey].interval = interval;

  }, delay);

  jobs[jobKey] = {
    timeout,
    interval: null
  };
}

/**
 * Ejecuta un objetivo específico
 * @param {object} target - Objetivo a ejecutar
 */
async function executeTarget(target) {
  const jobKey = `job_${target.internal_id}`;

  if (!target.active) {
    console.log(`[${target.id}] Objetivo desactivado, cancelando ejecución`);

    if (jobs[jobKey]) {
      clearTimeout(jobs[jobKey].timeout);
      clearInterval(jobs[jobKey].interval);
      delete jobs[jobKey];
    }

    return;
  }

  try {
    await executePlaywrightScript(target.url, target.id);
  } catch (err) {
    console.error(`[${target.id}] Error ejecutando script:`, err);
  }

  const now = Date.now();

  connection.query(
    'UPDATE targets SET last_run = ? WHERE internal_id = ?',
    [now, target.internal_id],
    (err) => {
      if (err) {
        console.error(`[${target.id}] Error actualizando last_run:`, err);
      } else {
        console.log(`[${target.id}] Última ejecución actualizada`);
      }
    }
  );
}

/**
 * Maneja cambios en un objetivo (activado/desactivado)
 * @param {number} internalId - ID interno del objetivo
 * @param {object} target - Datos del objetivo
 */
function updateSchedule(internalId, target) {
  scheduleTarget(target);
}

/**
 * Elimina la programación de un objetivo
 * @param {number} internalId - ID interno del objetivo
 */
function removeSchedule(internalId) {
  const jobKey = `job_${internalId}`;
  if (jobs[jobKey]) {
    jobs[jobKey].cancel();
    delete jobs[jobKey];
    console.log(`[Job ${internalId}] Cancelado`);
  }
}

module.exports = {
  loadTargetsAndSchedule,
  scheduleTarget,
  updateSchedule,
  removeSchedule
};
