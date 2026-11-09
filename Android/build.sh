#!/bin/bash
#----------------------------------------------------------------
#  build.sh
#
#  Changelog:
#      Paulinchen  2026-11-08: Brought the Equipment Window into the package and left it out of Manifest.txt
#      Paulinchen  2026-11-07: Dropped the helper and Update.bat from the package checks
#                            - Copied the framework's one project, which holds the bridge and the runtime
#                            - Checked the bridge's exports by their mf_ names
#      Paulinchen  2026-10-30: Created
#
#----------------------------------------------------------------
#
# Builds the framework's package for JoiPlay on Android: the DLL's code as a NativeAOT library for
# linux-bionic-arm64 (ModFramework.so), the libssl stand-in, and the scripts, zipped as
# ModFramework/bin/Release/MGQ-Mod-Framework-<version>-android.zip, then checks the zip.
#
# Runs on Linux or in WSL, never on Windows itself:
#   Android/build.sh [version]        build and check, the version defaulting to the project's
#   Android/build.sh check <zip>      check a zip built before
#
# Needs the .NET 10 SDK and the Android NDK r28c. DOTNET_ROOT and ANDROID_NDK_ROOT point at them;
# without them the folders of the WSL test setup are used. The build runs in a copy of the
# sources outside the repository (MF_ANDROID_WORK, ~/mf-android-build by default), so the Windows
# build's obj folders are never touched.

set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DOTNET_ROOT=${DOTNET_ROOT:-$HOME/dotnet}
ANDROID_NDK_ROOT=${ANDROID_NDK_ROOT:-$HOME/android-ndk/android-ndk-r28c}
WORK=${MF_ANDROID_WORK:-$HOME/mf-android-build}
RID=linux-bionic-arm64

# The oldest Android the libraries are linked for; JoiPlay needs Android 7.
API_LEVEL=24

export PATH="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin:$DOTNET_ROOT:$PATH"
export DOTNET_ROOT DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1

# Fails the build with a reason.
fail() {
    echo "android build: $*" >&2
    exit 1
}

# Checks a package: the scripts, the bundled mods, the library for arm64 with the framework's
# exports and nothing needed beyond Android's own libraries, the stand-in named libssl.so that needs
# the engine, no Windows file, and a Manifest.txt that names only the framework's own files.
check() {
    local zip=$1 dir
    [ -f "$zip" ] || fail "$zip does not exist"
    dir=$(mktemp -d)
    trap 'rm -rf "$dir"' RETURN
    unzip -q "$zip" -d "$dir"
    local folder="$dir/Patch/Mod_Framework"
    for file in "Patch/!Mod_Framework.rb" Patch/Mod_Framework/loader.rbx Patch/Mod_Framework/boot.rbx \
        Patch/Mod_Framework/Version.txt Patch/Mod_Framework/Manifest.txt Patch/Mod_Framework/ModFramework.so \
        Patch/Mod_Framework/libssl.so Patch/Mod_Framework/Scripts/bridge.rbx Patch/Equipment_Window.rb; do
        [ -f "$dir/$file" ] || fail "$zip lacks $file"
    done
    [ ! -e "$folder/ModFramework.dll" ] || fail "$zip holds the Windows file ModFramework.dll"
    llvm-readelf -h "$folder/ModFramework.so" | grep -q "AArch64" || fail "ModFramework.so is not built for arm64"
    local needed exports
    needed=$(llvm-readelf -d "$folder/ModFramework.so" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p' | sort | paste -sd ' ')
    for library in $needed; do
        case $library in
            libc.so | libm.so | libdl.so | liblog.so | libz.so) ;;
            *) fail "ModFramework.so needs $library, which is none of the NDK libraries every app may load" ;;
        esac
    done
    exports=$(llvm-nm -D --defined-only "$folder/ModFramework.so" | awk '{print $3}' | sed 's/@.*//')
    for export in mf_bridge_open mf_call mf_reply mf_drain mf_start_android; do
        grep -qx "$export" <<< "$exports" || fail "ModFramework.so lacks the export $export"
    done
    llvm-readelf -d "$folder/libssl.so" | grep -q "SONAME.*\[libssl.so\]" || fail "the stand-in is not named libssl.so"
    llvm-readelf -d "$folder/libssl.so" | grep -q "NEEDED.*\[libmkxp19.so\]" || fail "the stand-in does not need the engine"
    while IFS= read -r line; do
        line=${line%$'\r'}
        [ -f "$dir/${line//\\//}" ] || fail "Manifest.txt names $line, which the zip lacks"
        case $line in
            'Patch\!Mod_Framework.rb' | 'Patch\Mod_Framework\'*) ;;
            *) fail "Manifest.txt names $line, which is no file of the framework" ;;
        esac
    done < "$folder/Manifest.txt"
    echo "android build: $zip passed its check ($(du -k "$folder/ModFramework.so" | cut -f1) KB library, needs $needed)"
}

