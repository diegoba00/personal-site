# DynamoDB: Base de datos para el contador de visitantes
# ¿Por qué DynamoDB?
# - Pay-per-request: pagas SOLO por requests (no por servidores corriendo 24/7)
# - Sin mantenimiento: AWS gestiona backups, replicación, etc
# - Rápido: responde en <100ms incluso bajo carga
# ¿Qué sería la alternativa? Servidor SQL tradicional + mantenimiento + costo fijo
resource "aws_dynamodb_table" "visitors" {
  name         = "${var.project_name}-visitors"
  billing_mode = "PAY_PER_REQUEST"  # Paga por uso, no por capacidad reservada
  hash_key     = "id"               # Clave primaria: "visitors"

  attribute {
    name = "id"
    type = "S"  # String
  }
}

# IAM Role para Lambda
# ¿Por qué IAM role?
# - Seguridad: Lambda NO tiene acceso a TODO en AWS
# - Principio de menor privilegio: solo acceso a lo que necesita (DynamoDB + logs)
# - Si alguien compromete Lambda, solo puede acceder a estos recursos, no a toda tu cuenta
resource "aws_iam_role" "lambda" {
  name = "${var.project_name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Política IAM: Lambda solo puede hacer GetItem + UpdateItem en la tabla de visitantes
# ¿Por qué estas específicas?
# - GetItem: leer el contador actual (aunque no lo hacemos explícitamente, UpdateItem retorna el valor)
# - UpdateItem: incrementar el contador
# Lambda NO puede: deletear, crear tablas, acceder a otro recurso, etc
resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "dynamodb-access"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:UpdateItem"
      ]
      Resource = aws_dynamodb_table.visitors.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/function/handler.py"
  output_path = "${path.module}/function/handler.zip"
}

# Lambda: Función serverless que incrementa el contador
# ¿Por qué Lambda?
# - Pagas SOLO cuando se ejecuta (no 24/7)
# - 1 millón de ejecuciones = ~$0.20 (gratis en free tier)
# - Sin servidor que mantener
# - Se escala automáticamente (si llegan 1000 requests/seg, Lambda crea 1000 instancias)
# ¿Qué pasaría sin Lambda? Servidor Node/Python corriendo $15/mes mínimo
resource "aws_lambda_function" "visitors" {
  filename         = data.archive_file.lambda.output_path
  function_name    = "${var.project_name}-visitors"
  role             = aws_iam_role.lambda.arn
  handler          = "handler.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitors.name
    }
  }
}

# API Gateway v2 (HTTP API): Puerta de entrada a Lambda
# ¿Por qué API Gateway?
# - No puedes llamar Lambda directamente desde el navegador
# - API Gateway expone Lambda como endpoint HTTP REST
# - Rate-limiting integrado (protege contra bots)
# - CORS integrado (controla qué dominios pueden acceder)
# ¿Qué pasaría sin API Gateway? Necesitarías un proxy manual o exponer Lambda inseguramente
resource "aws_apigatewayv2_api" "visitors" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = concat(
      var.allowed_origins,
      ["https://d7m6q6tk9m4xj.cloudfront.net"]  # CloudFront default mientras no esté el dominio
    )
    allow_methods = ["GET"]
    allow_headers = ["Content-Type"]
  }
}

resource "aws_apigatewayv2_integration" "visitors" {
  api_id                 = aws_apigatewayv2_api.visitors.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.visitors.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "visitors" {
  api_id    = aws_apigatewayv2_api.visitors.id
  route_key = "GET /visitors"
  target    = "integrations/${aws_apigatewayv2_integration.visitors.id}"
}

# API Stage: Versión desplegada del API con rate-limiting
# ¿Por qué rate-limiting?
# - Sin esto: bot hace 10000 requests/seg → DynamoDB factura $500+
# - Con esto: bot hace 10000 requests/seg → rechazado después del 5to → costo: $0
# - rate_limit = 2: máximo 2 requests/segundo por cliente
# - burst_limit = 5: permite picos de hasta 5 requests antes de throttle
resource "aws_apigatewayv2_stage" "visitors" {
  api_id      = aws_apigatewayv2_api.visitors.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 2
    throttling_burst_limit = 5
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitors.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitors.execution_arn}/*/*"
}
