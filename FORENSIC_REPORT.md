# FORENSIC_REPORT - eco-air-backend:1.0.0

## Tabla de Identidad

| Dato | Comando | Salida |
|------|---------|--------|
| Hash de la imagen | `docker inspect --format='{{.Id}}' eco-air-backend:1.0.0` | `sha256:154b7ab29aa354614222c0a881817f8f98a6fa41982e721dd65c716da8734ea0` |
| Variable inyectada | `docker exec eco_air_active env \| grep OPERATOR_ID` | `OPERATOR_ID=913148` |

Consumo final calibrado (`docker stats --no-stream eco_air_active`, limite 208m):

```
CONTAINER ID   NAME             CPU %     MEM USAGE / LIMIT   MEM %     NET I/O           BLOCK I/O         PIDS
fdbe0289e979   eco_air_active   0.31%     178.3MiB / 208MiB   85.72%    18.5kB / 14.6kB   88.3MB / 73.7kB   31
```

## Reto 1 - Construccion multietapa

Comando: `docker build --build-arg STUDENT_ID="913148" -t eco-air-backend:1.0.0 .` (126.5 s con `--no-cache`).
Dos etapas: `builder` (Maven, dependencias en una capa propia antes de copiar `src/`) y `runtime` (solo el `.jar`, usuario `sensor_user` UID 10001, `OPERATOR_ID` y `USER` antes del `ENTRYPOINT`).

## Reto 2 - Auditoria forense

- **2.1 Capas:** `docker history` solo muestra capas del runtime (Alpine, JRE, usuario, `.jar`); no hay Maven ni codigo fuente.
- **2.2 Aislamiento:** `docker top` -> `java` (PID 630) bajo el usuario `10001`; `id sensor_user` -> `uid=10001(sensor_user) gid=101(sensorgroup)`; `ps` -> `java` como PID 1 bajo `sensor_u`.
- **2.3 Inmutabilidad:** `touch //etc/crontab_fake` -> `Permission denied`. `/etc` pertenece a root y `sensor_user` no puede escribir.
- **2.4 Artefactos:** `which mvn` sin salida (codigo 1); `find / -name "*.java"` sin resultados (solo `Permission denied` en `/root` y `/proc/tty/driver`). La imagen no contiene compiladores ni fuentes.

## Reto 3 - cgroups y OOM

### 3.1 Colapso con 48 MB

```
Status: exited | ExitCode: 137 | OOMKilled: true
```

El kernel mata el proceso con SIGKILL (137 = 128 + 9) al exceder el limite de memoria del cgroup.

### 3.2 Calibracion del limite minimo (con `--memory-swap` igual a `-m`)

| Limite | Resultado en este equipo |
|--------|--------------------------|
| 192m | `exited`, `ExitCode: 137`, `OOMKilled: true` (murio durante el arranque de Hibernate) |
| 208m | Arranque en 5.638 s, estable tras 30 peticiones, 85.72 % de memoria, sin OOM |
| 224m | Arranque en 5.466 s, estable tras 30 peticiones, 78.61 % de memoria, sin OOM |

**Umbral minimo: 208m.** El valor depende de los recursos del host: en otras pruebas 192m llego a arrancar con muy poco margen.

```
2026-10-20T21:43:40.787667790Z 2026-10-20T21:43:40.787Z  INFO 1 --- [eco-air-backend] [           main] com.ecoair.backend.EcoAirApplication     : Started EcoAirApplication in 5.638 seconds (process running for 6.598)
```