if [ "${1:-}" = "check" ]; then
    command -v llvm-readelf > /dev/null || fail "the NDK's llvm tools are not at $ANDROID_NDK_ROOT"
    check "$2"
    exit 0
fi

command -v dotnet > /dev/null || fail "no dotnet at $DOTNET_ROOT"
command -v clang > /dev/null || fail "no NDK at $ANDROID_NDK_ROOT"
VERSION=${1:-$(sed -n 's:.*<Version>\(.*\)</Version>.*:\1:p' "$REPO/ModFramework/ModFramework.csproj" | head -1)}
[ -n "$VERSION" ] || fail "no version given and none in ModFramework.csproj"

echo "android build: $VERSION in $WORK"
rm -rf "$WORK"
mkdir -p "$WORK"
tar -C "$REPO" --exclude=bin --exclude=obj -cf - Directory.Build.targets GameScript ModFramework Android Samples/Equipment_Window.rb | tar -C "$WORK" -xf -

# The stand-in names the engine as needed, so its lookups reach the engine's OpenSSL. Only the name
# counts, so it links against an empty library of that name instead of JoiPlay's own.
mkdir -p "$WORK/standin"
echo "" > "$WORK/standin/empty.c"
clang --target=aarch64-linux-android$API_LEVEL -shared -fPIC "$WORK/standin/empty.c" -o "$WORK/standin/libmkxp19.so" -Wl,-soname,libmkxp19.so
clang --target=aarch64-linux-android$API_LEVEL -O2 -shared -fPIC "$WORK/Android/libssl_standin.c" -o "$WORK/standin/libssl.so" \
    -Wl,-soname,libssl.so -Wl,--no-as-needed "$WORK/standin/libmkxp19.so"
llvm-strip --strip-unneeded "$WORK/standin/libssl.so"

dotnet publish "$WORK/ModFramework" -c Release -r $RID -p:Version="$VERSION" -p:DisableUnsupportedError=true \
    -p:PublishAotUsingRuntimePack=true -nologo
PUBLISHED="$WORK/ModFramework/bin/Release/net10.0/$RID/publish"

# The layout of the PC package, with the library and the stand-in in place of the DLL.
# Manifest.txt lists every file of the framework; the Equipment Window is a mod of its own.
PACKAGE="$WORK/Shipping-android"
FOLDER="$PACKAGE/Patch/Mod_Framework"
mkdir -p "$FOLDER/Scripts" "$FOLDER/Graphics"
cp "$WORK/GameScript/!Mod_Framework.rb" "$WORK/Samples/Equipment_Window.rb" "$PACKAGE/Patch/"
find "$WORK/GameScript/Mod_Framework" -maxdepth 1 -type f -exec cp {} "$FOLDER/" \;
cp "$WORK/GameScript/Mod_Framework/Scripts/"*.rbx "$FOLDER/Scripts/"
cp "$WORK/GameScript/Mod_Framework/Graphics/"*.png "$FOLDER/Graphics/"
cp "$PUBLISHED/ModFramework.so" "$PUBLISHED/Version.txt" "$WORK/standin/libssl.so" "$FOLDER/"
touch "$FOLDER/Manifest.txt"
(cd "$PACKAGE" && find "Patch/!Mod_Framework.rb" Patch/Mod_Framework -type f | LC_ALL=C sort | sed 's:/:\\:g; s/$/\r/') > "$FOLDER/Manifest.txt"

ZIP="$WORK/MGQ-Mod-Framework-$VERSION-android.zip"
(cd "$PACKAGE" && zip -qrX "$ZIP" Patch)
check "$ZIP"
mkdir -p "$REPO/ModFramework/bin/Release"
cp "$ZIP" "$REPO/ModFramework/bin/Release/"
echo "android build: -> $REPO/ModFramework/bin/Release/$(basename "$ZIP")"
