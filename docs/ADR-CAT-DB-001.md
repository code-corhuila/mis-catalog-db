# ADR-CAT-DB-001 - Publicar el esquema existente sin reescribir su historia

## Estado y contexto

Decision del equipo para la publicacion oficial, 2026-10-11. La creacion del
repositorio en mis-docs#5 no implica aprobacion docente de cada decision tecnica.
Las migraciones de HU-CAT-001 y HU-CAT-002 ya se aplicaron localmente y su historia
debe conservarse. Se publica conjuntamente el comportamiento y esta decision.

## Decision

Catalogo mantiene su esquema propio dentro del PostgreSQL compartido. Es dueno
de medicamentos y snapshots de creacion, no de cantidades ni movimientos.
Se conservan SQL, rutas e identificadores de los cuatro changesets existentes.
La migracion 002 agrega version=0 y auditoria nula a filas anteriores, sin cambiar
UUID, unidad, datos de creacion ni snapshots. Los cambios posteriores son aditivos.

El escritor solo recibe UPDATE de campos mutables/version/auditoria; no DELETE.
El rollback de 002 rechaza filas con version>0: no borrar evidencia para forzarlo.
Los roles administrativos se usan para migrar, no para atender solicitudes.
La API publicara If-Match/ETag y bloqueo de fila; no se afirma que este PR publique
esa API. Tampoco se promete atomicidad con Inventario ni acceso SQL entre dominios.

## Consecuencias y comprobacion

No se duplica el motor ni se copia el historial de otro dominio. Una prueba con
PostgreSQL desechable verifica repeticion, rollback vacio, upgrade preservando
el snapshot y rechazo de rollback con auditoria. La integracion de la API,
promocion a QA y entrega final siguen siendo pasos separados.
