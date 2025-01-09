#!/bin/bash

set -e

NEW_RELEASE_BRANCHES=()

# Define temporary files
rancher_tags_file=$(mktemp -p /tmp)

# Cherry pick label
cherry_pick_label="(cherry-pick)"

# Extract the latest tag from rancher/ingress-nginx
git for-each-ref --sort='-creatordate' --format '%(refname:short)' refs/tags | grep rancher > "$rancher_tags_file"

# Check if upstream_tags_file is empty
if [ ! -s "$rancher_tags_file" ]; then
    echo "[ERROR] No tags found in rancher/ingress-nginx."
    rm -f "$rancher_tags_file"
    exit 1
fi

# Process each tag
for tag in $NEW_TAGS; do
    echo "========================================================================================"
    echo "[INFO] Processing version: ${tag}"
    
    # Check if the branch already exist
    if git show-ref --verify --quiet refs/remotes/origin/nginx-${tag}-fix; then
        echo "[WARN] Branch nginx-${tag}-fix already exist. Skipping the version ${tag}."
        continue
    fi
    
    if ! $(git checkout -qb "nginx-${tag}-fix" controller-v$tag); then
        echo "[WARN] Could not checkout a local branch release-${tag} from the upstream tag ${tag}."
        continue
    fi
    echo "[INFO] Checkout to a local branch nginx-${tag}-fix from the upstream tag controller-v$tag."

    # Delete .github/workflows files and commit
    echo "[INFO] Deleting .github/workflows files."
    if ! rm -rf .github/workflows/*; then
        echo "[ERROR] Failed to delete .github/workflows files."
        exit 1
    fi

    # Add changes to git staging area
    if ! git add .github/workflows; then
        echo "[ERROR] Failed to stage .github/workflows files."
        exit 1
    fi

    # Commit the changes
    if ! git commit -m "Delete .github/workflows files"; then
        echo "[ERROR] Failed to commit the deletion of .github/workflows files."
        exit 1
    fi
    
    # Extract major and minor version from the tag
    major_minor=$(echo "${tag}" | cut -d '.' -f 1,2)

    # Try to find the latest tag with the same major and minor version
    last_latest_tag=$(grep "${major_minor}" "$rancher_tags_file" | head -1)

    # If not found, look for the previous minor version
    if [ -z "$last_latest_tag" ]; then
        major_minor=$(echo "${major_minor}" | awk -F. '{print $1 "." $2-1}')
        last_latest_tag=$(grep "${major_minor}" "$rancher_tags_file" | head -1)
    fi
    echo "[INFO] Latest ingress-nginx version in rancher/ingress-nginx prior ${tag}: ${last_latest_tag}"

    # List of commits to cherry pick
    cherry_pick_commits=$(git log --reverse ${last_latest_tag} --grep="^${cherry_pick_label}" --pretty=format:"%H")

    if [ -z "$cherry_pick_commits" ]; then
        echo "[WARN] No commit found with label ${cherry_pick_label} in tag ${last_latest_tag}. Skipping the version ${tag}"
        continue
    fi

    FAIL=0
    # Cherry-pick all commits before the user's commit
    for commit in $cherry_pick_commits; do
        if [[ $(git log --format=%B -n 1 $commit) == *"go generate"* ]]; then
            echo "[INFO] This is a go generate commit, not cherry picking."
            echo "[INFO] Performing 'go generate ./...'"
            if ! go generate ./... > /dev/null; then
                echo "[WARN] Failed during go generate in branch nginx-${tag}-fix. Skipping the version ${tag}."
                FAIL=1
                break
            fi
            echo "[INFO] Commit go generate changes"
            git add .
            if ! git commit -m "${cherry_pick_label} go generate" > /dev/null; then
                echo "[WARN] Failed in committing go generate in branch nginx-${tag}-fix. Skipping the version ${tag}."
                FAIL=1
                break
            fi
        else
            echo "[INFO] Cherry pick commit: $commit to branch: nginx-${tag}-fix"
            if ! git cherry-pick "$commit" > /dev/null; then
                echo "[WARN] Failed during cherry-pick of commit $commit in branch nginx-${tag}-fix. Skipping the version ${tag}."
                FAIL=1
                break
            fi
        fi
    done

    if [[ $FAIL == 0 ]]; then
        echo "[INFO] Cherry pick completed successfully. Pushing branch nginx-${tag}-fix to rancher repository."
        if ! git push --quiet --no-progress origin "nginx-${tag}-fix" > /dev/null; then
            echo "[WARN] Failed while pushing the branch nginx-${tag}-fix to rancher repository. Skipping the version ${tag}."
            continue
        else
            NEW_RELEASE_BRANCHES+=( "nginx-${tag}-fix" )
            echo "[INFO] Successfully pushed branch nginx-${tag}-fix: https://github.com/rancher/ingress-nginx/tree/nginx-${tag}-fix"
        fi
    else
        git cherry-pick --abort
    fi
done

echo "========================================================================================"

# Print the new branches
if [ ${#NEW_RELEASE_BRANCHES[@]} -eq 0 ]; then
    echo "[ERROR] No new release branches."
    exit 0
else
    echo "[INFO] New release branches:"
    for branch in "${NEW_RELEASE_BRANCHES[@]}"; do
        echo "- $branch"
    done
    # Convert NEW_RELEASE_BRANCHES array to JSON string
    echo "NEW_RELEASE_BRANCHES=$(printf '%s\n' "${NEW_RELEASE_BRANCHES[@]}" | awk '{printf "\"%s\",", $0}' | sed 's/,$/]/' | sed 's/^/[/' )" >> $GITHUB_OUTPUT
fi

# Clean up temporary files
rm -f "$rancher_tags_file"