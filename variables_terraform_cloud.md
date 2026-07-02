# Variables a configurar en Terraform Cloud

Ve a tu workspace → **Variables** y agrega las siguientes.

---

## Variables de credenciales AWS (Environment Variables)

Estas van como **Environment Variables** (no Terraform Variables) y deben marcarse como **Sensitive**.

| Key | Value | Sensitive |
|-----|-------|-----------|
| `AWS_ACCESS_KEY_ID` | Tu Access Key ID | ✅ |
| `AWS_SECRET_ACCESS_KEY` | Tu Secret Access Key | ✅ |
| `AWS_SESSION_TOKEN` | Solo si usas credenciales temporales (SSO/AssumeRole) | ✅ |

> Si usas un IAM Role en el workspace de Terraform Cloud (recomendado), no necesitas estas variables. Configura el rol en **Settings → Authentication**.

---

## Variables Terraform (Terraform Variables)

Estas van como **Terraform Variables**. Las sensibles deben marcarse como **Sensitive**.

| Variable | Tipo | Sensitive | Valor |
|----------|------|-----------|-------|
| `db_password` | string | ✅ | Password seguro para MySQL |
| `s3_primary_bucket_name` | string | ❌ | `dr-pilot-light-primary-<TU_ACCOUNT_ID>` |
| `s3_replica_bucket_name` | string | ❌ | `dr-pilot-light-replica-<TU_ACCOUNT_ID>` |
| `dr_ec2_enabled` | bool | ❌ | `false` (cambiar a `true` en el failover) |

---

## Variable clave para el failover

Durante la demo, el único cambio necesario es:

1. Ir al workspace en Terraform Cloud
2. Editar la variable `dr_ec2_enabled` → cambiar a `true`
3. Ejecutar un nuevo plan y aplicar

Eso es todo el failover de cómputo.
