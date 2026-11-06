#!/usr/bin/env bash
# Lambda 배포 zip을 만듭니다. (terraform plan/apply 전에 실행)
set -euo pipefail
cd "$(dirname "$0")/../modules/aws/lambda"
for name in alert_collector alert_batch_sender; do
  rm -f "${name}.zip"
  zip -q "${name}.zip" "${name}.py"
  echo "built ${name}.zip"
done
