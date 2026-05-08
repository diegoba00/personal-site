# SNS: Simple Notification Service — sistema de alertas
# ¿Por qué?
# - CloudWatch detecta problemas pero no te avisa
# - SNS envía email automático cuando algo está mal
# - Sin SNS: tendrías que revisar CloudWatch manualmente 24/7
# - Costo: GRATIS (primeros 1000 emails/mes)
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

# Suscripción a email
# ¿Por qué?
# - SNS tópico existe pero nadie lo escucha
# - Esta suscripción: "envía alertas a diego@example.com"
# - NOTA: AWS te pide confirmar por email la primera vez
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarm 1: Tráfico anormal (posible bot/scraper)
# ¿Por qué?
# - period = 3600 (1 hora)
# - threshold = 10 invocaciones (configurable)
# - Si Lambda se invoca >10 veces en 1 hora: alarma
# - Escenario: bot hace 1000 requests/min
#   → Lambda invocaciones suben de 0 a 1000
#   → Alarm se dispara
#   → Te llega email
#   → Tienes tiempo para reaccionar
# Sin esto: Bot ataca silenciosamente hasta factura de $100
resource "aws_cloudwatch_metric_alarm" "high_visitors" {
  alarm_name          = "${var.project_name}-high-visitors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Invocations"
  namespace           = "AWS/Lambda"
  period              = 3600
  statistic           = "Sum"
  threshold           = var.visitor_alarm_threshold
  alarm_description   = "More than ${var.visitor_alarm_threshold} visits in 1 hour — possible bot or scraper"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
  }
}

# Alarm 2: Lambda errores
# ¿Por qué?
# - period = 300 (5 minutos)
# - threshold = 5 errores
# - Si Lambda crashea 5+ veces en 5 minutos: alarma
# - Escenario: DynamoDB está down
#   → Lambda intenta escribir, falla
#   → Error logs se registran
#   → Después de 5 errores: email
# Sin esto: Sitio está roto y no sabes por qué
# treat_missing_data = "notBreaching": si no hay data, NO alarmar (evita falsos positivos)
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project_name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda function has ${var.lambda_function_name} errors — check logs"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = var.lambda_function_name
  }
}

# Alarm 3: Ataques posibles (errores 4xx)
# ¿Por qué?
# - 4xx = "Bad Request" (cliente hizo algo mal)
# - Scenarios:
#   - 429 = Rate-limited (bot intentó hacer mucho tráfico, rechazado) ✅ BUENO
#   - 400 = Malformed request (bot intenta inyectar SQL, etc) ⚠️ ATAQUE
# - threshold = 50 errores 4xx en 5 minutos
# - Si bot intenta ataques SQL injection 50+ veces: alarma
# Sin esto: Ataques pasan desapercibidos
resource "aws_cloudwatch_metric_alarm" "api_gateway_client_errors" {
  alarm_name          = "${var.project_name}-api-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 50
  alarm_description   = "High rate of client errors (4xx) — possible attacks"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiId = var.api_id
  }
}
