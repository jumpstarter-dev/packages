#!/bin/sh
set -e

# Function to print text in green color
message() {
    printf "\033[0;32m%s\033[0m\n" "$1"
}

warning() {
    printf "\033[0;33m%s\033[0m\n" "$1"
}

# Clone the repository if it doesn't exist
if [ ! -d "jumpstarter" ]; then
    git clone https://github.com/jumpstarter-dev/jumpstarter.git
fi

cd jumpstarter

# Clean previous build artifacts
rm -rf dist

EXCLUDED_TAGS="v0.0.0 v0.0.1 v0.0.2 v0.0.3 v0.5.0rc1 v0.5.0rc2 v0.7.0dev"

# Function to build for a given ref (tag or branch)
build_ref() {
    ref=$1
    message "🛠️ Building for $ref"
    git checkout "$ref"

    uv build --all --out-dir dist
}

# Build for tags
message "--- Building tags ---"
git tag | while read tag; do
    # Check if the tag is in the excluded list
    is_excluded=0
    for excluded_tag in $EXCLUDED_TAGS; do
        if [ "$tag" = "$excluded_tag" ]; then
            is_excluded=1
            break
        fi
    done

    if [ $is_excluded -eq 0 ]; then
        build_ref "$tag"
    else
        warning "Skipping excluded tag: $tag"
    fi
done

# Build for main branch
build_ref "main"

# Build for release branches

# Fetch latest branches from remote
git fetch origin
# List remote branches matching release-* and strip 'origin/' prefix
git branch -r | grep 'origin/release-' | sed 's/origin\///' | while read branch; do
    build_ref "$branch"
done


git checkout main

message "✅ Build process completed"

