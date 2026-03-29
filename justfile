set shell := ["bash", "-euo", "pipefail", "-c"]

app_name := "Audio Switcher"
project := "Audio Switcher.xcodeproj"
scheme := "Audio Switcher"
derived_data := "build"

build:
    xcodebuild -project "{{project}}" -scheme "{{scheme}}" -configuration Release -derivedDataPath "{{derived_data}}" build

install: build
    sudo rm -rf "/Applications/{{app_name}}.app"
    sudo ditto "{{derived_data}}/Build/Products/Release/{{app_name}}.app" "/Applications/{{app_name}}.app"
    @echo "Installed /Applications/{{app_name}}.app"
