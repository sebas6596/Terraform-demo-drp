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

Una vez confirmados los tres valores, el script muestra:
```
✅ EC2 Primary IP  : 98.92.235.167
✅ EC2 Primary ID  : i-0124b11a8099bbba9
✅ RDS Replica ID  : dr-pilot-light-dr-mysql-replica
```

**Antes de presionar ENTER — mostrar a la audiencia:**

- Abre `http://<IP_PRIMARY>` en el browser → debe mostrar "Respondiendo desde: us-east-1"
- Consola AWS us-east-1 → EC2: instancia `dr-pilot-light-primary-web` en **running**
- Consola AWS us-east-1 → RDS: instancia `dr-pilot-light-primary-mysql` en **available**
- Consola AWS us-east-2 → EC2: **no hay ninguna instancia** ← este es el punto clave
- Consola AWS us-east-2 → RDS: réplica `dr-pilot-light-dr-mysql-replica` en **available**

**Mensaje clave para la audiencia:**
> "us-east-2 tiene la base de datos replicando en tiempo real, pero no tiene servidores. El código para crearlos existe, con count=0. Eso es exactamente el patrón Pilot Light."

Presiona ENTER para continuar.

---

## PASO 1 — Simular el desastre

El script pide confirmación para detener el EC2 primario. Confirma con `s`.

**Qué mostrar mientras el EC2 se detiene:**

- Consola AWS us-east-1 → EC2: la instancia cambia **running → stopping → stopped**
- Recarga el browser con `http://<IP_PRIMARY>` → debe mostrar timeout o error

**Mensaje clave para la audiencia:**
> "us-east-1 está caído. En un escenario real esto sería un fallo de región o un incidente mayor."

Presiona ENTER para continuar.

---

## PASO 2 — Promover la Read Replica

El script pide confirmación para promover la réplica. Confirma con `s`.

**Qué mostrar mientras se hace la promoción (tarda 2-5 minutos):**

- Consola AWS us-east-2 → RDS: el estado cambia **available → modifying → available**
- Cuando vuelva a **available**, el campo "Replication role" cambia de `Replica` a `Primary`

**Mensaje clave para la audiencia:**
> "La promoción convierte la réplica en una instancia primaria independiente que acepta escrituras. La replicación desde us-east-1 se rompe — us-east-2 toma el control total de los datos."

Presiona ENTER para continuar.

---

## PASO 3 — Activar el cómputo en DR (Terraform Cloud)

El script muestra las instrucciones y espera. Ve a Terraform Cloud y ejecuta:

1. **Variables** → edita `dr_ec2_enabled` → cambia `false` por `true` → Save
2. **Actions → Start new run** → Plan and apply → confirma el apply

**Qué mostrar mientras corre el apply:**

En Terraform Cloud, muestra el plan antes de aplicar:
```
Plan: 2 to add, 0 to change, 0 to destroy.
```

**Mensaje clave para la audiencia:**
> "Solo 2 recursos nuevos: el EC2 y su health check. Todo lo demás ya existía. El apply del failover es mínimo porque la infraestructura base del Pilot Light ya estaba corriendo."

Mientras corre el apply, muestra en la consola AWS us-east-2 → EC2:
- La instancia `dr-pilot-light-dr-web` aparece **pending → running**

Cuando el apply termine, copia la IP del EC2 DR desde los outputs del run (`dr_app_url`, sin http://).

Vuelve al script, presiona ENTER e ingresa la IP.

---

## PASO 4 — Validar el failover

El script hace curl automático hasta que nginx responde. Puede tardar ~60-90 segundos.

Cuando responda, abre `http://<IP_DR>` en el browser.

**La página debe mostrar:**
```
Respondiendo desde: us-east-2
Hostname: ip-10-1-x-x
```

**Checklist visual para la audiencia:**

| Qué verificar | Dónde | Estado esperado |
|---|---|---|
| App en browser | `http://<IP_DR>` | Muestra us-east-2 |
| EC2 DR | Consola AWS us-east-2 → EC2 | running |
| RDS DR | Consola AWS us-east-2 → RDS | available, role: Primary |
| EC2 Primary | Consola AWS us-east-1 → EC2 | stopped |

**Mensaje clave para la audiencia:**
> "En menos de 15 minutos pasamos de una región caída a tener la aplicación respondiendo desde la región DR con la base de datos activa. Ese es el RTO real del patrón Pilot Light."

---

## Al terminar el webinar

```bash
./destroy_all.sh
```

Escribe `DESTRUIR` cuando lo pida y confirma con `s`. Destruye toda la infraestructura en ambas regiones.

---

## Tiempos de referencia

| Actividad | Tiempo estimado |
|---|---|
| Ingresar valores y verificar estado normal | 2 min |
| Paso 1 — simular desastre | 2 min |
| Paso 2 — promover Read Replica | 5 min |
| Paso 3 — apply en Terraform Cloud | 3 min |
| Paso 4 — validar en browser | 2 min |
| **RTO total de la demo** | **~15 min** |
