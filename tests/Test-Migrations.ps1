param([Parameter(Mandatory)][string]$InfraRoot)
$ErrorActionPreference = 'Stop'
$infra = (Resolve-Path -LiteralPath $InfraRoot).Path
$db = Split-Path $PSScriptRoot
$previousInfra = $env:MIS_INFRA_POSTGRES_PATH
$env:MIS_INFRA_POSTGRES_PATH = $infra.Replace('\','/')
$project = 'mis-cat-check-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$previousPort = $env:PG_HOST_PORT
$env:PG_HOST_PORT = '0'
$options = @('--env-file',(Join-Path $infra 'env/dev.env'),'-p',$project,'-f',(Join-Path $db 'deploy/compose.test.yml'))
$migration = @('--changelog-file=changelog/master.yaml','--database-changelog-table-name=databasechangelog_catalog','--database-changelog-lock-table-name=databasechangeloglock_catalog')
try {
    docker compose @options up -d --wait --wait-timeout 120 postgres
    if ($LASTEXITCODE -ne 0) { throw 'No inicio el PostgreSQL desechable.' }
    foreach ($action in @('first','second','rollback','rebuild')) {
        if ($action -eq 'rollback') { docker compose @options run --rm catalog-db-migrate @migration rollback-count --count=4 }
        else { docker compose @options run --rm catalog-db-migrate }
        if ($LASTEXITCODE -ne 0) { throw "Fallo de migracion: $action" }
        $expected = if ($action -eq 'rollback') { '0' } else { '4' }
        $query = 'SELECT count(*) FROM public.databasechangelog_catalog;'
        $count = $query | docker compose @options exec -T postgres sh -ec 'exec psql -v ON_ERROR_STOP=1 -qAt -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
        if ($LASTEXITCODE -ne 0 -or $count -ne $expected) { throw 'Historial de migracion inesperado.' }
        if ($action -eq 'rollback') {
            $schemas = "SELECT count(*) FROM pg_namespace WHERE nspname='catalog';" | docker compose @options exec -T postgres sh -ec 'exec psql -v ON_ERROR_STOP=1 -qAt -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
            if ($LASTEXITCODE -ne 0 -or $schemas -ne '0') { throw 'El rollback no retiro el esquema.' }
        }
    }
    docker compose @options run --rm catalog-db-migrate @migration rollback-count --count=1
    if($LASTEXITCODE -ne 0) { throw 'No pudo preparar el esquema v1 desechable.' }
    # Fixture solo en el proyecto aleatorio: nunca alterar auditoria de dev/qa/main.
    $seed=@'
INSERT INTO catalog.medication(id,code,name,active_ingredient,pharmaceutical_form,concentration,unit_of_measure,active,created_at,created_by)
VALUES ('11111111-1111-4111-8111-111111111111','UPGRADE-TEST','Sintetico','Sintetico','Tableta','10 mg','Unidad',true,'2026-01-01Z','22222222-2222-4222-8222-222222222222');
INSERT INTO catalog.creation_request(id,actor,request_key,request_hash,response_json,medication_id)
VALUES ('33333333-3333-4333-8333-333333333333','22222222-2222-4222-8222-222222222222','upgrade-test-key',repeat('a',64),'synthetic-original-snapshot','11111111-1111-4111-8111-111111111111');
'@
    $seed | docker compose @options exec -T postgres sh -ec 'exec psql -v ON_ERROR_STOP=1 -qAt -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
    if($LASTEXITCODE -ne 0) { throw 'No pudo crear fixture v1.' }
    docker compose @options run --rm catalog-db-migrate
    if($LASTEXITCODE -ne 0) { throw 'Upgrade incremental fallo.' }
    $verify="SELECT count(*) FROM catalog.medication m JOIN catalog.creation_request r ON r.medication_id=m.id WHERE m.id='11111111-1111-4111-8111-111111111111' AND m.version=0 AND m.updated_at IS NULL AND m.updated_by IS NULL AND m.code='UPGRADE-TEST' AND m.created_at='2026-01-01Z'::timestamptz AND r.response_json='synthetic-original-snapshot';"
    $preserved=$verify | docker compose @options exec -T postgres sh -ec 'exec psql -v ON_ERROR_STOP=1 -qAt -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
    if($LASTEXITCODE -ne 0 -or $preserved -ne '1') { throw 'Upgrade no preservo fixture/snapshot v1.' }
    "UPDATE catalog.medication SET version=1,updated_at=clock_timestamp(),updated_by=created_by WHERE code='UPGRADE-TEST';" | docker compose @options exec -T postgres sh -ec 'exec psql -v ON_ERROR_STOP=1 -qAt -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
    if($LASTEXITCODE -ne 0) { throw 'No pudo preparar auditoria sintetica.' }
    $nativePreference=$PSNativeCommandUseErrorActionPreference
    try {
        $PSNativeCommandUseErrorActionPreference=$false
        $rollback=docker compose @options run --rm catalog-db-migrate @migration rollback-count --count=1 2>&1
        if($LASTEXITCODE -eq 0 -or ($rollback -join "`n") -notmatch 'Exception Primary Reason:\s+ERROR: Rollback forbidden: medication maintenance audit exists') {
            throw 'Rollback no fallo por la guardia de auditoria esperada.'
        }
    } finally { $PSNativeCommandUseErrorActionPreference=$nativePreference }
    $audit="SELECT count(*) FROM catalog.medication WHERE code='UPGRADE-TEST' AND version=1 AND updated_at IS NOT NULL;" | docker compose @options exec -T postgres sh -ec 'exec psql -v ON_ERROR_STOP=1 -qAt -U "$POSTGRES_USER" -d "$POSTGRES_DB"'
    if($LASTEXITCODE -ne 0 -or $audit -ne '1') { throw 'Rollback rechazado altero evidencia.' }
    Write-Output 'PASS: repeticion, rollback/reconstruccion vacios, upgrade preservando v1 y rechazo de rollback con auditoria.'
} finally {
    # Solo se elimina el entorno aleatorio de esta prueba; nunca mis-dev, QA o main.
    docker compose @options down -v
    if ($null -eq $previousInfra) { Remove-Item Env:MIS_INFRA_POSTGRES_PATH -ErrorAction SilentlyContinue }
    else { $env:MIS_INFRA_POSTGRES_PATH = $previousInfra }
    if ($null -eq $previousPort) { Remove-Item Env:PG_HOST_PORT -ErrorAction SilentlyContinue }
    else { $env:PG_HOST_PORT = $previousPort }
}
