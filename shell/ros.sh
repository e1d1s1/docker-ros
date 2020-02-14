#!/bin/bash

#install
#cd /tmp
#git clone https://github.com/e1d1s1/docker-ros
#cd docker-ros
#cp -r . ~/.docker-ros
#cp -r shell/ ~/.docker-ros

#defined in bash.rc
#DOCKER_ROS_INSTALL="$( cd "$(dirname "$0")" ; pwd -P )"
ROS_DOCKER_PATH=${DOCKER_ROS_INSTALL:-~/.docker-ros/}

ROS_DOCKER_DEFAULT_IMG=jaci/ros

ROS_DOCKER_HOME=${ROS_DOCKER_HOME:-$HOME}

ROS_DOCKER_XSOCK=/tmp/.X11-unix
ROS_DOCKER_XAUTH=/tmp/.docker.xauth

ROS_DOCKER_VERS_FILE=".docker-ros-version"
ROS_DOCKER_IMG_FILE=".docker-ros-image"
LOCAL_VERS_FILE="./$ROS_DOCKER_VERS_FILE"
USER_VERS_FILE="$ROS_DOCKER_PATH/$ROS_DOCKER_VERS_FILE"

ros-xauth() {
  touch $1
  xauth nlist $DISPLAY | sed -e 's/^..../ffff/' | xauth -f $1 nmerge -
}

