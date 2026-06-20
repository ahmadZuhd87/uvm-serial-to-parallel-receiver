# UVM Serial-to-Parallel Receiver Verification

This project implements and verifies a configurable serial-to-parallel receiver using Verilog/SystemVerilog and UVM.

## Project Overview

The receiver converts serial input data into parallel output data. It supports:

- Start and stop bit detection
- Fixed baud rate of 1200 bps
- 100 MHz reference clock
- Configurable data size: 4, 5, 6, or 7 bits
- LSB-first data reception
- Optional even parity checking
- Framing error detection
- Parity error detection
- Data valid indication

## Verification Environment

The UVM testbench includes:

- Sequence item
- Directed sequences
- Driver
- Monitor
- Scoreboard
- Agent
- Environment
- UVM test
- Interface
- SystemVerilog assertions

## Test Cases

The verification covers:

- Reset behavior
- Valid frames without parity
- Valid frames with even parity
- Bad parity frames
- Framing error
- False start bit
- Enable-low frame
- Reset during frame
- Back-to-back packets

## Tools

- SystemVerilog
- UVM 1.2
- Synopsys VCS
- EDA Playground

## Authors

- Ahmad Zuhd
- Bara Mohsen
