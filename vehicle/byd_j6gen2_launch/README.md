# byd_j6gen2_launch

Vehicle model for the CARLA 0.10 `vehicle.byd.j6gen2` chassis, the ego used by the
Odaiba closed-loop runs.

It exists because `sample_vehicle` models a Lincoln MKZ (wheel_base 2.79 m) while
this chassis is 7.26 m long with a 5.4 m wheel base, so planning with
`sample_vehicle` produces roughly half the intended curvature. The geometry in
`byd_j6gen2_description/config/vehicle_info.param.yaml` is measured in CARLA; the
matching steer conversion lives in `autoware_carla_interface`'s
`config/vehicle_physics.yaml` under `vehicle.byd.j6gen2`.

Use it with `vehicle_model:=byd_j6gen2`.

The visual mesh is still the Lexus body inherited from `sample_vehicle_launch`; it
only affects RViz, not planning or control.
