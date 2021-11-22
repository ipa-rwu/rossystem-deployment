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
    # "/opt/ros/$ROS_DISTRO"/env.sh catkin_topological_order --only-names "/opt/ros/$ROS_DISTRO/share"
    # "/opt/ros/$ROS_DISTRO"/env.sh catkin_topological_order --only-names "$src"
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
    # comm -23 <(read_depends "$src" "$@"| sort -u) <(list_packages "$src" | sort -u) | xargs -r "/opt/ros/$ROS_DISTRO"/env.sh rosdep resolve | grep_opt -v '^#' | sort -u
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
    source "/opt/ros/$ROS_DISTRO/setup.sh"
    echo "ROS Version: $ROS_VERSION, ROS_DISTRO: $ROS_DISTRO"
    for file in $ws/src/*.rosinstall; do
        if [[ -f ${file} ]]; then
            echo "Found file $file"
            if [ "$ROS_VERSION" -eq 1 ]; then
                if ! command -v vcstool > /dev/null; then
                    apt_get_install python-vcstool > /dev/null
                fi
            fi
            if [ "$ROS_VERSION" -eq 2 ]; then
                if ! command -v vcstool > /dev/null; then
                    apt_get_install python3-vcstool > /dev/null
                fi
            fi
            if ! command -v git > /dev/null; then
                apt_get_install git > /dev/null
            fi
            if [ "$ROS_VERSION" != 0 ]; then
                vcs import $ws/src/ < $file
                rm $file
            fi
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
    cd $ws && colcon build
}

function test_workspace {
    local ws=$1; shift
    resolve_depends "$ws/src" depend exec_depend run_depend test_depend | apt_get_install
    cd $ws && colcon test
    colcon test-result --verbose
    # "/opt/ros/$ROS_DISTRO"/env.sh catkin_make_isolated -C "$ws" --make-args run_tests -j1
    # "/opt/ros/$ROS_DISTRO"/env.sh catkin_test_results --verbose "$ws"
}

function install_depends {
    local ws=$1; shift
    apt_get_install < "$ws/DEPENDS"
}

function install_workspace {
    local ws=$1; shift
    cd $ws && colcon build --merge-install --install-base "/opt/ros/$ROS_DISTRO"
    # "/opt/ros/$ROS_DISTRO"/env.sh catkin_make_isolated -C "$ws" --install --install-space "/opt/ros/$ROS_DISTRO"
}

if [ -n "$*" ]; then
    "$@"
fi
