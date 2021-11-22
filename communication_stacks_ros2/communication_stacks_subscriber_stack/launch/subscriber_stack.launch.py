from launch import LaunchDescription
from launch_ros.actions import Node

def generate_launch_description():
  ld = LaunchDescription()

  subscriber_node = Node(
    package="examples_rclpy_minimal_subscriber",
    executable="subscriber_lambda",
    name="subscriber_node",
    remappings=[
      ("minimal_subscriber", "subscriber")]
  )

  ld.add_action(subscriber_node)

  return ld
