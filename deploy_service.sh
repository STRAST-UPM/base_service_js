#!/bin/bash
set -e

#=========================
# Initial Configuration
#=========================

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo "No gcloud project set."
    echo "Execute: gcloud config set project <PROJECT_ID>"
    exit 1
fi

# Define domains and regions associated
declare -A DOMAINS
DOMAINS["europe.anycastprivacy.org"]="europe-west1 europe-north1"
DOMAINS["global.anycastprivacy.org"]="europe-west1 europe-north1 us-east1 us-west2"

# Name prefix to avoid collisions between resources
PREFIX="anycastprivacy"

echo "Active project: $PROJECT_ID"
echo "=============================="

# ===================================
# Create Network Endopoint Groups (NEGs) for each Cloud Run service
# ===================================

for domain in "${!DOMAINS[@]}"; do
  regions=(${DOMAINS[$domain]})
  for region in "${regions[@]}"; do
    service_name="${region//-/_}-service"
    neg_name="${PREFIX}-${service_name}-neg"

    echo "Creating NEG $neg_name for $service_name ($region)"
    # gcloud compute network-endpoint-groups create "$neg_name" \
    #   --region="$region" \
    #   --network-endpoint-type=serverless \
    #   --cloud-run-service="$service_name" \
    #   --project="$PROJECT_ID" || echo "NEG $neg_name created"
  done
done

#====================================
# Create Backends and Add NEGs
#====================================
for domain in "${!DOMAINS[@]}"; do
  backend_name="${PREFIX}-backend-${domain//./-}"
  echo "Creating backend $backend_name"

  # gcloud compute backend-services create "$backend_name" \
  #   --global \
  #   --protocol=HTTP \
  #   --load-balancing-scheme=EXTERNAL_MANAGED \
  #   --project="$PROJECT_ID" || echo "Backend $backend_name created"

  regions=(${DOMAINS[$domain]})
  for region in "${regions[@]}"; do
    service_name="${region//-/_}-service"
    neg_name="${PREFIX}-${service_name}-neg"

    echo "Adding NEG $neg_name ($region)"
    # gcloud compute backend-services add-backend "$backend_name" \
    #   --global \
    #   --network-endpoint-group="$neg_name" \
    #   --network-endpoint-group-region="$region" \
    #   --project="$PROJECT_ID" || echo "Error adding backend $neg_name"
  done
done

#====================================
# URL Maps, Certificates and Proxies
#====================================
for domain in "${!DOMAINS[@]}"; do
  backend_name="${PREFIX}-backend-${domain//./-}"
  urlmap_name="${PREFIX}-urlmap-${domain//./-}"
  cert_name="${PREFIX}-cert-${domain//./-}"
  proxy_name="${PREFIX}-proxy-${domain//./-}"
  rule_name="${PREFIX}-rule-${domain//./-}"

  echo "Configuring domain: $domain"

  # URL Map
    echo "Creating URL map $urlmap_name"
  # gcloud compute url-maps create "$urlmap_name" \
  #   --default-service="$backend_name" \
  #   --project="$PROJECT_ID" || echo "URL map $urlmap_name created"

  # Certificate SSL 
    echo "Creating SSL certificate $cert_name"
  # gcloud compute ssl-certificates create "$cert_name" \
  #   --domains="$domain" \
  #   --project="$PROJECT_ID" || echo "SSL certificate $cert_name created"

  # HTTPS Proxy
    echo "Creating HTTPS proxy $proxy_name"
  # gcloud compute target-https-proxies create "$proxy_name" \
  #   --url-map="$urlmap_name" \
  #   --ssl-certificates="$cert_name" \
  #   --project="$PROJECT_ID" || echo "HTTPS proxy $proxy_name created"

  # Forwarding Rule
    echo "Creating forwarding rule $rule_name"
  # gcloud compute forwarding-rules create "$rule_name" \
  #   --global \
  #   --target-https-proxy="$proxy_name" \
  #   --ports=443 \
  #   --project="$PROJECT_ID" || echo "Forwarding rule $rule_name created"
done

# ===================================
# Show IPs for DNS configuration
# ===================================
echo ""
echo "Configuration complete."
echo "Add these DNS records:"
# gcloud compute forwarding-rules list --global --format="table(Name, IPAddress, Target)"
