#!/bin/bash

set -e
set -o pipefail
function grep_opt {
    grep "$@" || [[ $? = 1 ]]
}
function update_list {
    local ws=$1; shift
    setup_rosdep
    if [ -f $ws/src/extra.sh ]; then
        $ws/src/extra.sh
    fi
}
function read_depends {
    local src=$1; shift
    for dt in "$@"; do
        grep_opt -rhoP "(?<=<$dt>)[\w-]+(?=</$dt>)" "$src"
    done
}
function list_packages {
    local src=$1; shift
    "/opt/ros/$ROS_DISTRO"/env.sh catkin_topological_order --only-names "/opt/ros/$ROS_DISTRO/share"
    "/opt/ros/$ROS_DISTRO"/env.sh catkin_topological_order --only-names "$src"
}
function setup_rosdep {
    if ! command -v rosdep > /dev/null; then
        if [ "$ROS_DISTRO" == "noetic" ]; then
            apt_get_install python3-rosdep > /dev/null
        else
            apt_get_install python-rosdep > /dev/null
        fi
    fi
    if command -v sudo > /dev/null; then
        sudo rosdep init || true
    else
        rosdep init | true
    fi
    rosdep update
}
function resolve_depends {
    local src=$1; shift
    comm -23 <(read_depends "$src" "$@"| sort -u) <(list_packages "$src" | sort -u) | xargs -r "/opt/ros/$ROS_DISTRO"/env.sh rosdep resolve | grep_opt -v '^#' | sort -u
}

function apt_get_install {
    local cmd=()
    if command -v sudo > /dev/null; then
        cmd+=(sudo)
    fi
    cmd+=(apt-get install --no-install-recommends -qq -y)
    if [ -n "$*" ]; then
        "${cmd[@]}" "$@"
    else
        xargs -r "${cmd[@]}"
    fi
}

function build_workspace {
    local ws=$1; shift
    apt_get_install build-essential
    setup_rosdep
    for file in "$ws/src/*.rosinstall"; do
        if [ -f ${file} ]; then
            if ! command -v git >/dev/null; then
                apt_get_install git > /dev/null
            fi
            if ! command -v wstool > /dev/null; then
                if [ "$ROS_DISTRO" == "noetic" ]; then
                apt_get_install python3-wstool > /dev/null
                else
                apt_get_install python-wstool > /dev/null
                fi
            fi
            wstool init $ws/src/
            wstool merge -t $ws/src/ $file
            wstool update -t $ws/src/
        fi
    done;
    for folder in "$ws/src"/*; do
        if [[ -d ${folder} ]]; then
            for file in "$ws/src/${folder}/*.rosinstall" "$ws/src/${folder}/rosinstall"; do
                if [ -f ${file} ]; then
            wstool merge -t $ws/src/ $file
            wstool update -t $ws/src/
                fi
            done;
        fi
    done;
    resolve_depends "$ws/src" depend build_depend build_export_depend | apt_get_install
    resolve_depends "$ws/src" depend build_export_depend exec_depend run_depend > "$ws/DEPENDS"
    "/opt/ros/$ROS_DISTRO"/env.sh catkin_make_isolated -C "$ws" -DCATKIN_ENABLE_TESTING=0
}

function test_workspace {
    local ws=$1; shift
    resolve_depends "$ws/src" depend exec_depend run_depend test_depend | apt_get_install
    "/opt/ros/$ROS_DISTRO"/env.sh catkin_make_isolated -C "$ws" -DCATKIN_ENABLE_TESTING=1
    "/opt/ros/$ROS_DISTRO"/env.sh catkin_make_isolated -C "$ws" --make-args run_tests -j1
    "/opt/ros/$ROS_DISTRO"/env.sh catkin_test_results --verbose "$ws"
}

function install_depends {
    local ws=$1; shift
    apt_get_install < "$ws/DEPENDS"
}

function install_workspace {
    local ws=$1; shift
    "/opt/ros/$ROS_DISTRO"/env.sh catkin_make_isolated -C "$ws" --install --install-space "/opt/ros/$ROS_DISTRO"
}

if [ -n "$*" ]; then
    "$@"
fi
