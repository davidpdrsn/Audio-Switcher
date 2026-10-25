# List available commands.
default:
    @just --list

# Build dist/Audio Switcher.app.
build:
    bash scripts/build-app.sh

# Build, install in /Applications, and restart the app.
install: build
    #!/usr/bin/env bash
    set -euo pipefail
    destination="/Applications/Audio Switcher.app"
    if [[ -w /Applications && ( ! -e "$destination" || -w "$destination" ) ]]; then
        rm -rf "$destination"
        ditto "dist/Audio Switcher.app" "$destination"
    else
        sudo rm -rf "$destination"
        sudo ditto "dist/Audio Switcher.app" "$destination"
    fi
    echo "Installed $destination"
    pkill -x "Audio Switcher" || true
    sleep 1
    open "$destination"
