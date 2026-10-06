const axios = require('axios');
const qs    = require('qs');

// Contador global de llamadas
let apiCallCount = 0;

// Totales por carpeta
let folderTotals = {};  // Ej: { "Raíz": { totalPersons: 8, packSizeCounts: { 2: 2 } }, "Subcarpeta A": { ... } }

// Patrón: solo "xN"
const packRegex = /x(\d+)/i;

// Helper que envuelve axios y cuenta llamadas
async function doRequest(config) {
  apiCallCount++;
  return axios.request(config);
}

// Configuración de Azure AD
const clientId     = '***';
const clientSecret = '***';
const tenantId     = '***';

// URLs compartidas
const sharedUrls = [
  //'https://empresa-my.sharepoint.com/:f:/g/personal/usuario/CARPETA',
  'https://1drv.ms/f/c/CARPETA_COMPARTIDA',
];

// Codifica la URL compartida en base64 "seguro"
function encodeSharingUrl(url) {
  return Buffer.from(url).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// Obtener token de acceso
async function getAccessToken() {
  const url = `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;
  const data = qs.stringify({
    grant_type:    'client_credentials',
    client_id:     clientId,
    client_secret: clientSecret,
    scope:         'https://graph.microsoft.com/.default'
  });

  const res = await doRequest({
    method: 'post',
    url,
    data,
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
  });

  return res.data.access_token;
}

// Cuenta los PDFs directamente en una carpeta (sin subcarpetas)
async function countPersonsInFolderDirectFiles(driveId, folderId, accessToken, folderName = 'Desconocida') {
  const url = `https://graph.microsoft.com/v1.0/drives/${driveId}/items/${folderId}/children`;
  const headers = { Authorization: `Bearer ${accessToken}` };

  const res = await doRequest({ method: 'get', url, headers });
  const children = Array.isArray(res.data.value) ? res.data.value : [];

  if (!folderTotals[folderName]) {
    folderTotals[folderName] = { totalPersons: 0, packSizeCounts: {} };
  }

  for (const file of children) {
    if (file.file && file.name.toLowerCase().endsWith('.pdf')) {
      const match = file.name.match(packRegex);
      if (match) {
        const persons = parseInt(match[1], 10);
        if (persons > 0) {
          folderTotals[folderName].totalPersons += persons;
          folderTotals[folderName].packSizeCounts[persons] = 
            (folderTotals[folderName].packSizeCounts[persons] || 0) + 1;
        }
      }
    }
  }
}

// Recorre subcarpetas y cuenta personas en cada una
async function traverseAndCount(driveId, parentId, accessToken, parentPath = '') {
  const childrenUrl = `https://graph.microsoft.com/v1.0/drives/${driveId}/items/${parentId}/children`;
  const childrenRes = await doRequest({
    method: 'get',
    url:    childrenUrl,
    headers:{ Authorization: `Bearer ${accessToken}` }
  });

  const children = Array.isArray(childrenRes.data.value) ? childrenRes.data.value : [];

  for (const item of children) {
    if (item.folder) {
      const folderName = parentPath ? `${parentPath}/${item.name}` : item.name;
      await countPersonsInFolderDirectFiles(driveId, item.id, accessToken, folderName);
      await traverseAndCount(driveId, item.id, accessToken, folderName);
    }
  }
}

// Procesar cada carpeta compartida
async function countPersonsInFolder(sharedUrl, accessToken) {
  const encoded  = encodeSharingUrl(sharedUrl);
  const shareUrl = `https://graph.microsoft.com/v1.0/shares/u!${encoded}/driveItem`;
  const shareRes = await doRequest({
    method:  'get',
    url:     shareUrl,
    headers: { Authorization: `Bearer ${accessToken}` }
  });

  const { driveId } = shareRes.data.parentReference;
  const rootId      = shareRes.data.id;
  const rootName    = shareRes.data.name || 'Raíz';

  // Contar archivos directamente en la raíz
  await countPersonsInFolderDirectFiles(driveId, rootId, accessToken, rootName);

  // Explorar subcarpetas y contarlas individualmente
  await traverseAndCount(driveId, rootId, accessToken);
}

// Función principal
async function countAllPersons() {
  const token = await getAccessToken();

  for (const url of sharedUrls) {
    await countPersonsInFolder(url, token);
  }

  console.log(`\nResumen por carpeta:\n`);
  for (const [folder, data] of Object.entries(folderTotals)) {
    console.log(`Carpeta: ${folder}`);
    console.log(`  Total de personas: ${data.totalPersons}`);
    for (const [size, count] of Object.entries(data.packSizeCounts)) {
      console.log(`    - ${count} archivo(s) con x${size} (→ ${size * count} persona(s))`);
    }
    console.log('');
  }

  console.log(`Total llamadas API realizadas: ${apiCallCount}`);
}

countAllPersons();
