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

# Clean previous build artifacts
rm -rf dist

cd jumpstarter

EXCLUDED_TAGS="v0.0.0 v0.0.1 v0.0.2 v0.0.3 v0.5.0rc1 v0.5.0rc2"

# Function to build for a given ref (tag or branch)
build_ref() {
    ref=$1
    out_dir=$2
    message "🛠️ Building for $ref"
    git checkout "$ref"
    git clean -f -x # clean ignoring .gitignore rules
    # for every directory in the packages/ directory, if it does not contain
    # a pyproject.toml file, remove it, otherwise uv fails, this could
    # be leftovers from previous branches that git clean does not remove
    for dir in packages/*; do
        if [ -d "$dir" ] && [ ! -f "$dir/pyproject.toml" ]; then
            rm -rf "$dir"
        fi
    done
    uv build --all --out-dir "$out_dir"
}

build_index() {
    dist_dir=$1
    variant=$2
    message "📦 Building index for ${dist_dir}/${variant}"
    for f in "${dist_dir}/${variant}/files"/*.whl "${dist_dir}/${variant}/files"/*.tar.gz; do basename "$f"; done > "package-list-${variant}.txt"
    cat "package-list-${variant}.txt"
    uvx dumb-pypi --package-list "package-list-${variant}.txt" \
                  --packages-url "https://pkg.jumpstarter.dev/${variant}/files" \
                  --output-dir "${dist_dir}/${variant}" \
                  --title "Jumpstarter Python Packages"
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

    # Exclude tags ending with "dev", "dev0", "dev123", etc. Those are just an anchor for the main branch releases 
    if echo "$tag" | grep -qE "dev[0-9]*$"; then
        is_excluded=1
    fi

    if [ $is_excluded -eq 1 ]; then
        warning "Skipping excluded tag: $tag"
        continue
    fi

    # Exclude tags matching the "v*rc*" pattern
    if echo "$tag" | grep -q "v.*rc.*"; then
        build_ref "$tag" "../dist/rc/files"
        continue
    fi


    build_ref "$tag" ../dist/files
done

message "--- Index for releases ---"
build_index "../dist" ""

message "--- Index for release candidates ---"
build_index "../dist" "rc"

# Build for main branch
build_ref "main" "../dist/main/files"
build_index "../dist" "main"

# Build for release branches

# Fetch latest branches from remote
git fetch origin
# List remote branches matching release-* and strip 'origin/' prefix
git branch -r | grep 'origin/release-' | sed 's/origin\///' | while read branch; do
    build_ref "${branch}" "../dist/${branch}/files"
    build_index "../dist" "${branch}"
done

git checkout main


message "✅ Build process completed"

