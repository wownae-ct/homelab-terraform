import json
import os
import boto3
import urllib.request
import uuid
from datetime import datetime, timezone, timedelta

KST = timezone(timedelta(hours=9))
dynamodb = boto3.resource("dynamodb")

SEVERITY_CONFIG = {
    "critical": {"color": 0xFF0000, "icon": "🔴", "label": "CRITICAL"},
    "warning":  {"color": 0xFFA500, "icon": "🟠", "label": "WARNING"},
    "info":     {"color": 0x3498DB, "icon": "🔵", "label": "INFO"},
    "none":     {"color": 0x95A5A6, "icon": "⚪", "label": "NONE"},
}

ALERT_ICONS = {
    "KubeNodeNotReady":    "🖥️",
    "KubePodCrashLooping": "💥",
    "TargetDown":          "📡",
    "KubeProxyDown":       "🌐",
    "KubeDeploymentReplicasMismatch": "⚖️",
    "KubePodNotReady":     "⏳",
    "KubeContainerWaiting": "🔄",
}

RESOLVED_COLOR = 0x2ECC71


def send_discord(webhook_url, alert):
    labels = alert.get("labels", {})
    annotations = alert.get("annotations", {})
    alertname = labels.get("alertname", "Unknown")
    severity = labels.get("severity", "none")
    status = alert.get("status", "firing")
    now = datetime.now(KST).strftime("%Y-%m-%d %H:%M:%S KST")

    if status == "resolved":
        color = RESOLVED_COLOR
        status_text = "✅ **RESOLVED**"
    else:
        cfg = SEVERITY_CONFIG.get(severity, SEVERITY_CONFIG["none"])
        color = cfg["color"]
        status_text = f"{cfg['icon']} **{cfg['label']}**"

    alert_icon = ALERT_ICONS.get(alertname, "🚨")
    fields = [
        {"name": "상태", "value": status_text, "inline": True},
        {"name": "심각도", "value": f"`{severity}`", "inline": True},
        {"name": "네임스페이스", "value": f"`{labels.get('namespace', 'N/A')}`", "inline": True},
    ]
    if annotations.get("summary"):
        fields.append({"name": "📋 요약", "value": annotations["summary"][:256], "inline": False})
    if annotations.get("description"):
        fields.append({"name": "📝 상세", "value": annotations["description"][:512], "inline": False})

    payload = {
        "username": "K8s Alertmanager",
        "avatar_url": "https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png",
        "embeds": [{
            "title": f"{alert_icon} {alertname}",
            "color": color,
            "fields": fields,
            "footer": {"text": f"K8s Alertmanager • {now}"},
        }],
    }
    req = urllib.request.Request(
        webhook_url,
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Content-Type": "application/json",
            "User-Agent": "K8sAlertmanager/1.0",
        },
    )
    urllib.request.urlopen(req)


def handler(event, context):
    table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
    webhook_url = os.environ["DISCORD_WEBHOOK_URL"]
    now = datetime.now(KST)
    ttl = int((now + timedelta(hours=24)).timestamp())

    for record in event.get("Records", []):
        message = record["Sns"]["Message"]
        print(f"RAW_SNS_MESSAGE: {message[:2000]}")

    for record in event.get("Records", []):
        message = record["Sns"]["Message"]
        try:
            data = json.loads(message)
            alerts = data if isinstance(data, list) else [data]
        except (json.JSONDecodeError, TypeError):
            alerts = [{"labels": {"alertname": "RawMessage"}, "annotations": {"description": message}, "status": "firing"}]

        for alert in alerts:
            labels = alert.get("labels", {})
            severity = labels.get("severity", "none")
            status = alert.get("status", "firing")
            alertname = labels.get("alertname", "Unknown")

            # critical 또는 resolved 여부 판단
            is_immediate = severity == "critical" or status == "resolved"

            # DynamoDB에 저장 (즉시 전송한 건 sent_in_batch=True)
            table.put_item(Item={
                "id": str(uuid.uuid4()),
                "alertname": alertname,
                "severity": severity,
                "status": status,
                "namespace": labels.get("namespace", "N/A"),
                "job": labels.get("job", "N/A"),
                "summary": alert.get("annotations", {}).get("summary", ""),
                "timestamp": now.isoformat(),
                "ttl": ttl,
                "sent_in_batch": is_immediate,
            })

            # critical 또는 resolved는 즉시 전송
            if is_immediate:
                send_discord(webhook_url, alert)

    return {"statusCode": 200}
