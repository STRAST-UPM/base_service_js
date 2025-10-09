#!/bin/bash
set -e

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
PREFIX="anycastprivacy"

echo "Cleaning resources in project: $PROJECT_ID"
echo "====================================="

# ========================
# 1. Delete forwarding rules
# ========================
echo "Deleting forwarding rules..."
for rule in $(gcloud compute forwarding-rules list --global --format="value(name)" | grep "$PREFIX"); do
    echo "Deleting forwarding rule: $rule"
    gcloud compute forwarding-rules delete "$rule" --global --quiet || true
    echo "Forwarding rule $rule deleted"
done
echo "Forwarding rules deletion complete."

# ========================
# 2. Delete HTTPS proxies
# ========================
echo "Deleting HTTPS proxies..."
for proxy in $(gcloud compute target-https-proxies list --format="value(name)" | grep "$PREFIX"); do
    echo "Deleting HTTPS proxy: $proxy"
    gcloud compute target-https-proxies delete "$proxy" --quiet || true
    echo "HTTPS proxy $proxy deleted"
done
echo "HTTPS proxies deletion complete."

# ========================
# 3. Delete SSL certificates
# ========================
echo "Deleting SSL certificates..."
for cert in $(gcloud compute ssl-certificates list --format="value(name)" | grep "$PREFIX"); do
    echo "Deleting SSL certificate: $cert"
    gcloud compute ssl-certificates delete "$cert" --quiet || true
    echo "SSL certificate $cert deleted"
done
echo "SSL certificates deletion complete."

# ========================
# 4. Delete URL maps
# ========================
echo "Deleting URL maps..."
for urlmap in $(gcloud compute url-maps list --format="value(name)" | grep "$PREFIX"); do
    echo "Deleting URL map: $urlmap"
    gcloud compute url-maps delete "$urlmap" --quiet || true
    echo "URL map $urlmap deleted"
done
echo "URL maps deletion complete."

# ========================
# 5. Delete backend services
# ========================
echo "Deleting backend services..."
for backend in $(gcloud compute backend-services list --global --format="value(name)" | grep "$PREFIX"); do
    echo "Deleting backend service: $backend"
    gcloud compute backend-services delete "$backend" --global --quiet || true
    echo "Backend service $backend deleted"
done
echo "Backend services deletion complete."

# ========================
# 6. Delete Network Endpoint Groups (NEGs)
# ========================
echo "Deleting Network Endpoint Groups (NEGs)..."
# We use a while read loop to handle names with spaces (if any)
while IFS=$'\t' read -r name region_url; do
    # If the line is empty, continue
    [ -z "$name" ] && continue
    region=$(basename "$region_url")
    echo "Deleting NEG: $name ($region)"
    gcloud compute network-endpoint-groups delete "$name" --region="$region" --quiet || true
    echo "NEG $name deleted"
done < <(gcloud compute network-endpoint-groups list --format="value(name,region)" | grep "$PREFIX")
echo "NEGs deletion complete."


# ========================
# 7. Delete Cloud Run services
# ========================
echo "Deleting Cloud Run services..."
for service in $(gcloud run services list --platform=managed --format="value(name)" | grep "_service"); do
    echo "Deleting Cloud Run service: $service"
    gcloud run services delete "$service" --platform=managed --quiet || true
    echo "Service $service deleted"
done
echo "Cloud Run services deletion complete."

echo "Cleanup complete."
