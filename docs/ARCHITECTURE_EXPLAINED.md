# Arquitectura Personal Site - Explicación Práctica

## El Problema que Resolvemos

Quieres un sitio web personal que:
- ✅ Sea rápido en cualquier parte del mundo
- ✅ Cuente visitantes
- ✅ Sea seguro (sin exponer datos sensibles)
- ✅ Sea económico (free tier de AWS)

---

## Arquitectura - Componentes y Por Qué

### 1. **S3 (Simple Storage Service)** 📁
**¿Qué es?** Base de datos de archivos en la nube

**¿Por qué lo usamos?**
- Almacena `index.html`, `styles.css`, etc
- Muy barato (5GB gratis/mes)
- Integra con CloudFront para servir rápido

**¿Sin S3 qué pasaría?**
- Tendrías que tener un servidor tradicional (Linux, Apache, etc) corriendo 24/7
- Costo: $5-20/mes mínimo
- Mantenimiento: actualizaciones, parches, reinicis

**Configuración:**
```terraform
# Privado - solo CloudFront puede leer
resource "aws_s3_bucket_public_access_block" "website" {
  block_public_acls = true
  block_public_policy = true
}
```

---

### 2. **CloudFront (CDN)** 🚀
**¿Qué es?** Red global que copia tu contenido en 200+ servidores mundiales

**¿Por qué lo usamos?**
- Usuario en Tokyo → obtiene contenido del servidor de Tokyo (10ms vs 200ms)
- Compresión automática (reduce tamaño de archivos)
- Cachea el contenido (reduce carga a S3)
- SSL/HTTPS gratis

**¿Sin CloudFront qué pasaría?**
- Todos obtienen contenido desde un solo datacenter (ej: Virginia)
- Usuario en Australia: 250ms+ latencia
- Página carga lenta → abandona el sitio

**Analogía real:**
- Sin CDN: Tienda central en CABA, todos van allá
- Con CDN: Tiendas en CABA, Córdoba, Mendoza, etc. → todos compran más rápido

**Configuración en código:**
```terraform
# Copia en 100 locations, no todas (ahorras costo)
price_class = "PriceClass_100"  # North America, Europe, Asia
```

---

### 3. **Lambda** ⚡
**¿Qué es?** Función de código que corre "cuando la necesitas"

**¿Por qué lo usamos?**
- Endpoint `/visitors` necesita contar visitas
- Lambda se ejecuta SOLO cuando alguien accede
- Costo: $0.20 por 1 millón de invocaciones (es decir, gratis para tu sitio)

**¿Sin Lambda qué pasaría?**
- Necesitarías un servidor Node.js/Python corriendo 24/7
- Costo: $5-15/mes mínimo
- Incluso si nadie visita, pagas igual

**Analogía:**
- Servidor tradicional: Mesero trabajando 24/7, gane o no gane
- Lambda: Mesero que aparece SOLO cuando llega cliente, cobra por hora trabajada

**Código del handler (Python):**
```python
# Recibe request → incrementa contador → responde
response = table.update_item(
    Key={"id": "visitors"},
    UpdateExpression="ADD visit_count :inc",  # +1 al contador
    ExpressionAttributeValues={":inc": 1},
    ReturnValues="UPDATED_NEW",  # Retorna valor nuevo
)
```

---

### 4. **DynamoDB** 📊
**¿Qué es?** Base de datos de NoSQL (clave-valor)

**¿Por qué lo usamos?**
- Almacena contador de visitantes
- Pay-per-request: pagas SOLO por lo que usas
- 25 GB gratis/mes (más que suficiente)
- Sin mantenimiento (AWS gestiona todo)

**¿Sin DynamoDB qué pasaría?**
- Lambda escribiría en un archivo en S3: LENTÍSIMO
- O en una BD SQL tradcional: complejo, caro, requiere mantenimiento

**Cómo funciona:**
```
Estructura de datos:
┌─────────────┬──────────────┐
│ id (clave)  │ visit_count  │
├─────────────┼──────────────┤
│ "visitors"  │ 42           │
└─────────────┴──────────────┘

Cuando llega request: visit_count = 42 + 1 = 43
```

---

### 5. **API Gateway** 🔌
**¿Qué es?** Puerta de entrada que mapea HTTP requests a Lambda

**¿Por qué lo usamos?**
- Frontend no puede llamar Lambda directamente
- API Gateway expone Lambda como endpoint HTTP: `GET /visitors`
- Rate-limiting integrado (protege contra bots)
- CORS integrado (permite requests desde tu dominio)

**¿Sin API Gateway qué pasaría?**
- Necesitarías configurar un proxy manual
- O exponer Lambda directamente (inseguro)

**Flujo:**
```
1. Frontend: fetch("https://api.example.com/visitors")
2. API Gateway recibe GET /visitors
3. Invoca Lambda
4. Lambda retorna {"visitors": 42}
5. API Gateway responde al cliente
```

**Rate-limiting configurado:**
```terraform
throttling_rate_limit = 2      # máx 2 req/seg
throttling_burst_limit = 5     # tolera spike de 5 req
```

Si alguien intenta hacer 100 requests/sec → API Gateway devuelve 429 (Too Many Requests)

