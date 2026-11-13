#!/usr/bin/env bash
# Generates the android/ and ios/ folders and applies VettuVoli's settings.
# Run once from the project root:  bash tool/setup_platforms.sh
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not on PATH. See https://docs.flutter.dev/get-started/install" >&2
  exit 1
fi

# Creates the native projects. Existing files (lib/, pubspec.yaml) are kept.
flutter create --org com.vettuvoli --project-name vettuvoli --platforms android,ios .

# The template test references a counter app that doesn't exist here.
rm -f test/widget_test.dart

python3 tool/patch_platforms.py

flutter pub get
echo
echo "Setup complete. Run:  flutter run          (debug on a connected phone)"
echo "                or:  flutter build apk --release"
