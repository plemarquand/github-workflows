#!/bin/bash
## ===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
##
## ===----------------------------------------------------------------------===##

set -euo pipefail

log() { printf -- "** %s\n" "$*" >&2; }
error() { printf -- "** ERROR: %s\n" "$*" >&2; }
fatal() { error "$@"; exit 1; }

test -n "${PROJECT_NAME:-}" || fatal "PROJECT_NAME unset"

if [ -f .license_header_template ]; then
  # allow projects to override the license header template
  expected_file_header_template=$(cat .license_header_template)
else
  expected_file_header_template="@@===----------------------------------------------------------------------===@@
@@
@@ This source file is part of the ${PROJECT_NAME} open source project
@@
@@ Copyright (c) YEARS Apple Inc. and the ${PROJECT_NAME} project authors
@@ Licensed under Apache License v2.0
@@
@@ See LICENSE.txt for license information
@@ See CONTRIBUTORS.txt for the list of ${PROJECT_NAME} project authors
@@
@@ SPDX-License-Identifier: Apache-2.0
@@
@@===----------------------------------------------------------------------===@@"
fi

paths_with_missing_license=( )

if [[ -f .licenseignore ]]; then
  static_exclude_list='":(exclude).licenseignore" ":(exclude).license_header_template" '
  dynamic_exclude_list=$(tr '\n' '\0' < .licenseignore | xargs -0 -I% printf '":(exclude)%" ')
  exclude_list=$static_exclude_list$dynamic_exclude_list
else
  exclude_list=":(exclude).license_header_template"
fi

file_paths=$(echo "$exclude_list" | xargs git ls-files)

while IFS= read -r file_path; do
  file_basename=$(basename -- "${file_path}")
  file_extension="${file_basename##*.}"

  # shellcheck disable=SC2001 # We prefer to use sed here instead of bash search/replace
  case "${file_extension}" in
    swift) expected_file_header=$(sed -e 's|@@|//|g' <<<"${expected_file_header_template}") ;;
    h) expected_file_header=$(sed -e 's|@@|//|g' <<<"${expected_file_header_template}") ;;
    c) expected_file_header=$(sed -e 's|@@|//|g' <<<"${expected_file_header_template}") ;;
    sh) expected_file_header=$(cat <(echo '#!/bin/bash') <(sed -e 's|@@|##|g' <<<"${expected_file_header_template}")) ;;
    ps1) expected_file_header=$(sed -e 's|@@|##|g' <<<"${expected_file_header_template}") ;;
    kts) expected_file_header=$(sed -e 's|@@|//|g' <<<"${expected_file_header_template}") ;;
    gradle) expected_file_header=$(sed -e 's|@@|//|g' <<<"${expected_file_header_template}") ;;
    groovy) expected_file_header=$(sed -e 's|@@|//|g' <<<"${expected_file_header_template}") ;;
    java) expected_file_header=$(sed -e 's|@@|//|g' <<<"${expected_file_header_template}") ;;
    py) expected_file_header=$(cat <(echo '#!/usr/bin/env python3') <(sed -e 's|@@|##|g' <<<"${expected_file_header_template}")) ;;
    rb) expected_file_header=$(cat <(echo '#!/usr/bin/env ruby') <(sed -e 's|@@|##|g' <<<"${expected_file_header_template}")) ;;
    in) expected_file_header=$(sed -e 's|@@|##|g' <<<"${expected_file_header_template}") ;;
    cmake) expected_file_header=$(sed -e 's|@@|##|g' <<<"${expected_file_header_template}") ;;
    *)
      error "Unsupported file extension ${file_extension} for file (exclude or update this script): ${file_path}"
      paths_with_missing_license+=("${file_path} ")
      ;;
  esac
  expected_file_header_linecount=$(wc -l <<<"${expected_file_header}")

  file_header=$(head -n "${expected_file_header_linecount}" "${file_path}")
  normalized_file_header=$(
    echo "${file_header}" \
    | sed -e 's/20[12][0123456789]-20[12][0123456789]/YEARS/' -e 's/20[12][0123456789]/YEARS/' \
  )

  if ! diff -u \
    --label "Expected header" <(echo "${expected_file_header}") \
    --label "${file_path}" <(echo "${normalized_file_header}")
  then
    paths_with_missing_license+=("${file_path} ")
  fi
done <<< "$file_paths"

if [ "${#paths_with_missing_license[@]}" -gt 0 ]; then
  fatal "❌ Found missing license header in files: ${paths_with_missing_license[*]}."
fi

log "✅ Found no files with missing license header."
