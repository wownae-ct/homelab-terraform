import json
import os
import boto3
import urllib.request
from datetime import datetime, timezone, timedelta
from collections import Counter

KST = timezone(timedelta(hours=9))
dynamodb = boto3.resource("dynamodb")

SEVERITY_CONFIG = {
    "critical": {"color": 0xFF0000, "icon": "🔴"},
    "warning":  {"color": 0xFFA500, "icon": "🟠"},
    "info":     {"color": 0x3498DB, "icon": "🔵"},
    "none":     {"color": 0x95A5A6, "icon": "⚪"},
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


def handler(event, context):
    table = dynamodb.Table(os.environ["DYNAMODB_TABLE"])
    webhook_url = os.environ["DISCORD_WEBHOOK_URL"]
    now = datetime.now(KST)

    # 미전송 알림 조회
    response = table.scan(
        FilterExpression=boto3.dynamodb.conditions.Attr("sent_in_batch").eq(False)
    )
    items = response.get("Items", [])

    if not items:
        return {"statusCode": 200, "body": "No pending alerts"}

    # 알림 집계
    alert_counter = Counter()
    severity_counter = Counter()
    namespaces = set()
    alerts_by_name = {}

    for item in items:
        name = item["alertname"]
        sev = item.get("severity", "none")
        alert_counter[name] += 1
        severity_counter[sev] += 1
        namespaces.add(item.get("namespace", "N/A"))

        if name not in alerts_by_name:
            alerts_by_name[name] = {
                "severity": sev,
                "summary": item.get("summary", ""),
                "namespace": item.get("namespace", "N/A"),
            }

    # 요약 embed 구성
    total = len(items)
    period_start = min(item["timestamp"] for item in items)
    period_end = now.strftime("%Y-%m-%d %H:%M KST")

    # 심각도 요약
    severity_lines = []
    for sev in ["critical", "warning", "info", "none"]:
        count = severity_counter.get(sev, 0)
        if count > 0:
            cfg = SEVERITY_CONFIG.get(sev, SEVERITY_CONFIG["none"])
            severity_lines.append(f"{cfg['icon']} {sev.upper()}: **{count}건**")
    severity_text = "\n".join(severity_lines) if severity_lines else "없음"

    # 알림별 상세
    detail_lines = []
    for name, count in alert_counter.most_common(10):
        icon = ALERT_ICONS.get(name, "🚨")
        info = alerts_by_name[name]
        detail_lines.append(f"{icon} **{name}** — {count}건 (`{info['namespace']}`)")

    detail_text = "\n".join(detail_lines) if detail_lines else "없음"

    # 최종 색상 결정
    if severity_counter.get("critical", 0) > 0:
        embed_color = 0xFF0000
    elif severity_counter.get("warning", 0) > 0:
        embed_color = 0xFFA500
    else:
        embed_color = 0x3498DB

    payload = {
        "username": "K8s Alertmanager",
        "avatar_url": "https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.png",
        "embeds": [{
            "title": f"📊 K8s 알림 요약 리포트 ({total}건)",
            "color": embed_color,
            "fields": [
                {"name": "📅 집계 기간", "value": f"`{period_start}` ~\n`{period_end}`", "inline": False},
                {"name": "🏷️ 심각도 분포", "value": severity_text, "inline": True},
                {"name": "📍 네임스페이스", "value": ", ".join(f"`{ns}`" for ns in sorted(namespaces)), "inline": True},
                {"name": "📋 알림 상세", "value": detail_text, "inline": False},
            ],
            "footer": {"text": f"K8s Alertmanager Batch Report • {period_end}"},
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

    # 전송 완료 마킹
    for item in items:
        table.update_item(
            Key={"id": item["id"]},
            UpdateExpression="SET sent_in_batch = :val",
            ExpressionAttributeValues={":val": True},
        )

    return {"statusCode": 200, "body": f"Sent batch report: {total} alerts"}
