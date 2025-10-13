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
africa-south1
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
us-west4
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
