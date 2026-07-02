#!/bin/bash
# =============================================================================
# user_data.sh.tpl — Script de arranque para EC2
# Se ejecuta UNA VEZ al lanzar la instancia.
# La variable ${region} es inyectada por Terraform via templatefile()
# =============================================================================

set -e

dnf update -y
dnf install -y nginx

HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S UTC')

cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DR Pilot Light Demo</title>
    <style>
        body {
            font-family: 'Courier New', monospace;
            background: #1a1a2e;
            color: #e0e0e0;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
        }
        .container {
            background: #16213e;
            border: 2px solid #0f3460;
            border-radius: 8px;
            padding: 40px 60px;
            text-align: center;
            box-shadow: 0 0 30px rgba(15,52,96,0.5);
        }
        h1  { color: #e94560; font-size: 2em; margin-bottom: 10px; }
        .status { color: #00d4aa; font-size: 1.3em; margin: 20px 0; }
        .info   { color: #a0a0b0; font-size: 0.95em; line-height: 2em; }
        .region { color: #f5a623; font-weight: bold; font-size: 1.1em; }
        .badge  { display: inline-block; background: #0f3460; padding: 4px 12px; border-radius: 4px; margin: 4px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔥 DR Pilot Light Demo</h1>
        <div class="status">✅ Sistema operativo</div>
        <div class="info">
            <div>Respondiendo desde: <span class="region">${region}</span></div>
            <div>Hostname: <span class="badge">$HOSTNAME</span></div>
            <div>Timestamp: <span class="badge">$TIMESTAMP</span></div>
        </div>
        <br>
        <div style="color:#666;font-size:0.8em;">AWS Disaster Recovery — Patrón Pilot Light</div>
    </div>
</body>
</html>
EOF

systemctl enable nginx
systemctl start nginx
