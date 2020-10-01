#!/usr/bin/env bash

set -e

# Helper
helpFunction()
{
   echo "Usage: ./scripts/git_tag_versioning.sh -p {dev|qa|sandbox|prod} -t {patch|minor|major}"
   exit 0 # Exit script after printing help
}

while getopts ":p:t:f:" opt; do
  case $opt in
    p) prefix="$OPTARG";;
    t) type="$OPTARG";;
    f) force="$OPTARG";;
    \?) echo "Invalid option -$OPTARG"; helpFunction;;
  esac
done

# Validate input
case "$prefix" in
    dev|qa|sandbox|prod);; # OK
    *) printf '\nError: invalid prefix "%s"\n' "$prefix"; helpFunction;;
esac

case "$type" in
    patch|minor|major);; # OK
    *) printf '\nError: invalid type "%s"\n' "$type"; helpFunction;;
esac

echo "Prefix: $prefix";
echo "Semver type: $type";
if [ -n "$force" ]; then
    echo "Forcing execution. I sure hope you know what you are doing."
fi

# Initializes flags and other variables
prefix="$prefix-"
versionFile=false   # Flag to generate the .semver file
last=''             # Will contain the last version tag found

## Runs a command with arguments, taking care of the --dry flag
function execute {
    cmd=("$@")

    printf '%s\n' "Executing ${cmd[*]} ..."

    "${cmd[@]}" 2>&1
}

# Asks for confirmation returns yes|no
function confirm() {
    read -p "$1 ([y]es or [n]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}


# Shows the result of the command
function showSuccess() {
    echo
    echo "Tag {$prefix}v$major.$minor.$patch was created in local repository."
    echo
    echo "Push it:"
    echo
    echo "    git push origin {$prefix}v$major.$minor.$patch"
    echo
    echo "Delete tag:"
    echo
    echo "    git tag -d {$prefix}v$major.$minor.$patch"
    echo
}


# Get the last tag and breaks into parts
function getLastTag() {
    #get all tags from remote
    t=`git fetch --tags -f`
    lasttag=`git tag | sort -r --version-sort | grep "^${prefix}v[0-9]*\.[0-9]*\.[0-9]*" | head -1 2> /dev/null` || true

    if [[ -z "$lasttag" ]]; then
        lasttag="v0.0.0"
    fi

    lasttag=${lasttag:0}

    parts=(${lasttag//./ })

    major=${parts[0]}
    minor=${parts[1]}
    patch=${parts[2]}

    last="$major.$minor.$patch"
}

# Get last tag from repo and process the desired command
getLastTag

case "$type" in
    'patch')
        patch=$((patch + 1))
        ;;
    'minor')
        minor=$((minor + 1))
        patch=0
        ;;
    'major')
        major=${prefix}v$((major + 1))
        minor=0
        patch=0
        ;;
    *)
        echo "No mode selected"
        exit 0
esac

# Shows information
printf "Current version : %s\n" "$last"
printf "New tag         : %s.%s.%s\n\n" "$major" "$minor" "$patch"

# Forces tag push if --force option is set to "true"
if [ -n "$force" ]; then
    echo "execute git tag $major.$minor.$patch"
    echo "execute git push origin $major.$minor.$patch"
fi

# Creates local tag
if [[ ! -n "$force" && "no" == $(confirm "Do you agree?") ]]; then
    echo "No tag was created"
    exit 0;
fi

execute git tag "$major.$minor.$patch"

# Pushes tag
if [[ ! -n "$force" && "no" == $(confirm "Do you want to push this tag right now?") ]]; then
    echo "No tag was pushed"
    exit 0;
fi

execute git push origin "$major.$minor.$patch"

exit 0
