# Manual de Failover — DR Pilot Light Demo
### Webinar: Disaster Recovery en AWS con Terraform

---

## Antes de empezar

Confirma que tienes abierto en pantalla:
- Terminal con el proyecto clonado
- Consola AWS en us-east-1 (una pestaña)
- Consola AWS en us-east-2 (otra pestaña)
- Terraform Cloud workspace
- Browser para verificar la app

---

## PASO 0 — Verificar estado normal

**Qué ejecutar:**
```bash
./failover.sh
```
El script arranca y muestra el estado inicial. Presiona ENTER para continuar.

**Qué mostrar a la audiencia:**

Abre el browser con la URL del EC2 primario (la tienes en los outputs de Terraform Cloud).

La página debe mostrar:
```
Respondiendo desde: us-east-1
Hostname: ip-10-0-x-x
```

En la consola AWS us-east-1, muestra:
- EC2 → instancia `dr-pilot-light-primary-web` en estado **running**
- RDS → instancia `dr-pilot-light-primary-mysql` en estado **available**

En la consola AWS us-east-2, muestra:
- RDS → instancia `dr-pilot-light-dr-mysql-replica` en estado **available** (es la réplica corriendo)
- EC2 → **no hay ninguna instancia** (esto es el Pilot Light: el cómputo no existe)

**Mensaje clave para la audiencia:**
> "us-east-2 tiene la base de datos replicando en tiempo real, pero no tiene servidores corriendo. El código para crearlos existe, simplemente tiene count=0. Eso es exactamente el patrón Pilot Light."

---

## PASO 1 — Simular el desastre

**Qué ejecutar:**

El script te pedirá confirmación para detener el EC2 primario via AWS CLI. Confirma con `s`.

```
¿Detener el EC2 primario en us-east-1? (s/n): s
```

**Qué mostrar a la audiencia:**

En la consola AWS us-east-1:
- EC2 → la instancia cambia de **running** a **stopping** y luego **stopped**

Intenta recargar el browser con la URL de us-east-1 — debe mostrar timeout o error de conexión.

Muestra el health check de Route 53:
- AWS Console → Route 53 → Health checks
- El health check primario cambia de **Healthy** a **Unhealthy** en ~90 segundos

**Mensaje clave para la audiencia:**
> "us-east-1 está caído. En un escenario real esto sería un fallo de región, un incidente mayor o una corrupción de datos. El health check ya detectó la falla."

---

## PASO 2 — Promover la Read Replica

**Qué ejecutar:**

El script te pedirá confirmación para promover la Read Replica. Confirma con `s`.

```
¿Promover 'dr-pilot-light-dr-mysql-replica' a instancia primaria? (s/n): s
```

El script ejecuta internamente:
```bash
aws rds promote-read-replica \
  --db-instance-identifier dr-pilot-light-dr-mysql-replica \
  --region us-east-2
```

**Qué mostrar a la audiencia:**

En la consola AWS us-east-2 → RDS:
- El estado de la réplica cambia: **available** → **modifying** → **available**
- El campo **Replication role** cambia de `Replica` a `Primary` (puede tardar 2-5 minutos)

Mientras espera, explica:

> "La promoción convierte la réplica en una instancia primaria independiente. A partir de este momento acepta escrituras. La replicación desde us-east-1 se rompe, que es exactamente lo que queremos: us-east-2 toma el control."

Cuando el estado vuelva a **available**, muestra que ya no aparece el campo "Replication source" — confirmación visual de que es primaria independiente.

Presiona ENTER para continuar al paso 3.

---

## PASO 3 — Activar el cómputo en DR (Terraform Cloud)

**Qué ejecutar:**

El script muestra las instrucciones y espera. Ahora vas a Terraform Cloud.

En el workspace `dr-pilot-light`:
1. Ve a **Variables**
2. Edita `dr_ec2_enabled` → cambia el valor de `false` a `true` → **Save**
3. Ve a **Actions → Start new run**
4. Selecciona **Plan and apply** → escribe un mensaje como `failover: activate DR compute` → **Start run**
5. Espera que el plan termine y haz clic en **Confirm & apply**

**Qué mostrar a la audiencia:**

En Terraform Cloud, muestra el plan antes de aplicar. Debe mostrar exactamente:
```
Plan: 2 to add, 0 to change, 0 to destroy.
```
Los dos recursos nuevos son: la instancia EC2 y el Route 53 health check DR.

> "Fíjense: Terraform solo agrega 2 recursos. Todo lo demás ya existía. Eso es la potencia del Pilot Light — el apply del failover es mínimo porque la infraestructura base ya estaba."

Mientras corre el apply, muestra en la consola AWS us-east-2 → EC2:
- La instancia `dr-pilot-light-dr-web` aparece en estado **pending** → **running**

Cuando el apply termine en Terraform Cloud, copia la IP pública del EC2 DR desde los outputs del run y vuelve al script. Presiona ENTER e ingresa la IP.

---

## PASO 4 — Validar el failover

**Qué verificar:**

El script hace un curl automático a la IP del EC2 DR esperando que nginx responda. Puede tardar hasta 60-90 segundos mientras el `user_data` termina de instalar nginx.

Cuando responda, abre el browser con `http://<IP-DR>`.

La página debe mostrar:
```
Respondiendo desde: us-east-2
Hostname: ip-10-1-x-x
```

**Qué mostrar a la audiencia — checklist visual:**

| Qué verificar | Dónde | Estado esperado |
|---|---|---|
| App respondiendo | Browser | Muestra us-east-2 |
| EC2 DR | Consola AWS us-east-2 → EC2 | running |
| RDS DR | Consola AWS us-east-2 → RDS | available, role: Primary |
| EC2 Primary | Consola AWS us-east-1 → EC2 | stopped |
| Health check primario | Route 53 → Health checks | Unhealthy |

**Mensaje clave para la audiencia:**
> "En menos de 10 minutos pasamos de una región caída a tener la aplicación respondiendo desde la región DR. La base de datos está activa y acepta escrituras. Esto es el RTO real del patrón Pilot Light."

---

## Al terminar el webinar

```bash
./destroy_all.sh
```

Escribe `DESTRUIR` cuando lo pida y confirma con `s`. El script vacía los buckets S3 y destruye toda la infraestructura en ambas regiones.

Verifica en la consola AWS que no quede ningún recurso en us-east-1 ni us-east-2.

---

## Tiempos de referencia

| Actividad | Tiempo estimado |
|---|---|
| Paso 0 → verificar estado normal | 2 min |
| Paso 1 → simular desastre + health check | 3 min |
| Paso 2 → promover Read Replica | 5 min |
| Paso 3 → apply en Terraform Cloud | 3 min |
| Paso 4 → validar en browser | 2 min |
| **RTO total de la demo** | **~15 min** |
