set -e

mkdir bundle

pushd bundle
wget https://github.com/e-rk/speedtools/releases/download/v$(jq -r '.speedtools' ../manifest.json)/speedtools-$(jq -r '.speedtools' ../manifest.json).zip
wget https://github.com/GyanD/codexffmpeg/releases/download/$(jq -r '.ffmpeg' ../manifest.json)/ffmpeg-$(jq -r '.ffmpeg' ../manifest.json)-essentials_build.zip
unzip ffmpeg-$(jq -r '.ffmpeg' ../manifest.json)-essentials_build.zip
rm ffmpeg-$(jq -r '.ffmpeg' ../manifest.json)-essentials_build.zip
popd

wget https://github.com/godotengine/godot/releases/download/$(jq -r '.godot' manifest.json)-stable/Godot_v$(jq -r '.godot' manifest.json)-stable_win64.exe.zip
wget https://github.com/godotengine/godot/releases/download/$(jq -r '.godot' manifest.json)-stable/Godot_v$(jq -r '.godot' manifest.json)-stable_linux.x86_64.zip
unzip -o Godot_v$(jq -r '.godot' manifest.json)-stable_win64.exe.zip
rm Godot_v$(jq -r '.godot' manifest.json)-stable_win64.exe.zip
unzip -o Godot_v$(jq -r '.godot' manifest.json)-stable_linux.x86_64.zip
rm Godot_v$(jq -r '.godot' manifest.json)-stable_linux.x86_64.zip

wget https://github.com/e-rk/spt-pipeline/releases/download/$(jq -r '."spt-pipeline"' manifest.json)/installer_linux
wget https://github.com/e-rk/spt-pipeline/releases/download/$(jq -r '."spt-pipeline"' manifest.json)/installer_windows.exe

chmod +x installer_linux

zip -r highstakesre-bundle.zip . -x .git -x .github
