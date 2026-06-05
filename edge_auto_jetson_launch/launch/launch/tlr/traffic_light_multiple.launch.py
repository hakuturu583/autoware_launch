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


import json

import launch
from launch.actions import DeclareLaunchArgument
from launch.actions import IncludeLaunchDescription
from launch.actions import OpaqueFunction
from launch.substitutions import LaunchConfiguration
from launch.substitutions import PathJoinSubstitution
from launch_ros.substitutions import FindPackageShare


def create_traffic_light_recognition_container(camera_id):
    package = FindPackageShare("edge_auto_jetson_launch")
    include = PathJoinSubstitution([package, f"launch/tlr/traffic_light.launch.xml"])
    arguments = [("camera_id", str(camera_id))]
    return IncludeLaunchDescription(include, launch_arguments=arguments)


def launch_setup(context, *args, **kwargs):

    # Load all camera ids
    all_camera_ids = LaunchConfiguration("all_camera_ids").perform(context)

    # Convert string to list safely
    all_camera_ids = json.loads(all_camera_ids)

    # Create containers for all cameras
    traffic_light_recognition_containers = [
        create_traffic_light_recognition_container(camera_id) for camera_id in all_camera_ids
    ]
    return traffic_light_recognition_containers


def generate_launch_description():
    return launch.LaunchDescription(
        [
            DeclareLaunchArgument("all_camera_ids", description="camera index list"),
            OpaqueFunction(function=launch_setup),
        ]
    )
