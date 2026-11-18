'use strict';

// ==============================================================================
// server.js - [ESQUELETO: Rol 2 - Desarrollador de App y Escalabilidad]
// ==============================================================================
// TODO [Rol 2 - Modulo I]: Fijar UV_THREADPOOL_SIZE antes de operaciones async/crypto
process.env.UV_THREADPOOL_SIZE = process.env.UV_THREADPOOL_SIZE || '4';

const cluster = require('cluster');
const os = require('os');
const express = require('express');
// const Redis = require('ioredis');
// const mysql = require('mysql2/promise');

const PORT = parseInt(process.env.PORT || '3000', 10);
const WORKERS = parseInt(process.env.APP_WORKERS || '2', 10);

// TODO [Rol 2]: Implementar patron cluster (cluster.isPrimary / cluster.fork())
// para generar procesos worker observables en 'top -H' y '/proc/<PID>/task'.
if (cluster.isPrimary) {
  console.log(`[master pid=${process.pid}] TODO: iniciar ${WORKERS} workers con cluster.fork()`);
  startWorker(); // Temporal: reemplazar por cluster.fork() x WORKERS + reinicio en evento 'exit'
} else {
  startWorker();
}

function startWorker() {
  const app = express();
  app.use(express.json());

  // TODO [Rol 2]: Conectar ioredis usando los 3 Redis Sentinels (REDIS_SENTINELS)
  // con enableOfflineQueue: false y timeouts cortos para degradar a MySQL en failover.

  // TODO [Rol 2]: Crear pools mysql2 para MYSQL_PRIMARY_HOST y MYSQL_REPLICA_HOST
  // con failover automatico si el primario no responde.

  // Endpoint de salud para balanceador y sondeo.sh
  app.get('/health', async (_req, res) => {
    // TODO [Rol 2]: Verificar conectividad real hacia MySQL y Redis
    res.json({
      status: 'ok',
      container: os.hostname(),
      pid: process.pid,
      todo: 'Implementar chequeo real de MySQL y Redis Sentinel'
    });
  });

  // Endpoint principal Cache-Aside (Redis -> MySQL) y carga controlada
  app.get('/api/datos', async (req, res) => {
    const id = parseInt(req.query.id || '1', 10);
    // TODO [Rol 2]:
    // 1. Si se solicita carga controlada (?work=N), ejecutar crypto.pbkdf2 en pool libuv
    // 2. Consultar primero en Redis; si hay hit, responder source: 'redis'
    // 3. Si hay miss o failover de Redis, consultar tabla 'registros' en MySQL y guardar en Redis
    res.json({
      id,
      source: 'stub',
      container: os.hostname(),
      pid: process.pid,
      todo: 'Implementar Cache-Aside Redis Sentinel -> MySQL + fallback'
    });
  });

  // TODO [Rol 2]: Implementar POST /api/datos para insertar registros canario
  // y verificar 0 perdida de datos en el failover de MySQL (Exp. 5.4).

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`[worker pid=${process.pid}] Escuchando en puerto ${PORT}`);
  });
}
