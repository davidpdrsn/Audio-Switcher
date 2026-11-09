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
    # Wait for the old instance to exit, otherwise `open` just activates it instead of launching the new build.
    if pkill -x "Audio Switcher"; then
        for _ in {1..50}; do
            pgrep -x "Audio Switcher" > /dev/null || break
            sleep 0.1
        done
        pkill -9 -x "Audio Switcher" || true
    fi
    open "$destination"
    echo "Restarted Audio Switcher"
