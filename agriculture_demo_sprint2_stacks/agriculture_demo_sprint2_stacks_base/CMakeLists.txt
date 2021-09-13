cmake_minimum_required(VERSION 2.8.3)
project(agriculture_demo_sprint2_stacks_base)

find_package(catkin REQUIRED)

catkin_package()


### INSTALL ###
install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)