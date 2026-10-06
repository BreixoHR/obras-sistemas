const express = require('express');
const path = require('path');
const connection = require('./db');
const { loadTargetsAndSchedule, updateSchedule, removeSchedule } = require('./scheduler');

const app = express();
const port = 4009;

// Middleware
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// API endpoint to update active status
app.put('/api/websites/:id/active', (req, res) => {
  const id = req.params.id;
  const active = req.body.active ? 1 : 0;

  connection.query('UPDATE targets SET active = ? WHERE internal_id = ?', [active, id], (err, result) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    if (result.affectedRows === 0) {
      res.status(404).json({ error: 'Target not found' });
      return;
    }

    // Obtener el objetivo actualizado para actualizar su programación
    connection.query('SELECT internal_id, id, url, active, last_run, interval_ms, execute_at FROM targets WHERE internal_id = ?', [id], (err, results) => {
      if (err) {
        console.error('Error obteniendo objetivo:', err);
      } else if (results.length > 0) {
        updateSchedule(id, results[0]);
      }
    });

    res.json({ success: true, active: !!active });
  });
});

// API endpoint to edit card (url and interval)
app.put('/api/websites/:id', (req, res) => {
  const id = req.params.id;
  const { url, interval_ms, execute_at } = req.body;

  if (!url || !interval_ms || isNaN(interval_ms)) {
    return res.status(400).json({ error: 'URL e interval_ms son requeridos y válidos' });
  }

  connection.query(
    'UPDATE targets SET url = ?, interval_ms = ?, execute_at = ? WHERE internal_id = ?',
    [url, interval_ms, execute_at, id],
    (err, result) => {
      if (err) {
        return res.status(500).json({ error: err.message });
      }

      if (result.affectedRows === 0) {
        return res.status(404).json({ error: 'Target not found' });
      }

      
      // refrescar schedule si existe
      connection.query(
        'SELECT internal_id, id, url, active, last_run, interval_ms, execute_at FROM targets WHERE internal_id = ?',
        [id],
        (err, results) => {
          if (err) {
            console.error('Error obteniendo objetivo:', err);
          } else if (results.length > 0) {
            updateSchedule(id, results[0]);
          }
        }
      );

      res.json({ success: true, url, interval_ms });
    }
  );
});

// API endpoint to create a new target
app.post('/api/websites', (req, res) => {
  const { id, url, interval_ms, execute_at } = req.body;
  if (!id || !url || !interval_ms) {
    res.status(400).json({ error: 'Faltan campos obligatorios: id, url e interval_ms' });
    return;
  }

  const active = 1;
  const createdAt = Date.now();

  connection.query(
    'INSERT INTO targets (id, url, interval_ms, execute_at, active, created_at) VALUES (?, ?, ?, ?, ?, ?)',
    [id, url, interval_ms, execute_at, active, createdAt],
    (err, result) => {
      if (err) {
        res.status(500).json({ error: err.message });
        return;
      }

      // Programar el nuevo objetivo
      const newTarget = {
        internal_id: result.insertId,
        id,
        url,
        interval_ms,
        active,
        last_run: null
      };
      updateSchedule(result.insertId, newTarget);

      res.json({ success: true, insertedId: result.insertId });
    }
  );
});

// API endpoint to get list of targets
app.get('/api/websites', (req, res) => {
  connection.query('SELECT internal_id, id, url, active, last_run, interval_ms,execute_at FROM targets', (err, results) => {
    if (err) {
      res.status(500).json({ error: err.message });
      return;
    }
    res.json(results);
  });
});

app.listen(port, () => {
  console.log(`Server running at http://localhost:${port}`);
  console.log('Inicializando scheduler...');
  
  // Iniciar scheduler después de una pequeña pausa para asegurar conexión a BD
  setTimeout(() => {
    loadTargetsAndSchedule();
  }, 2000);
});