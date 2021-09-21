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


## Runs a command with arguments, taking care of the --dry flag
function runCommand {
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


# Get the last tag and breaks into parts
function getLastTag {
    env=$1
    #get all tags from remote
    t=`git fetch --tags -f`
    lasttag=`git tag | sort -r --version-sort | grep "^${env}-v[0-9]*\.[0-9]*\.[0-9]*" | head -1 2> /dev/null` || true

    if [[ -z "$lasttag" ]]; then
        lasttag="v0.0.0"
    fi

    parts=(${lasttag//./ })
    parts=${parts#"$env-v"}

    major=${parts[0]}
    minor=${parts[1]}
    patch=${parts[2]}

    last="$major.$minor.$patch"
}

function generateTag {
    env=$1
    echo "Prefix: $env";
    echo "Semver type: $type";
    if [ -n "$force" ]; then
        echo "Forcing execution. I sure hope you know what you are doing."
    fi

    
    last='' # Will contain the last version tag found
    # Get last tag from repo and process the desired command
    getLastTag $env

    case "$type" in
        'patch')
            patch=$((patch + 1))
            ;;
        'minor')
            minor=$((minor + 1))
            patch=0
            ;;
        'major')
            major="$((major +1))"
            minor=0
            patch=0
            ;;
        *)
            echo "No mode selected"
            exit 0
    esac

    # Shows information
    printf "Current version : $env-v%s\n" "$last"
    printf "New tag         : ${env}-v%s.%s.%s\n\n" "$major" "$minor" "$patch"

    # Creates local tag
    if [[ ! -n "$force" && "no" == $(confirm "Do you agree?") ]]; then
        echo "No tag was created"
        exit 0;
    fi

    runCommand git tag "${env}-v$major.$minor.$patch"

    # Pushes tag
    if [[ ! -n "$force" && "no" == $(confirm "Do you want to push this tag right now?") ]]; then
        echo "No tag was pushed"
        exit 0;
    fi

    runCommand git push origin "${env}-v$major.$minor.$patch"
}

generateTag $prefix

exit 0
