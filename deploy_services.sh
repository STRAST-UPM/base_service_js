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

echo "Active project: $PROJECT_ID"
echo "=============================="

REGIONS=(
africa-south1 # Johannesburgo
asia-east1
asia-east2
asia-northeast1
asia-northeast2
asia-northeast3
asia-south1
asia-south2
asia-southeast1
asia-southeast2
australia-southeast1
australia-southeast2
europe-central2 # Varsovia
europe-north1 # Finlandia
europe-north2 # Estocolmo
europe-southwest1 # Madrid
europe-west1 # Bélgica
europe-west2 # Londres
europe-west3 # Frankfurt
europe-west4 # Países Bajos
europe-west6 # Zurich
europe-west8 # Milán
europe-west9 # París
europe-west10 # Berlín
europe-west12 # Turín
me-central1 # Dubai
me-central2 # Dubai
me-west1 # Dubai
northamerica-northeast1 # Toronto
northamerica-northeast2 # Montreal
northamerica-south1 # São Paulo
southamerica-east1 # Buenos Aires
southamerica-west1 # Santiago
us-central1 # Iowa
us-east1 # Virginia
us-east4 # Ohio
us-east5 # Washington
us-south1 # Dallas
us-west1 # Oregón
us-west2 # California
us-west3 # Nevada
us-west4 # Washington
)

REGIONS=(
europe-central2 # Varsovia
europe-north1 # Finlandia
# europe-north2 # Estocolmo
europe-southwest1 # Madrid
# europe-west1 # Bélgica
europe-west2 # Londres
# europe-west3 # Frankfurt
# europe-west4 # Países Bajos
# europe-west6 # Zurich
# europe-west8 # Milán
europe-west9 # París
# europe-west10 # Berlín
# europe-west12 # Turín
)

#====================================
# Deploy Cloud Run services
#====================================

IMAGE="gcr.io/$PROJECT_ID/base_service_js:latest"
WAIT_SECONDS=60

for region in "${REGIONS[@]}"; do
    service_name="${region}-service"
    echo "Deploying Cloud Run service $service_name in $region..."

    # Check if the service already exists
    if gcloud run services describe "$service_name" --region="$region" --platform=managed --project="$PROJECT_ID" &>/dev/null; then
        echo "Service $service_name already exists in $region. Skipping..."
        continue
    fi

    if gcloud run deploy "$service_name" \
        --image="$IMAGE" \
        --region="$region" \
        --allow-unauthenticated \
        --platform=managed \
        --project="$PROJECT_ID" \
        --set-env-vars="REGION=$region"; then
        echo "Service $service_name deployed successfully. Waiting $WAIT_SECONDS seconds..."
        sleep $WAIT_SECONDS
    else
        echo "Deployment failed for $service_name. Deleting service..."
        gcloud run services delete "$service_name" \
            --region="$region" \
            --platform=managed \
            --quiet
    fi
done

echo "All deployments attempted."
