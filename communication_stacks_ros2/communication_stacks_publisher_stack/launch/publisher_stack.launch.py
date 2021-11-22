from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
  ld = LaunchDescription()

  publisher_node = Node(
    package="examples_rclpy_minimal_publisher",
    executable="publisher_local_function",
    name="publisher_node",
    remappings=[
      ("minimal_publisher", "publisher")]
  )

  ld.add_action(publisher_node)

  return ld
