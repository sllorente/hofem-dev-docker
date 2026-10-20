#!/bin/bash
set -euo pipefail

# Usage: ./build.sh [--dry-run] [IMAGE]
# Build the requested image and its dependencies once, in dependency order.
# With no image, build all variants. --dry-run only prints shell-escaped commands.
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

dry_run=false
requested_image=
for argument in "$@"; do
    case "$argument" in
        --dry-run) dry_run=true ;;
        -*) printf 'Unsupported option: %s\n' "$argument" >&2; exit 2 ;;
        *)
            if [[ -n $requested_image || -z $argument ]]; then
                printf 'Expected at most one nonempty image argument.\n' >&2
                exit 2
            fi
            requested_image=$argument
            ;;
    esac
done

case "$requested_image" in
    "")
        requested_images=(grema-dev:gnu grema-dev:2025.3 hofem-dev:2025.3 grema-dev:latest hofem-dev:latest)
        ;;
    grema-dev|hofem-dev)
        requested_images=("$requested_image:latest")
        ;;
    grema-dev:gnu|grema-dev:2025.3|hofem-dev:2025.3|grema-dev:latest|hofem-dev:latest)
        requested_images=("$requested_image")
        ;;
    *)
        printf 'Unsupported image: %s\n' "$requested_image" >&2
        exit 2
        ;;
esac

built_images=()
build_image() {
    local image=$1 built
    local -a build_args
    for built in "${built_images[@]}"; do
        if [[ $built == "$image" ]]; then
            return 0
        fi
    done

    case "$image" in
        grema-dev:gnu)
            build_args=(-f "$repo_dir/Dockerfile" --target gnu-dev)
            ;;
        grema-dev:2025.3)
            build_image grema-dev:gnu
            build_args=(-f "$repo_dir/Dockerfile" --target intel-2025)
            ;;
        hofem-dev:2025.3)
            build_image grema-dev:2025.3
            build_args=(-f "$repo_dir/Dockerfile.hofem" --build-arg GREMA_IMAGE=grema-dev:2025.3)
            ;;
        grema-dev:latest)
            build_image grema-dev:2025.3
            build_args=(-f "$repo_dir/Dockerfile" --target development)
            ;;
        hofem-dev:latest)
            build_image grema-dev:latest
            build_args=(-f "$repo_dir/Dockerfile.hofem" --build-arg GREMA_IMAGE=grema-dev:latest)
            ;;
    esac

    if [[ $dry_run == true ]]; then
        printf '%q ' docker build --platform linux/amd64 "${build_args[@]}" -t "$image" "$repo_dir/"
        printf '\n'
    else
        docker build --platform linux/amd64 "${build_args[@]}" -t "$image" "$repo_dir/"
    fi
    built_images+=("$image")
}

for image in "${requested_images[@]}"; do
    build_image "$image"
done
