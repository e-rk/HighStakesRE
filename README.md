# HighStakesRE

This project is an attempt at reverse engineering and re-making the Need For Speed 4 High Stakes experience in Godot engine.

# Objectives

* re-implementation of the original physics
* compatibility with community addons through one-click conversion
* multiplayer
* moddability

# Start-up guide

The project does not come with any cars and tracks from the original game on its own.
You must own the original game and convert the cars and tracks yourself locally.

## Requirements

* Blender 5.0.1
* Godot 4.6

## Automated setup instructions

1. Download the latest [bundle][4] found under `Assets`. The bundle contains the remake project files, `speedtool` addon for Blender and Godot engine.
2. Run `installer_windows.exe` of `installer_linux` depending on your operating system
3. Provide path to the directory containing the original NFS4 High Stakes game
4. Provide path to Blender executable.
   The default path might be incorrect if Blender was installed in non-default directory.
   It is possible to automatically install Blender by clicking the `Install Blender` checkbox.
   In case of problems with this option, install [Blender][1] manually and provide the path to the installer program.
5. Click `Next`. The conversion process will start.
6. After the conversion completes, you can run the game by starting `Godot_v4.6-stable_win64.exe` or `Godot_v4.6-stable_linux.x86_64` depending on your operating system.

## Manual setup instructions

1. Install [Blender][1], [speedtools addon][2] and [Godot][3]
2. Open the project in Godot, close it, and open it again. Otherwise strange things happen.
2. Import a track with the following options enabled:
	- Import shading
	- Import collision
	- Import cameras
	- Import ambient
3. Export the track into the `./import/tracks` directory
	- For example, export map `UK` into `./import/tracks/UK/UK.glb`
	- Enable the following options and keep the rest at default values:
		- Include -> Data -> Custom properties
		- Include -> Data -> Cameras
		- Include -> Data -> Lights
		- Data -> Material -> Unused images
		- Data -> Mesh -> Attributes
4. Import a car
5. Export the car into the `./import/cars` directory
	- For example, export B911 into `./import/cars/B911/B911.glb`
	- Enable the following options and keep the rest at default values:
		- Include -> Data -> Custom properties
		- Data -> Mesh -> Attributes
		- Include -> Data -> Lights
6. Wait for Godot to process the asset. This may take a while.
7. Run the project
8. Select a track and a car. Click `Start game` button
9. Drive around

The conversion steps above will be automated later on.

# Keyboard bindings

The keyboard bindings are currently non-configurable. Here is the list:

* Arrow keys - steering, acceleration, braking
* R - reset position
* A - shift up
* Z - shift down
* Esc - end race

# Notice

EA has not endorsed and does not support this project.

[1]: https://www.blender.org/download/
[2]: https://github.com/e-rk/speedtools
[3]: https://godotengine.org/
[4]: https://github.com/e-rk/HighStakesRE/releases
