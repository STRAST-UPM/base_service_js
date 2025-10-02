#!/bin/bash

full_path_to_script="$(realpath "${BASH_SOURCE[0]}")"
script_parent_folder="$(dirname "$full_path_to_script")"

image_name="strast-upm/base_service_js"
# image_repository="docker.io"
image_repository="ghcr.io"

# Check if tags provided as arguments
if [ $# -eq 0 ]; then
    echo "Usage: $0 <tag1> [tag2] [tag3] ..."
    echo "Example: $0 latest v1.0 stable"
    exit 1
fi

# Convert arguments to tags array
tags=("$@")

# Build images without cache to be fully updated
sudo docker build --no-cache --force-rm -t "$image_name:${tags[0]}" "$script_parent_folder"

echo "Creating tags and pushing..."
# Create all tags and push to registry
for tag in "${tags[@]}"; do

    # Create additional tag if not the first one
    if [ "$tag" != "${tags[0]}" ]; then
        sudo docker tag "$image_name:${tags[0]}" "$image_name:$tag"
    fi

    # Tag for registry and push
    sudo docker tag "$image_name:$tag" "$image_repository/$image_name:$tag"
    sudo docker push "$image_repository/$image_name:$tag"
done

echo "Cleaning dangling images..."
sudo docker image prune -f

echo "Complete! Available tags:"
for tag in "${tags[@]}"; do
    echo "  - $image_repository/$image_name:$tag"
done
