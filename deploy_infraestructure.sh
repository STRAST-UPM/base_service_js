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


# List of all possible regions
################################################################################
# africa-south1 # Johannesburgo
# northamerica-northeast1 # Toronto
# northamerica-northeast2 # Montreal
# northamerica-south1 # São Paulo
# southamerica-east1 # Buenos Aires
# southamerica-west1 # Santiago
# us-central1 # Iowa
# us-east1 # Virginia
# us-east4 # Ohio
# us-east5 # Washington
# us-south1 # Dallas
# us-west1 # Oregón
# us-west2 # California
# us-west3 # Nevada
# us-west4 # Washington
# asia-east1 # Taiwán
# asia-east2 # Hong Kong
# asia-northeast1 # Tokio
# asia-northeast2 # Osaka
# asia-northeast3 # Seúl
# asia-south1 # Bombai
# asia-south2 # Delhi
# asia-southeast1 # Singapur
# asia-southeast2 # Yakarta
# australia-southeast1 # Sídney
# australia-southeast2 # Melbourne
# europe-central2 # Varsovia
# europe-north1 # Finlandia
# europe-north2 # Estocolmo
# europe-southwest1 # Madrid
# europe-west1 # Bélgica
# europe-west2 # Londres
# europe-west3 # Frankfurt
# europe-west4 # Países Bajos
# europe-west6 # Zurich
# europe-west8 # Milán
# europe-west9 # París
# europe-west10 # Berlín
# europe-west12 # Turín
# me-central1 # Doha
# me-central2 # Dammam
# me-west1 # Tel Aviv
################################################################################

# Define domains and regions associated
declare -A DOMAINS
# Only the ones in the EEA
DOMAINS["europe.anycastprivacy.org"]="
europe-central2
europe-north1
europe-southwest1
europe-west2
europe-west9
"

DOMAINS["global.anycastprivacy.org"]="
europe-central2
europe-north1
europe-southwest1
europe-west2
europe-west9
"

# Name prefix to avoid collisions between resources
PREFIX="anycastprivacy"

echo "Active project: $PROJECT_ID"
echo "=============================="

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
