#!/bin/bash
set -o errexit

find tools -type f -name Dockerfile.template \
| sort \
| while read -r FILENAME; do

    if grep -P -z -q 'RUN <<EOF # no download cache\n' "${FILENAME}"; then
        #echo "Ignoring ${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\nnpm install ' "${FILENAME}"; then
        #echo "Ignoring ${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\nshiv ' "${FILENAME}"; then
        #echo "Ignoring ${FILENAME}"
        continue
    fi

    if grep -q "^unzip -q " "${FILENAME}"; then
        sed -E -z -i 's@RUN <<EOF\ncheck-github-release-asset "([^"]+)" "([^"]+)" "([^"]+)"\n\n?url="([^"]+)"\nfilename=".+"\ncurl --silent --show-error --location --fail --remote-name "([^"]+)"\nunzip -q -o -d "([^"]+)" "([^"]+)"@RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF\nurl="\4"\nfilename="$( basename "${url}" )"\n\ncheck-github-release-asset "\1" "\2" "${filename}"\ncurl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" \\\n    "${url}"\n\nunzip -t "${uniget_cache_download}/${filename}"\nunzip -q -o -d "\6" "${uniget_cache_download}/${filename}"@' "${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\ncurl ' "${FILENAME}"; then
        echo "Missing handler ${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\ngit clone ' "${FILENAME}"; then
        #sed -E -z -i 's@RUN <<EOF\ngit clone -q --config advice.detachedHead=false --depth 1 --branch "([^"]+)" https://github.com/([^ ]+) .@RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF\nurl="https://github.com/\2/archive/refs/tags/\1.tar.gz"\nfilename="$( basename "${url}" )"\n\ncurl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" \\\n    "${url}"\n@' "${FILENAME}"
        #echo "Ignoring ${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\ncheck-github-release-asset "[^"]+" "[^"]+" "[^"]+"\n\n?curl --silent --show-error --location --fail "[^"]+" \\\n| tar' "${FILENAME}"; then
        sed -E -z -i 's@RUN <<EOF\ncheck-github-release-asset "([^"]+)" "([^"]+)" "([^"]+)"\n\n?curl --silent --show-error --location --fail "([^"]+)" \\\n\| tar @RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF\nurl="\4"\nfilename="$( basename "${url}" )"\n\ncheck-github-release-asset "\1" "\2" "${filename}"\ncurl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" \\\n    "${url}"\n\ntar --file "${uniget_cache_download}/${filename}" --list\ntar --file "${uniget_cache_download}/${filename}" @' "${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\ncheck-github-release-asset "[^"]+" "[^"]+" "[^"]+"\n\n?curl --silent --show-error --location --fail --output "[^"]+" \\\n\s+"[^"]+"' "${FILENAME}"; then
        sed -E -z -i 's@RUN <<EOF\ncheck-github-release-asset "([^"]+)" "([^"]+)" "([^"]+)"\n\n?curl --silent --show-error --location --fail --output "([^"]+)" \\\n\s+"([^"]+)"\nchmod \+x "([^"]+)"@RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF\nurl="\5"\nfilename="$( basename "${url}" )"\n\ncheck-github-release-asset "\1" "\2" "${filename}"\ncurl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" \\\n    "${url}"\n\ninstall --mode=0755 \\\n    "${uniget_cache_download}/${filename}" \\\n    "\6"\n@' "${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\ncheck-github-release-asset "[^"]+" "[^"]+" "[^"]+"\n' "${FILENAME}"; then
        sed -E -z -i 's@RUN <<EOF\ncheck-github-release-asset "([^"]+)" "([^"]+)" "([^"]+)"\n@RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF\ncheck-github-release-asset "\1" "\2" "\3"\n@' "${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\ncheck-download "[^"]+"\n\n?curl --silent --show-error --location --fail --output "[^"]+" \\\n\s+"[^"]+"' "${FILENAME}"; then
        sed -E -z -i 's@RUN <<EOF\ncheck-download "([^"]+)"\n\n?curl --silent --show-error --location --fail --output "([^"]+)" \\\n\s+"([^"]+)"\nchmod \+x "([^"]+)"@RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF\nurl="\1"\nfilename="$( basename "${url}" )"\n\ncheck-download "${url}"\ncurl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" \\\n    "${url}"\n\ninstall --mode=0755 \\\n    "${uniget_cache_download}/${filename}" \\\n    "\4"\n@' "${FILENAME}"
        continue
    fi

    if grep -P -z -q 'RUN <<EOF\necho "### Setting' "${FILENAME}" && grep -P -z -q 'check-github-release-asset' "${FILENAME}"; then
        sed -E -z -i 's@echo "### Downloading [^"]+"\n@@; s@RUN <<EOF\n@RUN --mount=type=cache,target=/var/cache/uniget/download <<EOF\n@; s@check-github-release-asset "([^"]+)" "([^"]+)" "([^"]+)"\n\n?curl --silent --show-error --location --fail "([^"]+)" \\\n\| tar @url="\4"\nfilename="$( basename "${url}" )"\n\ncheck-github-release-asset "\1" "\2" "${filename}"\ncurl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" \\\n    "${url}"\n\ntar --file "${uniget_cache_download}/${filename}" --list\ntar --file "${uniget_cache_download}/${filename}" @; s@check-github-release-asset "([^"]+)" "([^"]+)" "([^"]+)"\n\n?curl --silent --show-error --location --fail --output "([^"]+)" \\\n\s+"([^"]+)"\nchmod \+x "([^"]+)"@url="\5"\nfilename="$( basename "${url}" )"\n\ncheck-github-release-asset "\1" "\2" "${filename}"\ncurl --silent --show-error --location --fail --output "${uniget_cache_download}/${filename}" \\\n    "${url}"\n\ninstall --mode=0755 \\\n    "${uniget_cache_download}/${filename}" \\\n    "\6"\n@' "${FILENAME}"
        continue
    fi

    if grep -q "RUN <<EOF" "${FILENAME}"; then
        echo "Unhandled ${FILENAME}"
    fi

done
