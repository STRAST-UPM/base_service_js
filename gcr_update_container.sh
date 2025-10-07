#!/bin/bash

full_path_to_script="$(realpath "${BASH_SOURCE[0]}")"
script_parent_folder="$(dirname "$full_path_to_script")"

# === CONFIGURACIÓN ===
image_name="base_service_js"
gcp_repo="gcr.io"

# Obtén automáticamente el Project ID de GCP activo
gcp_project_id=$(gcloud config get-value project 2>/dev/null)

if [ -z "$gcp_project_id" ]; then
    echo "No hay un proyecto de Google Cloud configurado."
    echo "Ejecuta antes: gcloud config set project <PROJECT_ID>"
    exit 1
fi

# === USO ===
if [ $# -eq 0 ]; then
    echo "Usage: $0 <tag1> [tag2] [tag3] ..."
    echo "Example: $0 latest v1.0 stable"
    exit 1
fi

tags=("$@")

# === LOGIN a GCR ===
echo "Autenticando Docker con GCR..."
gcloud auth configure-docker gcr.io --quiet

# === BUILD ===
echo "Construyendo imagen local..."
sudo docker build --no-cache --force-rm -t "$image_name:${tags[0]}" "$script_parent_folder"

# === PUSH ===
echo "Creando tags y subiendo a GCR..."
for tag in "${tags[@]}"; do
    if [ "$tag" != "${tags[0]}" ]; then
        sudo docker tag "$image_name:${tags[0]}" "$image_name:$tag"
    fi

    gcr_tag="$gcp_repo/$gcp_project_id/$image_name:$tag"
    sudo docker tag "$image_name:$tag" "$gcr_tag"
    sudo docker push "$gcr_tag"
done

# === LIMPIEZA ===
echo "Limpiando imágenes intermedias..."
sudo docker image prune -f

echo "Completado. Imágenes disponibles en GCR:"
for tag in "${tags[@]}"; do
    echo "  - $gcp_repo/$gcp_project_id/$image_name:$tag"
done
