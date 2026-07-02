# Manual de Failover — DR Pilot Light Demo
### Webinar: Disaster Recovery en AWS con Terraform

---

## Antes de empezar

Confirma que tienes abierto en pantalla:
- Terminal con el proyecto clonado
- Consola AWS us-east-1 (una pestaña)
- Consola AWS us-east-2 (otra pestaña)
- Terraform Cloud workspace
- Browser para verificar la app

---

## PREVIO — Crear Health Checks manualmente en Route 53

Los health checks no están en el código Terraform. Créalos manualmente una vez que la infraestructura esté desplegada.

**En la consola AWS → Route 53 → Health checks → Create health check:**

Health check del EC2 Primary (us-east-1):
- Name: `dr-pilot-light-primary-hc`
- What to monitor: `Endpoint`
- Protocol: `HTTP` — Port: `80` — Path: `/`
- Specify endpoint by: `IP address`
- IP: la IP pública del EC2 primary (output `primary_app_url`)
- Request interval: `Fast (10 seconds)` ← detecta la caída más rápido en demo
- Failure threshold: `3`

Health check del EC2 DR (us-east-2):
- Name: `dr-pilot-light-dr-hc`
- Misma configuración pero con la IP del EC2 DR
- Créalo después del Paso 3 cuando el EC2 DR ya esté corriendo y tenga IP asignada

**Qué muestran durante la demo:**

| Momento | HC Primary | HC DR |
|---|---|---|
| Estado normal | Healthy | — (aún no creado) |
| Tras Paso 1 (EC2 detenido) | Unhealthy | — |
| Tras Paso 3 (EC2 DR activo) | Unhealthy | Healthy |

> "En producción estos health checks estarían asociados a registros DNS con política de failover. Route 53 cambiaría el DNS automáticamente sin intervención manual."

---

## Arrancar el script

```bash
./failover.sh
```

El script pide tres valores al inicio. Los encuentras en:
**Terraform Cloud → workspace → último run → pestaña Outputs**

