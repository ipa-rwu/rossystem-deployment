#!/bin/bash

set -e
set -o pipefail
function builder_setup {
    apt_get_install python3-colcon-common-extensions
}
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
    colcon list --base-paths "/opt/ros/$ROS_DISTRO/share" --names-only
    colcon list --base-paths "$src" --names-only
}
function setup_rosdep {
    source "/opt/ros/$ROS_DISTRO/setup.bash"
    if [ "$ROS_VERSION" -eq 1 ]; then
        if ! command -v rosdep > /dev/null; then
            apt_get_install python-rosdep > /dev/null
        fi
    fi
    if [ "$ROS_VERSION" -eq 2 ]; then
        if ! command -v rosdep > /dev/null; then
            apt_get_install python3-rosdep > /dev/null
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
    comm -23 <(read_depends "$src" "$@"| sort -u) <(list_packages "$src" | sort -u) | xargs -r rosdep resolve | grep_opt -v '^#' | sort -u

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
    ROS_VERSION=0
    source "/opt/ros/$ROS_DISTRO/setup.bash"
    for file in $ws/src/*.rosinstall; do
        if [[ -f ${file} ]]; then
            if [ "$ROS_VERSION" -eq 2 ]; then
                if ! command -v vcstool > /dev/null; then
                    apt_get_install python3-vcstool > /dev/null
                fi
                if ! command -v git > /dev/null; then
                    apt_get_install git > /dev/null
                fi
                vcs import $ws/src/ < $file
                rm $file
        fi
    done;
    for folder in "$ws/src"/*; do
        if [[ -d ${folder} ]]; then
            for file in "$ws/src/${folder}/*.rosinstall" "$ws/src/${folder}/rosinstall"; do
                if [ -f ${file} ]; then
                    vcs import $ws/src/ < $file
                fi
            done;
        fi
    done;
    resolve_depends "$ws/src" depend build_depend build_export_depend | apt_get_install
    resolve_depends "$ws/src" depend build_export_depend exec_depend run_depend > "$ws/DEPENDS"
    cd $ws && colcon build
}

function test_workspace {
    local ws=$1; shift
    resolve_depends "$ws/src" depend exec_depend run_depend test_depend | apt_get_install
    cd $ws && colcon test
    colcon test-result --verbose
}

function install_depends {
    local ws=$1; shift
    apt_get_install < "$ws/DEPENDS"
}

function install_workspace {
    local ws=$1; shift
    cd $ws && colcon build --merge-install --install-base "/opt/ros/$ROS_DISTRO"
}

if [ -n "$*" ]; then
    "$@"
fi
