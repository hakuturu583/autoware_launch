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


def create_object_recognition(camera_id, container_name, yolox_precision, process_index):
    package = FindPackageShare("edge_auto_jetson_launch")
    include = PathJoinSubstitution([package, f"launch/object_recognition.launch.xml"])
    container_name += str(camera_id)
    arguments = [
        ("camera_id", str(camera_id)),
        ("roi_id", str(camera_id)),
        ("container_name", container_name),
        ("dla_core_id", str(-1)),  # 0 or 1, select -1 to run on GPU
        ("yolox_precision", yolox_precision),
        (
            "model_path",
            (
                "/opt/autoware/yolox-sPlus-opt-pseudoV2-T4-960x960-T4-seg16cls.onnx"
                if camera_id == 0
                else "/opt/autoware/mlmodels/yolox/yolox-sPlus-T4-960x960-debris.onnx"
            ),
        ),
        (
            "label_path",
            (
                "/opt/autoware/label.txt"
                if camera_id == 0
                else "/opt/autoware/mlmodels/yolox/label.txt"
            ),
        ),
    ]
    return IncludeLaunchDescription(include, launch_arguments=arguments)


def create_camera_driver(camera_id, container_name):
    package = FindPackageShare("edge_auto_jetson_launch")
    include = PathJoinSubstitution([package, f"launch/v4l2_camera.launch.xml"])
    container_name += str(camera_id)
    arguments = [("camera_id", str(camera_id)), ("container_name", container_name)]
    return IncludeLaunchDescription(include, launch_arguments=arguments)


def create_image_decompressor(camera_id, container_name):
    package = FindPackageShare("edge_auto_jetson_launch")
    include = PathJoinSubstitution([package, f"launch/image_transport_decompressor.launch.xml"])
    container_name += str(camera_id)
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
    object_recognition_camera_ids = LaunchConfiguration("object_recognition_camera_ids").perform(
        context
    )
    camera_driver_camera_ids = LaunchConfiguration("camera_driver_camera_ids").perform(context)
    live_sensor = LaunchConfiguration("live_sensor").perform(context)
    container_name = LaunchConfiguration("container_name").perform(context)
    yolox_precision = LaunchConfiguration("yolox_precision").perform(context)
    camera_start_interval_sec = float(
        LaunchConfiguration("camera_start_interval_sec").perform(context)
    )

    # Convert string to list safely
    object_recognition_camera_ids = json.loads(object_recognition_camera_ids)
    camera_driver_camera_ids = json.loads(camera_driver_camera_ids)

    # object recognition
    object_recognitions = [
        create_object_recognition(camera_id, container_name, yolox_precision, process_index)
        for process_index, camera_id in enumerate(object_recognition_camera_ids)
    ]
    # cspell: ignore decompressors
    # camera driver and image decompressor
    if bool(strtobool(live_sensor)):
        camera_drivers = [
            wrap_with_delay(
                create_camera_driver(camera_id, container_name),
                camera_start_interval_sec * process_index,
                camera_id,
            )
            for process_index, camera_id in enumerate(camera_driver_camera_ids)
        ]
        image_decompressors = []
    if not bool(strtobool(live_sensor)):
        camera_drivers = []
        image_decompressors = [
            create_image_decompressor(camera_id, container_name)
            for camera_id in camera_driver_camera_ids
        ]

    return object_recognitions + camera_drivers + image_decompressors


def generate_launch_description():
    return launch.LaunchDescription(
        [
            DeclareLaunchArgument("object_recognition_camera_ids", description="camera index list"),
            DeclareLaunchArgument("camera_driver_camera_ids", description="camera index list"),
            DeclareLaunchArgument("live_sensor", description="live camera driver or not"),
            DeclareLaunchArgument(
                "container_name", description="container name for object recognition"
            ),
            DeclareLaunchArgument(
                "camera_start_interval_sec",
                default_value="0.0",
                description="interval seconds between each camera driver startup",
            ),
            OpaqueFunction(function=launch_setup),
        ]
    )