ros-version() {
  if [[ $# -gt 0 ]]; then
    action="$1"
    if [[ "$action" == "get" || "$action" == "get-local" ]]; then
      if [[ -f $LOCAL_VERS_FILE ]]; then
        cat $LOCAL_VERS_FILE
      elif [[ -f $USER_VERS_FILE ]]; then
        cat $USER_VERS_FILE
      elif [[ "$action" == "get" ]]; then
        echo $ROS_DOCKER_DEFAULT_IMG:melodic
      fi
    elif [[ "$action" == "set" ]]; then
      if [[ $# -eq 2 ]]; then
        echo $ROS_DOCKER_DEFAULT_IMG:$2 > $USER_VERS_FILE
      elif [[ $# -eq 3 ]] && [[ "$2" == "-i" ]]; then
        echo $3 > $USER_VERS_FILE
      else
        echo "Usage: ros-version set [-i image] [version]"
      fi
    elif [[ "$action" == "set-local" ]]; then
      if [[ $# -eq 2 ]]; then
        echo $ROS_DOCKER_DEFAULT_IMG:$2 > $LOCAL_VERS_FILE
      elif [[ $# -eq 3 ]] && [[ "$2" == "-i" ]]; then
        echo $3 > $LOCAL_VERS_FILE
      else
        echo "Usage: ros-version set [-i image] [version]"
      fi
    fi
  else
    echo "Usage: ros-version <action>"
    echo "  actions:"
    echo "    get: Get the current active ros version"
    echo "    set: Set the user default ros version"
    echo "    set-local: Set the directory default ros version"
  fi
}

ros-launch() {
  local args=(
    --net=host 
    --cap-add=SYS_PTRACE
    --volume="$(pwd):/work"
  )

  local dockerargs=()
  local withx=y
  local nvidia=
  local root=
  local confined=
  local image="$(ros-version get-local)"
  local unrealsimplugin=
  local unreal=
  local layer=
  local layername=
  local tag="latest"

  # Try to detect nvidia support
  if command -v nvidia-smi > /dev/null; then
    nvidia=y
  fi

  while [[ $# -gt 0 ]]
  do
    key="$1"
    case $key in 
      --confine)
        confined=y
        shift
        ;;
      --unconfine)
        confined=
        shift
        ;;
      --nvidia)
        nvidia=y
        shift
        ;;
      --no-nvidia)
        nvidia=
        shift
        ;;
      --no-x)
        withx=
        shift
        ;;
      --root)
        root=y
        shift
        ;;
      --rm)
        dockerargs=( "${dockerargs[@]}" --rm )
        shift
        ;;
      -it|--interactive)
        dockerargs=( "${dockerargs[@]}" -it )
        shift
        ;;
      -d|--docker)
        dockerargs=( "${dockerargs[@]}" $2 )
        shift
        shift
        ;;
      -i|--image)
        image="$2"
        shift
        shift
        ;;
      -l|--customlayer)
        layer="$2"
        layername="$3"
        shift
        shift
        shift
        ;;        
      -v|--version)
        image="$ROS_DOCKER_DEFAULT_IMG:$2"
        shift
        shift
        ;;
      -s|--unrealsimulation)
        unreal="$2"
        unrealsimplugin="$3"
        shift
        shift
        shift
        ;;
      *)
        if [[ -z "$image" ]]; then
          echo "using image $ROS_DOCKER_DEFAULT_IMG:$1"
          image="$ROS_DOCKER_DEFAULT_IMG:$1"
          tag="$1"
        fi
        shift
        ;;
    esac
  done

  echo "Starting ROS Docker Container with image $image"

  if [[ -n "$withx" ]]; then
    # X Forwarding Enabled
    local XSOCK=$ROS_DOCKER_XSOCK
    local XAUTH=$ROS_DOCKER_XAUTH

    ros-xauth $XAUTH

    args=( 
      "${args[@]}"
      --env="DISPLAY"
      --volume="${XSOCK}:${XSOCK}:rw" 
      --volume="${XAUTH}:${XAUTH}:rw" 
      --env="XAUTHORITY=${XAUTH}"
    )
  fi

  if [[ -n "$nvidia" ]]; then
    # NVIDIA Runtime Enabled
    args=( "${args[@]}" --gpus all )
  fi
  
  if [[ -n "$unreal" ]]; then
    args=( 
      "${args[@]}"
      --volume $unreal:/UnrealEngine
    )
    
    if [[ "${unrealsimulation,,}" == *"airsim"* ]]; then
      args=( 
        "${args[@]}"
        --volume $unrealsimulation:/AirSim
      )
    fi
    
    if [[ "${unrealsimulation,,}" == *"carla"* ]]; then
      args=( 
        "${args[@]}"
        --volume $unrealsimulation:/carla
      )
    fi
    
  fi

  if [[ -z "$root" ]]; then
    # Build new container with appropriate user
    args=(
      "${args[@]}"
      --env HOME=$HOME
      --env UID=$UID
      --env GID=$GID
      --volume $ROS_DOCKER_HOME:$HOME
    )
    
    echo "Building docker image from $image"
       
    if [[ -n "$layer" ]]; then
      echo "building custom layer as $layername:$tag"
      $(docker build -q -t ${layername}:${tag} --build-arg FROM=$image $layer)
      echo "base layer complete"
      ros-version set-local -i ${layername}:${tag}
      image=$(docker build -q --build-arg FROM=${layername}:${tag} --build-arg USER=$USER --build-arg UID=$UID --build-arg GID=$GID $ROS_DOCKER_PATH)
    else
      image=$(docker build -q --build-arg FROM=$image --build-arg USER=$USER --build-arg UID=$UID --build-arg GID=$GID $ROS_DOCKER_PATH)
    fi
    
    echo "build complete for $image"
  fi

  if [[ -z "$confined" ]]; then
    # Unconfined
    # Required for melodic (ubuntu 18.04 container).
    # Really, it boils down to this: https://github.com/moby/moby/issues/38442
    # To avoid having to add new apparmor profiles, we can run unconfined. The ROS installation
    # should be fairly trusted, but it can be avoided by setting ROS_DOCKER_UNCONFINED to false
    args=( "${args[@]}" --security-opt apparmor:unconfined )
  fi

  args=( "${args[@]}" "${dockerargs[@]}" $image )

  docker run ${args[@]} $@
}

ros() {
  ros-launch --rm -it $@
}
