#!/usr/bin/env bash
set -euo pipefail

PROJECT="back-pay-calc"

echo "Tearing down load balancer stack for project: $PROJECT"

echo "1/7 Deleting forwarding rule..."
gcloud compute forwarding-rules delete back-pay-calc-https-fwd \
  --global --project "$PROJECT" --quiet

echo "2/7 Deleting HTTPS proxy..."
gcloud compute target-https-proxies delete back-pay-calc-https-proxy \
  --global --project "$PROJECT" --quiet

echo "3/7 Deleting SSL certificate..."
gcloud compute ssl-certificates delete back-pay-calc-cert \
  --project "$PROJECT" --quiet

echo "4/7 Deleting URL map..."
gcloud compute url-maps delete back-pay-calc-urlmap \
  --global --project "$PROJECT" --quiet

echo "5/7 Deleting backend service..."
gcloud compute backend-services delete back-pay-calc-backend \
  --global --project "$PROJECT" --quiet

echo "6/7 Deleting serverless NEG..."
gcloud compute network-endpoint-groups delete back-pay-calc-neg \
  --region europe-west1 --project "$PROJECT" --quiet

echo "7/7 Releasing reserved static IP..."
gcloud compute addresses delete back-pay-calc-ip \
  --global --project "$PROJECT" --quiet

echo "Done. Load balancer stack fully removed."
