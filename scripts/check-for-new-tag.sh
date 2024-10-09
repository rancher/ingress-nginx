#!/bin/bash

set -e

new_tags=()

# Define temporary files
rancher_tags_file=$(mktemp -p /tmp)
upstream_tags_file=$(mktemp -p /tmp)

# Fetch tags from the rancher/ingress-nginx repository and save to a temp file
git for-each-ref --sort='-creatordate' --format '%(refname:short)' refs/tags | grep rancher | head -n 10 > "$rancher_tags_file"

echo "[INFO] Setting up git kubernetes/ingress-nginx upstream in rancher/ingress-nginx git repository."
# Add upstream remote if not already added
if ! git remote get-url upstream &>/dev/null; then
    git remote add "upstream" https://github.com/kubernetes/ingress-nginx.git
fi

# Fetch upstream tags
git fetch --tags --quiet upstream || true

# Fetch tags from the upstream kubernetes/ingress-nginx repository and save to a temp file
git for-each-ref --sort='-creatordate' --format '%(refname:short)' refs/tags | grep controller | head -n 5 | awk '{gsub(/controller-v/, ""); print $0}'> "$upstream_tags_file"

# Check if upstream_tags_file is empty
if [ ! -s "$upstream_tags_file" ]; then
    echo "[ERROR] Could not get tags from kubernetes/ingress-nginx."
    cat $upstream_tags_file
    rm -f "$rancher_tags_file" "$upstream_tags_file"
    exit 1
fi

# Process each tag
while read -r tag; do
    # Skip tags with "rc", "alpha", or "beta"
    if [[ "$tag" == *"rc"* || "$tag" == *"alpha"* || "$tag" == *"beta"* ]]; then
        continue
    fi

    # Check if the tag already exists in the rancher repository
    if grep -q "${tag}" "$rancher_tags_file"; then
        continue
    else
        # Check if the tag has a newer patch release already available
        latest_patch_in_rancher=$(grep "$(echo "${tag}" | cut -d '.' -f 1,2)" "$rancher_tags_file" | head -n 1)
        latest_patch_in_rancher=${latest_patch_in_rancher#nginx-}
        latest_patch_in_rancher=${latest_patch_in_rancher%-rancher*}
        if [ "$(printf '%s\n' "${tag}" "${latest_patch_in_rancher}" | sort -V | tail -n 1)" = "${tag}" ]; then
            new_tags+=( "${tag}" )
        fi
    fi
done < "$upstream_tags_file"

# In-place reverse so that the latest ingress-nginx version is processed last and stays latest as per the tagged date time.
for (( i=0, j=${#new_tags[@]}-1; i<j; i++, j-- )); do
    temp="${new_tags[i]}"
    new_tags[i]="${new_tags[j]}"
    new_tags[j]="$temp"
done

# Print the new tags
if [ ${#new_tags[@]} -eq 0 ]; then
    echo "[ERROR] No new tags found in upstream kubernetes/ingress-nginx."
    exit 1
else
    echo "[INFO] New tags to create branches in rancher/ingress-nginx:"
    for tag in "${new_tags[@]}"; do
        echo "- $tag"
    done
fi

echo "NEW_TAGS=${new_tags[@]}" >> $GITHUB_ENV

# Clean up temporary files
rm -f "$rancher_tags_file" "$upstream_tags_file"
