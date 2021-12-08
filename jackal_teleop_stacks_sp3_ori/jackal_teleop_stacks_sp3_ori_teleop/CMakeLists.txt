cmake_minimum_required(VERSION 2.8.3)
project(jackal_teleop_stacks_sp3_ori_teleop)

find_package(catkin REQUIRED)

catkin_package()


### INSTALL ###
install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)