| Campo que pide | Output de TF Cloud | Ejemplo |
|---|---|---|
| IP pública EC2 Primary | `primary_app_url` (sin http://) | `98.92.235.167` |
| ID del EC2 Primary | `primary_ec2_id` | `i-0124b11a8099bbba9` |
| ID de la RDS Replica | `dr_rds_replica_id` | `dr-pilot-light-dr-mysql-replica` |

**Antes de presionar ENTER — mostrar a la audiencia:**

- Abre `http://<IP_PRIMARY>` en el browser → debe mostrar "Respondiendo desde: us-east-1"
- Consola AWS us-east-1 → EC2: instancia `dr-pilot-light-primary-web` en **running**
- Consola AWS us-east-1 → RDS: instancia `dr-pilot-light-primary-mysql` en **available**
- Consola AWS us-east-2 → EC2: **no hay ninguna instancia** ← este es el punto clave
- Consola AWS us-east-2 → RDS: réplica `dr-pilot-light-dr-mysql-replica` en **available**
- Route 53 → Health checks: `dr-pilot-light-primary-hc` en **Healthy**

> "Lo que están viendo ahora es el patrón Pilot Light en estado de reposo. us-east-2 tiene la base de datos replicando en tiempo real, pero no tiene servidores. El código para crearlos existe, con count=0. Mínimo costo, máxima preparación."

Presiona ENTER para continuar.

---

## PASO 1 — Simular el desastre

El script pide confirmación para detener el EC2 primario. Confirma con `s`.

El script captura el **inicio del RTO** en este momento.

**Qué mostrar mientras el EC2 se detiene (~1 minuto):**

- Consola AWS us-east-1 → EC2: la instancia cambia **running → stopping → stopped**
- Recarga el browser con `http://<IP_PRIMARY>` → debe mostrar timeout o error de conexión
- Route 53 → Health checks: en ~30 segundos `dr-pilot-light-primary-hc` cambia a **Unhealthy**

> "us-east-1 está caído. En un escenario real este momento representaría una caída de región, un incidente de seguridad o una corrupción de datos. El equipo de operaciones habría recibido una alerta y estaría ejecutando el runbook de DR."

> "Noten que la base de datos en us-east-2 sigue replicando normalmente. No se ha visto afectada. Esa es la ventaja del Pilot Light: la capa de datos es completamente independiente de la capa de cómputo."

Presiona ENTER para continuar.

---

## PASO 2 — Promover la Read Replica

El script pide confirmación para promover la réplica. Confirma con `s`.

**Qué mostrar en la consola AWS us-east-2 → RDS (tarda 2-5 minutos):**

- El estado cambia **available → modifying → available**
- Cuando vuelva a **available**, el campo "Replication role" cambia de `Replica` a `Primary`

> "La promoción convierte la réplica en una instancia primaria independiente que acepta escrituras. A partir de este momento us-east-2 tiene control total de los datos."

> "Esto es lo que diferencia Pilot Light de un backup tradicional. Con un backup tendrías que restaurar los datos, lo que podría tomar horas. Aquí la base de datos ya estaba lista y sincronizada — el RPO es prácticamente cero."

> "Una vez promovida, la replicación desde us-east-1 se rompe permanentemente. us-east-2 se convierte en la fuente de verdad."

Presiona ENTER cuando el estado de RDS vuelva a **available**.

---

## PASO 3 — Activar el cómputo en DR (Terraform Cloud)

El script muestra las instrucciones y espera. Ve a Terraform Cloud:

1. **Variables** → edita `dr_ec2_enabled` → cambia `false` por `true` → Save
2. **Actions → Start new run** → Plan and apply → confirma el apply

**Qué mostrar en Terraform Cloud antes de aplicar:**

El plan debe mostrar:
```
Plan: 1 to add, 0 to change, 0 to destroy.
```

> "Fíjense en el plan: solo 1 recurso nuevo. El EC2. Todo lo demás — la VPC, las subnets, los security groups — ya existía en us-east-2 desde el primer deploy. Eso es exactamente lo que hace que el failover sea tan rápido."

> "En un entorno productivo este apply lo dispararía un pipeline automatizado, no una persona. El cambio de variable sería la señal de activación del runbook."

Mientras corre el apply, muestra en la consola AWS us-east-2 → EC2:
- La instancia `dr-pilot-light-dr-web` aparece **pending → running**

Cuando el apply termine, copia la IP del EC2 DR desde los outputs (`dr_app_url`, sin http://).

Vuelve al script, presiona ENTER e ingresa la IP.

---

## PASO 4 — Validar el failover

El script hace curl automático. Puede tardar ~60-90 segundos mientras el EC2 termina de instalar nginx.

> "El EC2 acaba de arrancar y está ejecutando el script de arranque: instalando nginx y generando la página HTML con los datos de la región. En producción aquí estaría desplegando tu aplicación real desde un artefacto o un repositorio."

Cuando nginx responda, abre `http://<IP_DR>` en el browser.

**La página debe mostrar:**
```
Respondiendo desde: us-east-2
Hostname: ip-10-1-x-x
```

Crea ahora el health check del EC2 DR en Route 53:
- Route 53 → Health checks → Create health check
- Name: `dr-pilot-light-dr-hc`, IP: la IP del EC2 DR, misma configuración
- En ~30 segundos aparece en **Healthy**

**Checklist visual final:**

| Qué verificar | Dónde | Estado esperado |
|---|---|---|
| App en browser | `http://<IP_DR>` | Muestra us-east-2 |
| EC2 DR | Consola AWS us-east-2 → EC2 | running |
| RDS DR | Consola AWS us-east-2 → RDS | available, role: Primary |
| EC2 Primary | Consola AWS us-east-1 → EC2 | stopped |
| HC Primary | Route 53 → Health checks | Unhealthy |
| HC DR | Route 53 → Health checks | Healthy |

Al terminar la validación, el script muestra las métricas finales del failover con el RTO real medido desde el Paso 1.

> "En menos de 15 minutos pasamos de una región caída a tener la aplicación respondiendo desde la región DR con la base de datos activa y aceptando escrituras. Sin intervención manual en la base de datos, sin restaurar backups, sin reconfigurar redes. Ese es el poder del patrón Pilot Light."

---

## Al terminar el webinar

Elimina los health checks de Route 53 manualmente:
- Route 53 → Health checks → seleccionar ambos → Delete

Luego destruye desde Terraform Cloud:
- **Settings → Destruction and Deletion → Queue destroy plan**

---

## Tiempos de referencia

| Actividad | Tiempo estimado |
|---|---|
| Arrancar script e ingresar valores | 2 min |
| Verificar estado normal con la audiencia | 2 min |
| Paso 1 — simular desastre | 2 min |
| Paso 2 — promover Read Replica | 5 min |
| Paso 3 — apply en Terraform Cloud | 3 min |
| Paso 4 — validar y crear HC DR | 3 min |
| **RTO total de la demo** | **~15 min** |
