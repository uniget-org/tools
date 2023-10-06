#!/bin/bash

if ! curl --silent --location --fail http://127.0.0.1:5000/v2/; then
    echo "ERROR: Local registry is missing."
    exit 1
fi

DOCKERFILE="$(
    cat <<EOF
    FROM ubuntu:22.04
EOF
)"

docker buildx create --name sbom --driver-opt network=host --bootstrap --use
regctl registry set --tls disabled localhost:5000

echo "${DOCKERFILE}" \
| docker buildx build --file - --provenance=false                                    . --output type=registry,name=localhost:5000/test:docker-image,oci-mediatypes=false,buildinto=true,push=true
regctl manifest get localhost:5000/test:docker-image
#Name:        localhost:5000/test:docker-image
#MediaType:   application/vnd.docker.distribution.manifest.v2+json
#Digest:      sha256:4364d0a5d20e6df330a78e0acb3016fc28c59a1f200685a3feff07bbd7020885
#Total Size:  29.538MB
#Config:
#  Digest:    sha256:c4e82f53b551c4caf0e4f261361fe3849ad7c19af950868fb6f28fc266098a2f
#  MediaType: application/vnd.docker.container.image.v1+json
#  Size:      1224B
#Layers:
#  Digest:    sha256:37aaf24cf781dcc5b9a4f8aa5a99a40b60ae45d64dcb4f6d5a4b9e5ab7ab0894
#  MediaType: application/vnd.docker.image.rootfs.diff.tar.gzip
#  Size:      29.538MB

echo "${DOCKERFILE}" \
| docker buildx build --file - --provenance=false                                    . --output type=registry,name=localhost:5000/test:oci-image,oci-mediatypes=true,buildinto=true,push=true
regctl manifest get localhost:5000/test:oci-image
#Name:        localhost:5000/test:oci-image
#MediaType:   application/vnd.oci.image.manifest.v1+json
#Digest:      sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#Total Size:  29.538MB
#Config:
#  Digest:    sha256:c4e82f53b551c4caf0e4f261361fe3849ad7c19af950868fb6f28fc266098a2f
#  MediaType: application/vnd.oci.image.config.v1+json
#  Size:      1224B
#Layers:
#  Digest:    sha256:37aaf24cf781dcc5b9a4f8aa5a99a40b60ae45d64dcb4f6d5a4b9e5ab7ab0894
#  MediaType: application/vnd.oci.image.layer.v1.tar+gzip
#  Size:      29.538MB

echo "${DOCKERFILE}" \
| docker buildx build --file - --provenance=false --platform linux/amd64,linux/arm64 . --output type=registry,name=localhost:5000/test:docker-list,oci-mediatypes=false,buildinto=true,push=true
regctl manifest get localhost:5000/test:docker-list
#Name:        localhost:5000/test:docker-list
#MediaType:   application/vnd.docker.distribution.manifest.list.v2+json
#Digest:      sha256:9c66e59ff3b281f308706010e4df3f4c3d6a2f2abd02a560cd0dbd9a4e99bcb1
#Manifests:
#  Name:      localhost:5000/test:docker-list@sha256:4364d0a5d20e6df330a78e0acb3016fc28c59a1f200685a3feff07bbd7020885
#  Digest:    sha256:4364d0a5d20e6df330a78e0acb3016fc28c59a1f200685a3feff07bbd7020885
#  MediaType: application/vnd.docker.distribution.manifest.v2+json
#  Platform:  linux/amd64
#
#  Name:      localhost:5000/test:docker-list@sha256:cfc9834fd29204f049861e0eb189136110ea0dd1afcb1f5f66f1198dc1229231
#  Digest:    sha256:cfc9834fd29204f049861e0eb189136110ea0dd1afcb1f5f66f1198dc1229231
#  MediaType: application/vnd.docker.distribution.manifest.v2+json
#  Platform:  linux/arm64

