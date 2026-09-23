# SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
# SPDX-License-Identifier: Apache-2.0
#
# The Android tools the scripts beside this one share: the SDK, adb, aapt2,
# JDK 21, Gradle, and the device a run goes to. Sourced, never run.

ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
[[ -d "$ANDROID_HOME/platform-tools" ]] || { echo "ERROR: no Android SDK at $ANDROID_HOME - set ANDROID_HOME"; exit 1; }
export ANDROID_HOME

ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR="$ANDROID_HOME/emulator/emulator"
AAPT2="$(ls -d "$ANDROID_HOME"/build-tools/*/aapt2 2>/dev/null | sort -V | tail -n 1)"

# The Gradle every head builds with; the wrapper's own download when no cache has it.
GRADLE_VERSION="9.4.1"

# JDK 21 for Gradle and the Android plugin, whatever JAVA_HOME says elsewhere.
java_home_21 () {
  if [[ -x /usr/libexec/java_home ]]; then
    /usr/libexec/java_home -v 21 2>/dev/null && return
  fi
  if [[ -n "${JAVA_HOME:-}" ]] && "$JAVA_HOME/bin/java" -version 2>&1 | grep -q '"21\.'; then
    echo "$JAVA_HOME"
  fi
}

# Gradle $GRADLE_VERSION: from the wrapper's cache, else downloaded into it.
gradle_binary () {
  local cached distribution
  cached="$(ls -d "$HOME"/.gradle/wrapper/dists/gradle-"$GRADLE_VERSION"-bin/*/gradle-"$GRADLE_VERSION"/bin/gradle 2>/dev/null | head -n 1)"
  if [[ -x "$cached" ]]; then
    echo "$cached"
    return
  fi

  distribution="$HOME/.gradle/wrapper/dists/gradle-$GRADLE_VERSION-bin/stateui"
  mkdir -p "$distribution"
  echo "downloading Gradle $GRADLE_VERSION..." >&2
  curl -fsSL "https://services.gradle.org/distributions/gradle-$GRADLE_VERSION-bin.zip" -o "$distribution/gradle.zip"
  unzip -q -o "$distribution/gradle.zip" -d "$distribution"
  rm -f "$distribution/gradle.zip"
  echo "$distribution/gradle-$GRADLE_VERSION/bin/gradle"
}

# Builds the Android head of the application in $1 - its Swift product $2, in
# configuration $3, for ABI $4 - and says where the APK is, on its last line.
build_head () {
  local app="$1" product="$2" configuration="$3" abi="$4" head build java gradle apk task
  head="$app/Platforms/Android"
  build="$app/.build-android"
  [[ -f "$head/build.gradle.kts" ]] || { echo "ERROR: $(basename "$app") has no Android head ($head)" >&2; return 1; }

  # A command substitution runs this function without `set -e`, so every
  # step that can fail says so: a failed build must never package the last one.
  STATEUI_ANDROID=1 SWIFT_CONFIG="$configuration" ABIS="$abi" \
    "$script_dir/build-swift.sh" "$app" "$product" "$build" >&2 || return 1

  java="$(java_home_21)"
  [[ -n "$java" ]] || { echo "ERROR: Gradle needs JDK 21 - install it, or point JAVA_HOME at one" >&2; return 1; }
  gradle="$(gradle_binary)" || return 1
  task="assemble$(tr '[:lower:]' '[:upper:]' <<< "${configuration:0:1}")${configuration:1}"

  JAVA_HOME="$java" "$gradle" \
    --project-dir "$head" \
    --project-cache-dir "$build/gradle-project" \
    --console=plain --quiet \
    -Pstateui.build="$build/gradle" \
    -Pstateui.java="$repository_dir/lib/StateUI.Android/Java" \
    -Pstateui.libraries="$build/jniLibs" \
    "$task" >&2 || return 1

  apk="$(find "$build/gradle/outputs/apk/$configuration" -name '*.apk' 2>/dev/null | head -n 1)"
  [[ -f "$apk" ]] || { echo "ERROR: Gradle made no APK under $build/gradle/outputs/apk/$configuration" >&2; return 1; }
  echo "$apk"
}

# The ABI of the device $1.
device_abi () {
  "$ADB" -s "$1" shell getprop ro.product.cpu.abi | tr -d '\r'
}

# The device a run goes to: the one named, else the only one attached.
device_serial () {
  local named="$1" attached
  if [[ -n "$named" ]]; then
    echo "$named"
    return
  fi

  attached="$("$ADB" devices | awk 'NR > 1 && $2 == "device" { print $1 }')"
  case "$(printf '%s\n' "$attached" | grep -c .)" in
    0) echo "ERROR: no device attached - start an emulator or name one" >&2; exit 1 ;;
    1) echo "$attached" ;;
    *) echo "ERROR: several devices attached - name one: $(echo $attached)" >&2; exit 1 ;;
  esac
}
