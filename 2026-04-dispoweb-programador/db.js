const mysql = require('mysql2');

// Configuración de la conexión a MariaDB
const dbConfig = {
  host: 'localhost',
  user: 'app_user',
  password: '***',
  database: 'uptimeweb',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
};

let connection;

function createConnection() {
  connection = mysql.createConnection(dbConfig);

  connection.connect((err) => {
    if (err) {
      console.error('Error conectando a la base de datos:', err);
      setTimeout(createConnection, 2000); // Reintentar cada 2 segundos
      return;
    }
    console.log('Conectado a la base de datos MariaDB');
  });

  // Manejar desconexiones
  connection.on('error', (err) => {
    console.error('Error de conexión a la base de datos:', err);
    if (err.code === 'PROTOCOL_CONNECTION_LOST') {
      createConnection();
    }
    if (err.code === 'PROTOCOL_ERROR') {
      createConnection();
    }
    if (err.code === 'ER_CON_COUNT_ERROR') {
      createConnection();
    }
    if (err.code === 'ER_ACCESS_DENIED_ERROR') {
      createConnection();
    }
    if (err.code === 'ER_HANDSHAKE_ERROR') {
      createConnection();
    }
  });

  // Manejar desconexión no esperada
  connection.on('disconnect', () => {
    console.log('Desconectado de la base de datos, reconectando...');
    createConnection();
  });
}

createConnection();

module.exports = connection;