echo "${DOCKERFILE}" \
| docker buildx build --file - --provenance=false --platform linux/amd64,linux/arm64 . --output type=registry,name=localhost:5000/test:oci-list,oci-mediatypes=true,buildinto=true,push=true
regctl manifest get localhost:5000/test:oci-list
#Name:        localhost:5000/test:oci-list
#MediaType:   application/vnd.oci.image.index.v1+json
#Digest:      sha256:653b915ef3fe9b892b11e3e6bb4122c5f9fe6fff1fa10e94d5e385928343de5a
#Manifests:
#  Name:      localhost:5000/test:oci-list@sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#  Digest:    sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#  MediaType: application/vnd.oci.image.manifest.v1+json
#  Platform:  linux/amd64
#
#  Name:      localhost:5000/test:oci-list@sha256:2ab1136e35f9a85352d3e43a647f3feb6517317a2c8310fe392706087fd7fbfd
#  Digest:    sha256:2ab1136e35f9a85352d3e43a647f3feb6517317a2c8310fe392706087fd7fbfd
#  MediaType: application/vnd.oci.image.manifest.v1+json
#  Platform:  linux/arm64

echo "${DOCKERFILE}" \
| docker buildx build --file - --attest=type=sbom                                    . --output type=registry,name=localhost:5000/test:oci-sbom,oci-mediatypes=true,buildinto=true,push=true
regctl manifest get localhost:5000/test:oci-sbom
#Name:                            localhost:5000/test:oci-sbom
#MediaType:                       application/vnd.oci.image.index.v1+json
#Digest:                          sha256:cb961fc14f51de08aea804a4bc1aac3cea32421f6dc87b96a6050917c22f31d4
#Manifests:
#  Name:                          localhost:5000/test:oci-sbom@sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#  Digest:                        sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#  MediaType:                     application/vnd.oci.image.manifest.v1+json
#  Platform:                      linux/amd64
#
#  Name:                          localhost:5000/test:oci-sbom@sha256:7fa02a66b3e93c2be01521b1bb8383c8128077c3353be20f95a68a07b1288f6c
#  Digest:                        sha256:7fa02a66b3e93c2be01521b1bb8383c8128077c3353be20f95a68a07b1288f6c
#  MediaType:                     application/vnd.oci.image.manifest.v1+json
#  Platform:                      unknown/unknown
#  Annotations:
#    vnd.docker.reference.digest: sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#    vnd.docker.reference.type:   attestation-manifest

echo "${DOCKERFILE}" \
| docker buildx build --file - --attest=type=sbom --platform linux/amd64,linux/arm64 . --output type=registry,name=localhost:5000/test:oci-list-sbom,oci-mediatypes=true,buildinto=true,push=true
regctl manifest get localhost:5000/test:oci-list-sbom
#Name:                            localhost:5000/test:oci-list-sbom
#MediaType:                       application/vnd.oci.image.index.v1+json
#Digest:                          sha256:06a72f6ac4e7e4cbd044233037a382b04ea819cf25ac8ee4aa584e05379d2eec
#Manifests:
#  Name:                          localhost:5000/test:oci-list-sbom@sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#  Digest:                        sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#  MediaType:                     application/vnd.oci.image.manifest.v1+json
#  Platform:                      linux/amd64
#
#  Name:                          localhost:5000/test:oci-list-sbom@sha256:2ab1136e35f9a85352d3e43a647f3feb6517317a2c8310fe392706087fd7fbfd
#  Digest:                        sha256:2ab1136e35f9a85352d3e43a647f3feb6517317a2c8310fe392706087fd7fbfd
#  MediaType:                     application/vnd.oci.image.manifest.v1+json
#  Platform:                      linux/arm64
#
#  Name:                          localhost:5000/test:oci-list-sbom@sha256:ec10889e2d430e58cc366216ced663849f9b44096a0e20f5c2e8e8e1a42efccb
#  Digest:                        sha256:ec10889e2d430e58cc366216ced663849f9b44096a0e20f5c2e8e8e1a42efccb
#  MediaType:                     application/vnd.oci.image.manifest.v1+json
#  Platform:                      unknown/unknown
#  Annotations:
#    vnd.docker.reference.digest: sha256:326d32b66725c5007dedc9515be190fc491d37a918ce61df41f9bd6556b79ff5
#    vnd.docker.reference.type:   attestation-manifest
#
#  Name:                          localhost:5000/test:oci-list-sbom@sha256:ea32c5368891fcf9ce9bc7e69b924c27e2a6b3ff656357c0bd2952b0f5214e2a
#  Digest:                        sha256:ea32c5368891fcf9ce9bc7e69b924c27e2a6b3ff656357c0bd2952b0f5214e2a
#  MediaType:                     application/vnd.oci.image.manifest.v1+json
#  Platform:                      unknown/unknown
#  Annotations:
#    vnd.docker.reference.digest: sha256:2ab1136e35f9a85352d3e43a647f3feb6517317a2c8310fe392706087fd7fbfd
#    vnd.docker.reference.type:   attestation-manifest

