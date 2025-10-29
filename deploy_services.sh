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
europe-central2 # Varsovia
europe-north1 # Finlandia
europe-southwest1 # Madrid
europe-west2 # Londres
europe-west9 # París
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
