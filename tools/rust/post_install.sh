#!/bin/bash
set -o errexit

cat <<EOF >"${target}/etc/profile.d/rust.sh"
#!/bin/bash
export CARGO_HOME="${target}/cargo"
export RUSTUP_HOME="${target}/rustup"
EOF
