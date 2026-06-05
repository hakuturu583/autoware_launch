#!/usr/bin/env python3

# Copyright 2024 Tier IV, Inc.
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
import subprocess
import time
import uuid

import rclpy
from rclpy.node import Node


class ReadoutDelaySetter(Node):
    def __init__(self):
        super().__init__("readout_delay_setter")
        self.declare_parameter("camera_id", 10)
        self.declare_parameter("bus_number", 40)
        self.declare_parameter("delay_ms", 95.784)
        self.declare_parameter("one_h", 0.0120)

        camera_id = self.get_parameter("camera_id").get_parameter_value().integer_value
        bus_number = self.get_parameter("bus_number").get_parameter_value().integer_value
        delay_ms = self.get_parameter("delay_ms").get_parameter_value().double_value
        one_h = self.get_parameter("one_h").get_parameter_value().double_value

        rclpy.logging.get_logger("readout_delay_setter").info(
            f"camera_id: {camera_id}, bus_number: {bus_number}, delay_ms: {delay_ms}, one_h: {one_h}"
        )

        self.wait_v4l2(camera_id)
        self.set_readout_delay(bus_number, delay_ms, one_h)

    def set_readout_delay(self, bus_number, delay_ms, one_h):
        delay_in_line = delay_ms / one_h

        delay_in_line = "{:06x}".format(int(delay_in_line))
        for i, suffix in enumerate(["fd", "fe", "ff"]):
            self.write_to(suffix, delay_in_line[(2 - i) * 2 : (3 - i) * 2], bus_number)
            time.sleep(0.1)

    def write_to(self, target_reg_suffix, value_suffix, bus_number):
        target_reg = "0x" + target_reg_suffix
        value = "0x" + value_suffix
        regs = [
            "0x33",
            "0x47",
            "0x15",
            "0x0",
            "0x0",
            "0x0",
            "0xe0",
            "0x0",
            "0x80",
            "0x1",
            "0x0",
            "0x0",
            "0x0",
            "0x34",
            "0x0",
            "0x0",
            "0x0",
            target_reg,
            "0x1",
            "0x0",
            "0x0",
            value,
            "0x0",
            "0x0",
            "0x0",
            "0x2",
            "0x1",
        ]
        regs_str = " ".join(regs)
        check_sum = 0
        for reg in regs:
            check_sum += int(reg, 16)
        check_sum = check_sum & 0xFF
        check_sum = "0x" + str(hex(check_sum))[2:]
        command = f"i2ctransfer -f -y {bus_number} w28@0x6d {regs_str} {check_sum} r6"
        rclpy.logging.get_logger("readout_delay_setter").debug(f"command: {command}")
        rclpy.logging.get_logger("readout_delay_setter").debug(
            f"target regisers are: {regs_str}, {check_sum}"
        )
        subprocess.run(command, shell=True)

    def has_numbers(self, in_str):
        return any(char.isdigit() for char in in_str)

    def wait_v4l2(self, camera_id):
        command = f"ros2 topic echo /sensing/camera/camera{camera_id}/image_raw/compressed --field header.stamp --once"
        while True:
            try:
                output = subprocess.run(command, shell=True, capture_output=True, text=True)
                rclpy.logging.get_logger("readout_delay_setter").info(
                    f"output.stdout: {output.stdout}"
                )
            except subprocess.CalledProcessError as cpe:
                rclpy.logging.get_logger("readout_delay_setter").error(
                    "subprocess err. "
                    + cpe.stderr
                    + "\n"
                    + "returncode: "
                    + str(cpe.returncode)
                    + "\n"
                    + "cmd: "
                    + cpe.cmd
                )
            if (
                "sec" in output.stdout
                and "nanosec" in output.stdout
                and self.has_numbers(output.stdout)
            ):
                break


def main():
    rclpy.init()
    node = ReadoutDelaySetter()
    rclpy.shutdown()


if __name__ == "__main__":
    main()
