#!/bin/bash
camera_ids=(3 4 9 10)
camera_num=${#camera_ids[*]}
echo "total number of cameras" ${camera_num}
# 43: camera3, 42: camera4, 41: camera9, 40: camera10
buses=(${2:-43} ${2:-42} ${2:-41} ${2:-40})
buses_size=${#buses[*]}
# delay values for camera3, camera4, camera9, camera10
delays_in_ms=(${1:-37.451} ${1:-65.228} ${1:-6.895} ${1:-95.784})
delays_size=${#delays_in_ms[*]}

if [[ ! ${buses_size} -eq ${camera_num} ]]; then
    echo "total numbers are different between camera and bus, these should be same."
    echo "total number of camera" ${camera_num} "total number of bus" ${buses_size}
    exit 1
fi
if [[ ! ${delays_size} -eq ${camera_num} ]]; then
    echo "total numbers are different between camera and delay_in_ms, these should be same."
    echo "total number of camera" ${camera_num} "total number of delay" ${delay}
    exit 1
fi
# ONE_H=0.0167          # 1H = 0.0167[ms]
ONE_H=0.0120 # 1H = 0.0120[ms](?)

function write_to() {
    target_reg="0x${1}"
    value="0x${2}"
    regs=(0x33 0x47 0x15 0x0 0x0 0x0 0xe0 0x0 0x80 0x1 0x0 0x0 0x0 0x34 0x0 0x0 0x0
        ${target_reg} 0x1 0x0 0x0 ${value} 0x0 0x0 0x0 0x2 0x1)

    check_sum=0
    for i in ${regs[@]}; do
        ((check_sum += i))
    done
    check_sum=$((check_sum & 0xff))
    check_sum="0x$(printf '%x\n' ${check_sum})"
    i2ctransfer -f -y ${3} w28@0x6d $(echo "${regs[@]}" ${check_sum}) r6
}

for j in $(seq 0 3); do
    echo "--------------------" "camera_id" ${camera_ids[j]} "; bus" ${buses[j]} "; delay" ${delays_in_ms[j]} "--------------------"

    # Calculate the number of line to be set in HEX
    delay_in_line=$(echo "${delays_in_ms[j]} / ${ONE_H}" | bc | xargs printf '%06x\n')
    # delay_in_line="000064"    # 98.1
    # delay_in_line="0000c8"    # 99.3
    # delay_in_line="00012c"    # 100.5
    # memo: delay_in_line == 0x000256 if delay_in_ms == 10

    # Write to EX_VRESET_VDLY, which is 3-byte length register, byte by byte
    write_to "fd" $(echo ${delay_in_line:4:2}) ${buses[j]}
    sleep 0.1
    write_to "fe" $(echo ${delay_in_line:2:2}) ${buses[j]}
    sleep 0.1
    write_to "ff" $(echo ${delay_in_line:0:2}) ${buses[j]}
    sleep 0.1
done
