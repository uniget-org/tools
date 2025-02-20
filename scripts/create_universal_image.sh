#!/bin/bash
set -o errexit

#
# Create an image which uses the same layers for all platforms
#
# 1. Download image for linux/amd64
# 2. Patch OCI layout for linux/arm64
# 3. Create a new image index including the patched image
#

IMAGE_REPO=registry.haufe.io/dillen/universal
IMAGE_AMD64=${IMAGE_REPO}:amd64
IMAGE_ARM64=${IMAGE_REPO}:arm64
IMAGE_UNIVERSAL=${IMAGE_REPO}:latest

# Build image for amd64
docker build . --provenance=false --sbom=false --platform=linux/amd64 --tag=${IMAGE_AMD64} --push
regctl manifest get ${IMAGE_AMD64}

# Export image to disk
regctl image export ${IMAGE_AMD64} >test-amd64.tar
tar -xf test-amd64.tar

# Show current digests
MANIFEST_DIGEST="$( jq --raw-output '.manifests[0].digest' index.json | cut -d: -f2 )"
CONFIG_DIGEST="$( jq --raw-output '.[0].Config' manifest.json | cut -d/ -f3 )"
echo "### Manifest digest: ${MANIFEST_DIGEST}"
echo "### Config digest: ${CONFIG_DIGEST}"

# Patch config for arm64
sed -i 's/amd64/arm64/' blobs/sha256/${CONFIG_DIGEST}
NEW_CONFIG_DIGEST="$(
    sha256sum blobs/sha256/${CONFIG_DIGEST} \
    | cut -d' ' -f1 \
    | cut -d: -f2
)"
echo "### New config digest: ${NEW_CONFIG_DIGEST}"
mv -v blobs/sha256/${CONFIG_DIGEST} blobs/sha256/${NEW_CONFIG_DIGEST}
sed -i "s|${CONFIG_DIGEST}|${NEW_CONFIG_DIGEST}|" manifest.json

# Patch manifest for arm64
sed -i "s|${CONFIG_DIGEST}|${NEW_CONFIG_DIGEST}|" blobs/sha256/${MANIFEST_DIGEST}
NEW_MANIFEST_DIGEST="$(
    sha256sum blobs/sha256/${MANIFEST_DIGEST} \
    | cut -d' ' -f1 \
    | cut -d: -f2
)"
echo "### New manifest digest: ${NEW_MANIFEST_DIGEST}"
mv -v blobs/sha256/${MANIFEST_DIGEST} blobs/sha256/${NEW_MANIFEST_DIGEST}

# Upload config blob and manifest
regctl blob put ${IMAGE_REPO} <blobs/sha256/${NEW_CONFIG_DIGEST}
regctl manifest put ${IMAGE_ARM64} <blobs/sha256/${NEW_MANIFEST_DIGEST}

# Create index
regctl index create ${IMAGE_UNIVERSAL} \
    --ref ${IMAGE_AMD64} \
    --ref ${IMAGE_ARM64}

# Cleanup
rm -rf \
    blobs \
    index.json \
    manifest.json \
    oci-layout \
    test-amd64.tar \
    test-arm64.tar
