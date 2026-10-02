#!/usr/bin/env bash
set -euo pipefail

manifest="${1:?Usage: install-tools.sh MANIFEST ARCH DESTINATION}"
arch="${2:?Architecture is required}"
destination="${3:?Destination is required}"
case "${arch}" in
  arm64 | amd64) ;;
  *)
    echo "Unsupported architecture: ${arch}" >&2
    exit 1
    ;;
esac

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
mkdir -p "${destination}"

while IFS= read -r tool; do
  url="$(jq -r --arg arch "${arch}" '.platforms[$arch].url' <<< "${tool}")"
  digest="$(jq -r --arg arch "${arch}" '.platforms[$arch].sha256' <<< "${tool}")"
  curl --fail --location --retry 3 --output "${work_dir}/download" "${url}"
  echo "${digest}  ${work_dir}/download" | sha256sum --check --status
  rm -rf "${work_dir}/extracted"
  mkdir -p "${work_dir}/extracted"
  if [[ "$(jq -r '.format' <<< "${tool}")" == tar.gz ]]; then
    tar --extract --gzip --file "${work_dir}/download" --directory "${work_dir}/extracted" --no-same-owner
  fi
  while IFS=$'\t' read -r target source; do
    if [[ "$(jq -r '.format' <<< "${tool}")" == binary ]]; then
      binary="${work_dir}/download"
    else
      mapfile -t matches < <(find "${work_dir}/extracted" -type f -name "${source}")
      if [[ "${#matches[@]}" != 1 ]]; then
        echo "Expected one ${source} executable in ${url}" >&2
        exit 1
      fi
      binary="${matches[0]}"
    fi
    install -m 0755 "${binary}" "${destination}/${target}"
  done < <(jq -r --arg arch "${arch}" '.platforms[$arch].binaries | to_entries[] | [.key, .value] | @tsv' <<< "${tool}")
done < <(jq -c '.[]' "${manifest}")
