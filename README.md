# mis-catalog-db

> catalog bounded context: database (schema, seeds, migrations)

Part of the **Medicine Inventory System** distributed system — team `medicine-inventory-system`, Grupo 1.
Governance and documentation live in [`mis-docs`](https://github.com/code-corhuila/mis-docs).

## Branching

Three permanent branches. **None of them accepts a direct commit** — you enter through a child
branch and leave through a Pull Request.

```
develop  <--PR--  feat/... fix/... chore/...
qa       <--PR--  qa/...
main     <--PR--  release/...  hotfix/...
```

Promotion happens **by re-application** (`git cherry-pick -x`), never by merging one permanent
branch into another: `merge develop -> qa` and `merge qa -> main` do not exist in this model.

`main` requires **1 approval from `ariel5253`**. On `develop` and `qa` the team sets its own review
rule.

Full policy: `00-governance/branching-policy.md` in `mis-docs`.

## Migraciones de Catalogo - HU-CAT-001 y HU-CAT-002

Publicacion del codigo local en el repositorio oficial creado en
[mis-docs#5](https://github.com/code-corhuila/mis-docs/issues/5).
Este repositorio no inicia otro motor: usa el PostgreSQL de `mis-infra-postgres`.

Catalogo posee `catalog.medication` y `catalog.creation_request` (idempotencia).
No almacena stock ni escribe tablas de otros dominios. Los UUID de identidad
no tienen FK hacia Seguridad. No se incluyen datos reales ni credenciales.

Liquibase 4.31.1 mantiene cuatro changesets y los historiales propios
`databasechangelog_catalog` / `databasechangeloglock_catalog`.
Se conservan los SQL y changelog locales ya aplicados, sin cambiar identificadores.
001 crea esquema, tablas y roles; 002 agrega version y auditoria incremental.
`catalog_app` hereda `catalog_writer`: SELECT/INSERT propios y UPDATE solo de
columnas mutables, version y auditoria. Sin DELETE ni UPDATE de UUID/unidad/creacion.
El migrador usa credenciales administrativas; no son credenciales de la API.

### Validacion local

Requiere PowerShell 7, Docker y la infraestructura configurada con `env/dev.env`.
Desde este repositorio, usando la ruta real de la infraestructura:

```powershell
pwsh -NoProfile -File ./tests/Test-Migrations.ps1 -InfraRoot 'D:\descargas\pago 2\mis-infra-postgres'
```

La prueba usa un proyecto aleatorio y puerto dinamico: aplica dos veces, revierte
y reconstruye una base vacia, verifica upgrade de un fixture v1 y rechazo de
rollback cuando ya existe auditoria. Solo elimina el volumen de esa prueba.
No ejecutar rollback sobre dev/qa/main ni modificar migraciones ya aplicadas.
La prueba local no demuestra promocion a QA ni ejecucion en GitHub Actions.

Decision de datos: [ADR-CAT-DB-001](docs/ADR-CAT-DB-001.md).
