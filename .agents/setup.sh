#!/usr/bin/env bash
set -euo pipefail

# Install OpenJDK 17 to match JavaVersion.VERSION_17 in app/build.gradle and CI.
if [ ! -d /usr/lib/jvm/java-17-openjdk-amd64 ] && command -v apt-get >/dev/null 2>&1; then
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openjdk-17-jdk-headless
fi

# Strip non-interactive early-return guard from ~/.bashrc and persist JAVA_HOME / PATH idempotently.
touch "$HOME/.bashrc"
sed -i '/case \$- in/,/esac/d' "$HOME/.bashrc" 2>/dev/null || true

LINE_JAVA='if [ -d /usr/lib/jvm/java-17-openjdk-amd64 ]; then export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64; case ":$PATH:" in *":$JAVA_HOME/bin:"*) ;; *) export PATH="$JAVA_HOME/bin:$PATH" ;; esac; fi'
LINE_BT='if [ -d "${ANDROID_HOME:-/opt/android-sdk}/build-tools/34.0.0" ]; then case ":$PATH:" in *":${ANDROID_HOME:-/opt/android-sdk}/build-tools/34.0.0:"*) ;; *) export PATH="${ANDROID_HOME:-/opt/android-sdk}/build-tools/34.0.0:$PATH" ;; esac; fi'
grep -qxF "$LINE_JAVA" "$HOME/.bashrc" || echo "$LINE_JAVA" >> "$HOME/.bashrc"
grep -qxF "$LINE_BT" "$HOME/.bashrc" || echo "$LINE_BT" >> "$HOME/.bashrc"

if [ -d /usr/lib/jvm/java-17-openjdk-amd64 ]; then
  export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
  case ":$PATH:" in *":$JAVA_HOME/bin:"*) ;; *) export PATH="$JAVA_HOME/bin:$PATH" ;; esac
fi

# Ensure Android SDK Platform 34 and Build-Tools 34.0.0 are installed.
ANDROID_SDK="${ANDROID_HOME:-/opt/android-sdk}"
if command -v sdkmanager >/dev/null 2>&1; then
  if [ ! -d "$ANDROID_SDK/platforms/android-34" ] || [ ! -d "$ANDROID_SDK/build-tools/34.0.0" ]; then
    yes | sdkmanager --sdk_root="$ANDROID_SDK" --licenses >/dev/null 2>&1 || true
    sdkmanager --sdk_root="$ANDROID_SDK" "platforms;android-34" "build-tools;34.0.0"
  fi
fi

# Pre-warm Gradle plugin and Android Lint caches without leaving untracked build outputs.
GRADLE_CACHE="${GRADLE_USER_HOME:-$HOME/.gradle}/caches"
HAS_AGP=""
HAS_LINT=""
if [ -d "$GRADLE_CACHE" ]; then
  HAS_AGP="$(find "$GRADLE_CACHE" -name 'gradle-8.2.2.jar' -print -quit 2>/dev/null || true)"
  HAS_LINT="$(find "$GRADLE_CACHE" -name 'lint-gradle-31.2.2.jar' -print -quit 2>/dev/null || true)"
fi
if [ -z "$HAS_AGP" ] || [ -z "$HAS_LINT" ]; then
  gradle assembleDebug lintDebug --no-daemon
  rm -rf app/build .gradle
fi
