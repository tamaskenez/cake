cake
====

cake for CMake, helper script for launching cmake and managing options

The **cake** project consists of 2 CMake scripts, **cake** and **cakecfg**. You can use **cake** to save typing the parameters for cmake again and again.

Usage: use **cake** in place of calling cmake directly. **cake** calls cmake with the parameters you specify in config files or on the command line.

You can use cakecfg or any text editor to manage the cake config files.

Extensive list of features:

- Multi-layered config files containing parameters controlling the generate and build steps of cmake. You can have per-user, per-cake-installation, per-session, per-source and per-build-dir config files (they're plain cmake files)
- Use cakecfg to add new parameters to the config files the same way you call cmake: e.g. `cakecfg -G Xcode` adds the Xcode generator to the current session
- Edit the cakecfg files with a text editor. You can also write CMake scripts in them.
- Use cakecfg to bind a CMake build dir to a source dir so you don't need to refer to the build dir: `cakecfg mysourcedir -b mybinarydir`
- Or let **cake** calculate a build directory automatically
- Launch Xcode or Visual Studio from the command-line: `cake --ide mysourcedir`
- Launch cmake-gui from the command-line: `cake --gui mysourcedir`
- Build multiple configurations or targets with simple command lines: `cake mysourcedir --install --debug-release`