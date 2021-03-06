ROS Docker Images
=====

This project provides docker images for ROS, along with optional NVIDIA acceleration support, with a friendly startup script and VSCode development support.

Example use cases:
  - Testing a ROS network in a containerized environment
  - Running ROS melodic on Ubuntu 19.04, or on any unsupported platform

![](rviz.gif)

Docker Hub: https://hub.docker.com/r/jaci/ros  
GitHub: https://github.com/JacisNonsense/docker-ros

## Setting Up
1. Install the shell utilities
```bash
cd /tmp
git clone https://github.com/JacisNonsense/docker-ros

cd docker-ros
rm -r ~/.docker-ros
cp -r shell/ ~/.docker-ros
```

2. Edit your `.bashrc` / `.zshrc` to include the following lines
```bash
export UID=${UID}
# Debian/Ubuntu:
export GID=$(id -g $USER)
# other systems
export GID=${GID}

source ~/.docker-ros/ros.sh

# OPTIONAL: Isolate the default HOME for the docker container if you don't want to passthrough your own.
ROS_DOCKER_HOME=path/to/my/isolated/home

# OPTIONAL: If you "install" the docker-ros shell somewhere else, specifiy it
DOCKER_ROS_INSTALL=~/.docker-ros/
```

3. Install `nvidia-docker2` if you have a NVIDIA GPU: [nvidia-docker repo](https://github.com/NVIDIA/nvidia-docker)

## Running

```
$ ros <version>
```
Where `<version>` is one of the following:
  - `kinetic`, `melodic` - Aliases to `kinetic-desktop-full` and `melodic-desktop-full`
  - `kinetic-ros-core`, `kinetic-ros-base`, `kinetic-robot`, `kinetic-perception`, `kinetic-desktop`, `kinetic-desktop-full`
  - `melodic-ros-core`, `melodic-ros-base`, `melodic-robot`, `melodic-perception`, `melodic-desktop`, `melodic-desktop-full`

For example:
```
$ ros melodic
user@host:/work$ 
```

By default, the `ros` script will automatically:
  - Detect NVIDIA acceleration, and use the `nvidia-docker2` runtime (you must install it first!)
  - Setup X forwarding
  - Create a new container image, passing through your local user and `$HOME`
  - Passthrough your current directory to `/work` via docker bind mount
  - Make the container interactive (`-it --rm`)
  - Sets up host networking by default (or another networking type as specified: `--network=bridge`

You can specify your own image with `--image image`:
```
$ ros --image myname/myimage:version
```

You can build a custom local image based on an image from the docker hub (jaci/ros by default) applying a custom local Dockerfile layer on top of it to automate installation of any desired packages or unique setup with `--customlayer path/to/Dockerfile/ new_image_name ros_version`
  - Roughly equivalent to simply loading the default image, installing a bunch of packages, and then commiting the container to an image named new_image_name:ros_version.
  - Your custom Dockerfile should take a FROM argument to base the image upon.

```
$ # will build myimage based on a kinetic base with additional layer as defined by the passed Dockerfile directory path. 
$ ros --customlayer ~/path_to_dockerfile_directory/ myimage_name kinetic
$ # specify the default image to load when called from this local host directory:
$ ros-version set-local -i myimage:kinetic
$ # This allows the following to load that custom image later when called from same directory path:
$ ros
$ # Or from any other host path you can still call the custom image by full name:tag
$ ros --image myimage:kinetic

$ # repeat for a melodic variant
$ ros --customlayer ~/path_to_dockerfile_directory myimage melodic
$ # specify only the base image name in the local path to support multiple variants
$ ros-version set-local -i myimage
$ # now you can call either variant from this directoy, specifying the ROS version
$ ros melodic
$ ros kinetic
```

You can launch a program directly from the ros script if you don't require a bash prompt:
```
$ ros melodic rviz
```

## Using with Visual Studio Code (VSCode)
Install the `Remote - Container` extension and copy the `.devcontainer` folder into your VSCode workspace.

Open the command palette with `CTRL + SHIFT + P` and select `Remote-Containers: Reopen Folder in Container`. VSCode will build a new container and open the editor within the context of the container, providing C++ and Python intellisense with the ros installation.

By default, the VSCode containers do _not_ forward X11 nor run on the NVIDIA docker runtime. If you require GUI applications and/or NVIDIA acceleration, launch with `ros <version>` in a terminal (as seen in the 'Running' section above).
