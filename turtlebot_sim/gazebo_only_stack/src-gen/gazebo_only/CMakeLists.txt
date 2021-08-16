cmake_minimum_required(VERSION 2.8.3)
project(gazebo_only)

find_package(catkin REQUIRED)

catkin_package()


### INSTALL ###
install(DIRECTORY launch
  DESTINATION ${CATKIN_PACKAGE_SHARE_DESTINATION}
)