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
# Only the ones in the EEA
DOMAINS["europe.anycastprivacy.org"]="
europe-central2
europe-north1
europe-north2
europe-southwest1
europe-west1
europe-west10
europe-west12
europe-west3
europe-west4
europe-west8
europe-west9"

DOMAINS["global.anycastprivacy.org"]="
africa-south1
asia-east1
asia-east2
asia-northeast1northeast1
asia-northeast2
asia-northeast3
asia-south1
asia-south2
asia-southeast1
asia-southeast2
australia-southeast1
australia-southeast2
europe-central2
europe-north1
europe-north2
europe-southwest1
europe-west1
europe-west10
europe-west12
europe-west2
europe-west3
europe-west4
europe-west6
europe-west8
europe-west9
me-central1
me-central2
me-west1
northamerica-northeast1
northamerica-northeast2
northamerica-south1
southamerica-east1
southamerica-west1
us-central1
us-east1
us-east4
us-east5
us-south1
us-west1
us-west2
us-west3
us-west4"

# Name prefix to avoid collisions between resources
PREFIX="anycastprivacy"

echo "Active project: $PROJECT_ID"
echo "=============================="

#====================================
# Deploy Cloud Run services in specified regions
#====================================
IMAGE="gcr.io/$PROJECT_ID/base_service_js:latest"

for domain in "${!DOMAINS[@]}"; do
    regions=(${DOMAINS[$domain]})
    for region in "${regions[@]}"; do
        service_name="${region}-service"
        echo "Deploying Cloud Run service $service_name in $region..."
        gcloud run deploy "$service_name" \
            --image="$IMAGE" \
            --region="$region" \
            --allow-unauthenticated \
            --platform=managed \
            --project="$PROJECT_ID" \
            --set-env-vars="REGION=$region" || echo "Service $service_name already deployed"
    done
done

#====================================
# Create Network Endpoint Groups (NEGs) for each Cloud Run service
#====================================

for domain in "${!DOMAINS[@]}"; do
    regions=(${DOMAINS[$domain]})
    for region in "${regions[@]}"; do
        service_name="${region}-service"
        neg_name="${PREFIX}-${service_name}-neg"

        echo "Creating NEG $neg_name for $service_name ($region)"
        gcloud compute network-endpoint-groups create "$neg_name" \
            --region="$region" \
            --network-endpoint-type=serverless \
            --cloud-run-service="$service_name" \
            --project="$PROJECT_ID" || echo "NEG already $neg_name created"
    done
done

#====================================
# Create Backends and Add NEGs
#====================================
for domain in "${!DOMAINS[@]}"; do
    backend_name="${PREFIX}-backend-${domain//./-}"
    echo "Creating backend $backend_name"

    gcloud compute backend-services create "$backend_name" \
        --global \
        --protocol=HTTP \
        --load-balancing-scheme=EXTERNAL_MANAGED \
        --project="$PROJECT_ID" || echo "Backend already $backend_name created"

    regions=(${DOMAINS[$domain]})
    for region in "${regions[@]}"; do
        service_name="${region}-service"
        neg_name="${PREFIX}-${service_name}-neg"

        echo "Adding NEG $neg_name ($region)"
        gcloud compute backend-services add-backend "$backend_name" \
           --global \
           --network-endpoint-group="$neg_name" \
           --network-endpoint-group-region="$region" \
           --project="$PROJECT_ID" || echo "Error adding backend $neg_name"
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
    gcloud compute url-maps create "$urlmap_name" \
        --default-service="$backend_name" \
        --project="$PROJECT_ID" || echo "URL map already $urlmap_name created"

    # Certificate SSL 
    echo "Creating SSL certificate $cert_name"
    gcloud compute ssl-certificates create "$cert_name" \
        --domains="$domain" \
        --project="$PROJECT_ID" || echo "SSL certificate already $cert_name created"

    # HTTPS Proxy
    echo "Creating HTTPS proxy $proxy_name"
    gcloud compute target-https-proxies create "$proxy_name" \
        --url-map="$urlmap_name" \
        --ssl-certificates="$cert_name" \
        --project="$PROJECT_ID" || echo "HTTPS proxy already $proxy_name created"

    # Forwarding Rule
    echo "Creating forwarding rule $rule_name"
    gcloud compute forwarding-rules create "$rule_name" \
        --global \
        --target-https-proxy="$proxy_name" \
        --ports=443 \
        --project="$PROJECT_ID" || echo "Forwarding rule already $rule_name created"
done

# ===================================
# Show IPs for DNS configuration
# ===================================
echo ""
echo "Configuration complete."
echo "Add these DNS records:"
gcloud compute forwarding-rules list --global --format="table(Name, IPAddress, Target)"