echo "${DOCKERFILE}" \
| docker buildx build --file - --provenance=false                                    . --output type=registry,name=localhost:5000/test:oci-tar,oci-mediatypes=true,buildinto=true,compression=uncompressed,force-compression=true,push=true
regctl manifest get localhost:5000/test:oci-tar
#Name:        localhost:5000/test:oci-tar
#MediaType:   application/vnd.oci.image.manifest.v1+json
#Digest:      sha256:534238c28c4d1a1d97f4296bd0dc34efe0b0bd6e47dfeb7c7501484f50ebb59c
#Total Size:  80.347MB
#Config:
#  Digest:    sha256:c4e82f53b551c4caf0e4f261361fe3849ad7c19af950868fb6f28fc266098a2f
#  MediaType: application/vnd.oci.image.config.v1+json
#  Size:      1224B
#Layers:
#  Digest:    sha256:01d4e4b4f381ac5a9964a14a650d7c074a2aa6e0789985d843f8eb3070b58f7d
#  MediaType: application/vnd.oci.image.layer.v1.tar
#  Size:      80.347MB

echo "${DOCKERFILE}" \
| docker buildx build --file - --provenance=false                                    . --output type=registry,name=localhost:5000/test:oci-estargz,oci-mediatypes=true,buildinto=true,compression=estargz,force-compression=true,push=true
regctl manifest get localhost:5000/test:oci-estargz
#Name:                                         localhost:5000/test:oci-estargz
#MediaType:                                    application/vnd.oci.image.manifest.v1+json
#Digest:                                       sha256:d98faa6717d20a6340c015ec491491649e1df05f6797ed2d3999da23a65d96c1
#Total Size:                                   32.513MB
#Config:
#  Digest:                                     sha256:43de87063de51c0f53960f14de6b4481ab54e6e4aba626840ab17ca62ebfe043
#  MediaType:                                  application/vnd.oci.image.config.v1+json
#  Size:                                       1224B
#Layers:
#  Digest:                                     sha256:ac8467af075e07f57674a644f752c0d0457c04cfddd55344e768aad721d93ccd
#  MediaType:                                  application/vnd.oci.image.layer.v1.tar+gzip
#  Size:                                       32.513MB
#  Annotations:
#    containerd.io/snapshot/stargz/toc.digest: sha256:61dd4cc6018bab50b9d94f335ef8eab5c086fef0b777bf9df2a1f8ac4a807274
#    io.containers.estargz.uncompressed-size:  81402368

echo "${DOCKERFILE}" \
| docker buildx build --file - --provenance=false                                    . --output type=registry,name=localhost:5000/test:oci-zstd,oci-mediatypes=true,buildinto=true,compression=zstd,force-compression=true,push=true
regctl manifest get localhost:5000/test:oci-zstd
#Name:        localhost:5000/test:oci-zstd
#MediaType:   application/vnd.oci.image.manifest.v1+json
#Digest:      sha256:35aa08dd68ff030c69fc0c2b31e81aa596b2cad104ea9c171f880d21932f50d7
#Total Size:  27.086MB
#Config:
#  Digest:    sha256:c4e82f53b551c4caf0e4f261361fe3849ad7c19af950868fb6f28fc266098a2f
#  MediaType: application/vnd.oci.image.config.v1+json
#  Size:      1224B
#Layers:
#  Digest:    sha256:f1ca272eea4226d7c520b7f97e0d8619e59d02ae789adea2dc2db434423dc1c2
#  MediaType: application/vnd.oci.image.layer.v1.tar+zstd
#  Size:      27.086MB
