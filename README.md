# AGV-Embedded

FPGA-based embedded systems projects developed for AGV applications.

## OV7670 Camera Interface

This project aims to interface the OV7670 camera module with an FPGA using Verilog HDL. It includes camera configuration through the SCCB interface and pixel-data capture in RGB565 format.

### Modules

| File | Description |
|---|---|
| `camera_top.v` | Top-level module connecting the camera configuration controller and SCCB master. |
| `ov7670_config.v` | FSM that sequences the OV7670 register configuration. |
| `sccb_master.v` | Implements SCCB serial communication for writing camera registers. |
| `capture.v` | Captures the camera's 8-bit pixel data and combines two bytes into a 16-bit RGB565 pixel. |

### Current Features

- Verilog-based, FSM-driven design.
- SCCB communication for camera register configuration.
- RGB565 pixel-data reconstruction.
- Modular RTL design for easier testing and integration.

### Planned Development

- Verify camera configuration and SCCB timing on hardware.
- Integrate the pixel-capture module with the top-level design.
- Implement pixel buffering using FPGA internal memory.
- Develop the VGA output interface.
- Integrate the complete camera-to-display pipeline.

### Tools and Technologies

- **HDL:** Verilog
- **FPGA Design Tool:** Intel Quartus Prime
- **Camera:** OV7670
- **Interfaces:** SCCB, parallel pixel-data interface

### Project Status

Work in progress. The modules are under development and require simulation and hardware validation before the complete system can be considered functional.
