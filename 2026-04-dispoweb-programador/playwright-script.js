const { chromium } = require('playwright');

/**
 * Ejecuta el script de Playwright para un sitio específico
 * @param {string} url - La URL del sitio a escanear
 * @param {string} targetId - ID del objetivo para logging
 */
async function executePlaywrightScript(url, targetId) {
  let browser;
  try {
    console.log(`[${new Date().toISOString()}] Iniciando script para: ${targetId} (${url})`);

    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox']
    });

    const page = await browser.newPage();

    console.log(`[${targetId}] Navegando a ${url}...`);
    await page.goto(url, {
      waitUntil: 'domcontentloaded', timeout: 150000
    });

    const ids = await page.evaluate(() => {
      return [...document.querySelectorAll('[id^="prdr-widget-task-"]')]
        .map(el => el.id.replace('prdr-widget-task-', ''))
        .filter(Boolean);
    });

    console.log(`[${targetId}] IDs encontrados:`, ids);

    for (const postId of ids) {
      const targetUrl = `${url}?post_id=${postId}`;

      console.log(`[${targetId}] Abriendo página ${postId}...`);

      await page.goto(targetUrl, { waitUntil: 'load' });

      console.log(`[${targetId}] Esperando que la red se estabilice...`);
      await page.waitForLoadState('domcontentloaded');
      await page.waitForTimeout(5000);

      console.log(`[${targetId}] Esperando botón...`);
      await page.waitForSelector('#prdr-start-scan', {
        state: 'visible',
        timeout: 60000
      });

      await page.waitForTimeout(1500);

      await page.waitForTimeout(1000);

      console.log(`[${targetId}] Pulsando botón...`);
      await page.click('#prdr-start-scan', { force: true });

      console.log(`[${targetId}] ✔ Botón pulsado`);

      console.log(`[${targetId}] Esperando envío automático del sitio...`);
      await page.waitForTimeout(20000);
    }

    console.log(`[${targetId}] ✔ Script completado exitosamente`);
    return { success: true, targetId };

  } catch (err) {
    console.error(`[${targetId}] ❌ Error en el script:`, err.message);
    return { success: false, targetId, error: err.message };
  } finally {
    if (browser) {
      await browser.close();
    }
  }
}

module.exports = { executePlaywrightScript };
