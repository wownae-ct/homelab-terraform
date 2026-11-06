# ──────────────────────────────────────
# DynamoDB — 알림 저장소
# ──────────────────────────────────────
resource "aws_dynamodb_table" "k8s_alerts" {
  name         = "k8s-alerts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Name = "k8s-alerts"
    Role = "alerting"
  })
}

# ──────────────────────────────────────
# IAM Role for Lambda
# ──────────────────────────────────────
resource "aws_iam_role" "lambda_discord" {
  name = "k8s-alerts-discord-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_discord.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "k8s-alerts-dynamodb-access"
  role = aws_iam_role.lambda_discord.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:Scan",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem"
      ]
      Resource = aws_dynamodb_table.k8s_alerts.arn
    }]
  })
}

# ──────────────────────────────────────
# Lambda — 수집 (SNS → DynamoDB)
# ──────────────────────────────────────
resource "aws_lambda_function" "alert_collector" {
  filename         = "${path.module}/lambda/alert_collector.zip"
  function_name    = "k8s-alert-collector"
  role             = aws_iam_role.lambda_discord.arn
  handler          = "alert_collector.handler"
  runtime          = "python3.12"
  timeout          = 15
  source_code_hash = filebase64sha256("${path.module}/lambda/alert_collector.zip")

  environment {
    variables = {
      DYNAMODB_TABLE      = aws_dynamodb_table.k8s_alerts.name
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }

  tags = merge(local.common_tags, {
    Name = "k8s-alert-collector"
    Role = "alerting"
  })
}

# ──────────────────────────────────────
# Lambda — 배치 전송 (EventBridge → Discord)
# ──────────────────────────────────────
resource "aws_lambda_function" "alert_batch_sender" {
  filename         = "${path.module}/lambda/alert_batch_sender.zip"
  function_name    = "k8s-alert-batch-sender"
  role             = aws_iam_role.lambda_discord.arn
  handler          = "alert_batch_sender.handler"
  runtime          = "python3.12"
  timeout          = 30
  source_code_hash = filebase64sha256("${path.module}/lambda/alert_batch_sender.zip")

  environment {
    variables = {
      DYNAMODB_TABLE      = aws_dynamodb_table.k8s_alerts.name
      DISCORD_WEBHOOK_URL = var.discord_webhook_url
    }
  }

  tags = merge(local.common_tags, {
    Name = "k8s-alert-batch-sender"
    Role = "alerting"
  })
}

# ──────────────────────────────────────
# SNS → Collector Lambda
# ──────────────────────────────────────
resource "aws_sns_topic_subscription" "discord_lambda" {
  topic_arn = aws_sns_topic.k8s_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.alert_collector.arn
}

resource "aws_lambda_permission" "sns_invoke" {
  statement_id  = "AllowSNSInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_collector.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.k8s_alerts.arn
}

# ──────────────────────────────────────
# EventBridge — 매일 KST 09:00 배치 전송
# ──────────────────────────────────────
resource "aws_cloudwatch_event_rule" "alert_batch" {
  name                = "k8s-alert-batch-daily"
  description         = "매일 KST 09:00 K8s 알림 배치 전송"
  schedule_expression = "cron(0 0 * * ? *)"
  tags = merge(local.common_tags, {
    Name = "k8s-alert-batch-daily"
    Role = "alerting"
  })
}

resource "aws_cloudwatch_event_target" "batch_lambda" {
  rule = aws_cloudwatch_event_rule.alert_batch.name
  arn  = aws_lambda_function.alert_batch_sender.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.alert_batch_sender.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.alert_batch.arn
}
