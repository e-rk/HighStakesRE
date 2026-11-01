set -e

SPEEDTOOLS=$(jq -r '.speedtools' manifest.json)
GODOT=$(jq -r '.godot' manifest.json)
SPT_PIPELINE=$(jq -r '."spt-pipeline"' manifest.json)
FFMPEG=$(jq -r '.ffmpeg' manifest.json)

SPEEDTOOLS_URL=https://github.com/e-rk/speedtools/releases/download/v${SPEEDTOOLS}
GODOT_URL=https://github.com/godotengine/godot/releases/download/${GODOT}-stable
SPT_PIPELINE_URL=https://github.com/e-rk/spt-pipeline/releases/download/${SPT_PIPELINE}

mkdir bundle

pushd bundle
wget ${SPEEDTOOLS_URL}/speedtools-${SPEEDTOOLS}.zip
wget -O speedtool ${SPEEDTOOLS_URL}/speedtool
wget -O speedtool.exe ${SPEEDTOOLS_URL}/speedtool.exe
chmod +x speedtool
wget https://github.com/GyanD/codexffmpeg/releases/download/${FFMPEG}/ffmpeg-${FFMPEG}-essentials_build.zip
unzip ffmpeg-${FFMPEG}-essentials_build.zip
rm ffmpeg-${FFMPEG}-essentials_build.zip
popd

wget ${GODOT_URL}/Godot_v${GODOT}-stable_win64.exe.zip
wget ${GODOT_URL}/Godot_v${GODOT}-stable_linux.x86_64.zip
unzip -o Godot_v${GODOT}-stable_win64.exe.zip
rm Godot_v${GODOT}-stable_win64.exe.zip
unzip -o Godot_v${GODOT}-stable_linux.x86_64.zip
rm Godot_v${GODOT}-stable_linux.x86_64.zip

wget ${SPT_PIPELINE_URL}/installer_linux
wget ${SPT_PIPELINE_URL}/installer_windows.exe

chmod +x installer_linux

{
    git ls-files -- . ':!.github'
    find bundle -type f
    echo Godot_v${GODOT}-stable_win64.exe
    echo Godot_v${GODOT}-stable_win64_console.exe
    echo Godot_v${GODOT}-stable_linux.x86_64
    echo installer_linux
    echo installer_windows.exe
} | zip -MM highstakesre-bundle.zip -@
