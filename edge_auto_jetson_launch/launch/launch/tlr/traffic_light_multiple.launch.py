# Copyright 2024 TIER IV, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


from distutils.util import strtobool
import json

import launch
from launch.actions import DeclareLaunchArgument
from launch.actions import GroupAction
from launch.actions import IncludeLaunchDescription
from launch.actions import LogInfo
from launch.actions import OpaqueFunction
from launch.actions import TimerAction
from launch.substitutions import LaunchConfiguration
from launch.substitutions import PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def create_traffic_light_recognition_container(camera_id):
    package = FindPackageShare("edge_auto_jetson_launch")
    include = PathJoinSubstitution([package, "launch/tlr/traffic_light.launch.xml"])
    arguments = [
        ("camera_id", str(camera_id)),
        ("disable_camera_driver", "true"),
    ]
    return IncludeLaunchDescription(include, launch_arguments=arguments)


def create_camera_driver(camera_id):
    package = FindPackageShare("edge_auto_jetson_launch")
    include = PathJoinSubstitution([package, "launch/v4l2_camera.launch.xml"])
    container_name = f"traffic_light_node_container{camera_id}"
    arguments = [("camera_id", str(camera_id)), ("container_name", container_name)]
    return IncludeLaunchDescription(include, launch_arguments=arguments)


def wrap_with_delay(action, delay_sec, camera_id):
    description = f"v4l2 initialization for camera{camera_id}"
    if delay_sec <= 0.0:
        return GroupAction(
            actions=[
                LogInfo(
                    msg=(
                        "[v4l2_camera.launch] "
                        f"camera{camera_id}: scheduling {description} "
                        f"with startup_delay_sec={delay_sec:.1f}"
                    )
                ),
                LogInfo(
                    msg=(
                        "[v4l2_camera.launch] "
                        f"camera{camera_id}: starting {description} "
                        f"after startup_delay_sec={delay_sec:.1f}"
                    )
                ),
                action,
            ]
        )

    return GroupAction(
        actions=[
            LogInfo(
                msg=(
                    "[v4l2_camera.launch] "
                    f"camera{camera_id}: scheduling {description} "
                    f"with startup_delay_sec={delay_sec:.1f}"
                )
            ),
            TimerAction(
                period=delay_sec,
                actions=[
                    LogInfo(
                        msg=(
                            "[v4l2_camera.launch] "
                            f"camera{camera_id}: starting {description} "
                            f"after startup_delay_sec={delay_sec:.1f}"
                        )
                    ),
                    action,
                ],
            ),
        ]
    )


def launch_setup(context, *args, **kwargs):

    # Load all camera ids
    all_camera_ids = LaunchConfiguration("all_camera_ids").perform(context)
    disable_camera_driver = LaunchConfiguration("disable_camera_driver").perform(context)
    camera_start_interval_sec = float(
        LaunchConfiguration("camera_start_interval_sec").perform(context)
    )

    # Convert string to list safely
    all_camera_ids = json.loads(all_camera_ids)

    # TLR pipeline starts immediately; camera drivers are launched separately with delay.
    traffic_light_recognition_containers = [
        create_traffic_light_recognition_container(camera_id) for camera_id in all_camera_ids
    ]

    if bool(strtobool(disable_camera_driver)):
        camera_drivers = []
    else:
        camera_drivers = [
            wrap_with_delay(
                create_camera_driver(camera_id),
                camera_start_interval_sec * process_index,
                camera_id,
            )
            for process_index, camera_id in enumerate(all_camera_ids)
        ]

    return traffic_light_recognition_containers + camera_drivers


def generate_launch_description():
    return launch.LaunchDescription(
        [
            DeclareLaunchArgument("all_camera_ids", description="camera index list"),
            DeclareLaunchArgument(
                "disable_camera_driver",
                default_value="false",
                description="If true, skip v4l2 camera driver startup.",
            ),
            DeclareLaunchArgument(
                "camera_start_interval_sec",
                default_value="0.0",
                description="interval seconds between each camera driver startup",
            ),
            OpaqueFunction(function=launch_setup),
        ]
    )
