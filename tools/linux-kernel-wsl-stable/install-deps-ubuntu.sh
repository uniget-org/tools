#!/bin/bash
set -o errexit -o pipefail

apt-get install --no-install-recommends \
    build-essential \
    pkg-config \
    libncurses-dev \
    flex \
    bison \
    libelf-dev \
    libncurses-dev \
    libssl-dev \
    dwarves