---

### 6. **CloudWatch** 📈
**¿Qué es?** Sistema de monitoreo y logging

**¿Por qué lo usamos?**
- **Logs**: Registra qué hace Lambda (errores, debug)
- **Metrics**: Cuenta cuántas veces Lambda fue invocada
- **Alarms**: Alerta si algo sale mal

**¿Sin CloudWatch qué pasaría?**
- Lambda crashea y no sabes por qué
- Un bot ataca tu contador y no te enteras
- Pagas $100 sin saber dónde

**Ejemplo real:**
```
Bot hace 1000 requests/min al contador
↓
DynamoDB recibe 1000 writes/min
↓
CloudWatch Alarm detecta anomalía
↓ 
Te envía email: "⚠️ Tráfico anormal en Lambda"
↓
Tienes tiempo de reaccionar
```

**Sin CloudWatch:**
- Solo te enteras cuando llega la factura de AWS: $100
- Ya es tarde

---

### 7. **SNS (Simple Notification Service)** 📧
**¿Qué es?** Sistema de notificaciones

**¿Por qué lo usamos?**
- CloudWatch alarm → envía email automático
- Te alertas en tiempo real de problemas

**Flujo:**
```
Alarm se dispara
↓
SNS tópico "alerts"
↓
Email a diego@example.com
↓
"⚠️ Lambda errors detected: 5 errors en 5 min"
```

---

## Flujo Completo: Un Visitante

```
1. Usuario abre https://d7m6q6tk9m4xj.cloudfront.net/
2. CloudFront:
   - Revisa si tiene HTML cacheado → SÍ → devuelve
   - (latencia: 50ms desde servidor más cercano)
3. HTML carga y ejecuta: fetch("/api/visitors")
4. API Gateway recibe GET /visitors
5. API Gateway verifica rate-limit (¿menos de 2 req/sec?) → SÍ
6. Invoca Lambda
7. Lambda:
   - Conecta a DynamoDB
   - Lee: visit_count = 42
   - Escribe: visit_count = 43
   - Retorna JSON: {"visitors": 43}
8. API Gateway responde al frontend
9. Frontend muestra: "Visitas: 43"
10. CloudWatch registra: "Lambda invocation successful"
```

**Tiempo total: ~200ms**

Sin esta arquitectura (con servidor tradicional):
- Mismo resultado: ~500ms-1s
- Costo: $10-20/mes
- Complejidad: configurable, actualizaciones, backups

Con esta arquitectura:
- Resultado: ~200ms
- Costo: $0 (free tier)
- Complejidad: 0 (AWS lo gestiona)

---

## Costo Real

| Recurso | Free Tier | ¿Es suficiente? |
|---------|-----------|-----------------|
| S3 | 5 GB | ✅ Sí (tu site es <1MB) |
| CloudFront | 1 TB salida | ✅ Sí (100K visitas = 100 MB) |
| Lambda | 1M invocaciones | ✅ Sí (100 visitas/día = 3K/mes) |
| DynamoDB | 25 GB | ✅ Sí (1 número entero) |
| SNS | 1000 emails | ✅ Sí (alertas ocasionales) |
| API Gateway | 1M requests | ✅ Sí |

**Total: $0 mientras no excedas estos límites**

Si tu sitio "explota" y recibe 1 millón de visitas/mes, costo máximo: ~$5-10

---

## Seguridad: Por Qué Cada Decisión

### ✅ S3 Privado
**¿Por qué?**
```
Opción 1: S3 público
- Cualquiera podría listar archivos
- Alguien podría eliminar contenido
- MALO

Opción 2: S3 privado + CloudFront
- CloudFront tiene credenciales para acceder
- Usuario normal no puede acceder directo a S3
- SEGURO ✅
```

### ✅ CORS Restrictivo
**¿Por qué?**
```
Sin restricción: allow_origins = ["*"]
- Cualquier sitio (attacker.com) puede llamar tu API
- Pueden hacer flood del contador
- Aparentas tener 1 millón de visitas
- Factura sube

Con restricción: allow_origins = ["https://diegoayala.click"]
- Solo TU dominio puede llamar
- Bot en attacker.com → request rechazada
- Protegido ✅
```

### ✅ Rate-Limiting
**¿Por qué?**
```
Sin rate-limiting:
- Bot hace 1000 requests/segundo
- DynamoDB costo: $500/mes
- Te enteras cuando llega factura

Con rate-limiting (2 req/sec):
- Bot hace 1000 requests/segundo
- API Gateway rechaza requests después del 2do
- Costo: $0
- Estás protegido ✅
```

---

## Conclusión

Cada recurso está ahí porque:
1. Resuelve un problema específico
2. Es el más económico para ese problema
3. Requiere mínimo mantenimiento
4. Tiene protecciones de seguridad integradas

**TL;DR:**
- S3 + CloudFront = web rápida, global, barata
- Lambda + DynamoDB = contador sin servidor corriendo
- API Gateway = control de acceso
- CloudWatch + SNS = te alertas si algo sale mal

Sin esta arquitectura pagarías $50-100/mes mínimo. Con ella: $0 🚀
