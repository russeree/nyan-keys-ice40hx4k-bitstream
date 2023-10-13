# Nyan Keys

An FPGA based mechanical keybaord controller design based around the Lattice ice40hx series of FPGA chips.

## Why?

The biggest question to be asked is why? The answer is simple. A quest to create the most performant keyboard
on planet earth. The additional performance is extracted through four means.

    - Per key programmable debounce counters (2 bit)
    - Per key parallel input _All keys are parallel without a scanning matrix_
    - Ultra fast SPI based serialization
    - Lowest possible latency from key to computer
    - nKRO - Though standard now it's nice to have becuase of the parallel interface

## FPGA IP

FPGA IP is designed to be build using Yosys and Nextpnr. 

## STM32 USB HID Interface
