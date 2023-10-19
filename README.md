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

FPGA IP is designed to be build using Yosys and Nextpnr. Functional and tested on the Lattice ICE40HX1K 144TQFP. 
The IP is designed and seperated into 3 main parts.
 - Key switch core
 - SPI core (MODE 1) COPL=0, CPHA=1
 - Global glue logic

### Key Switching Core
Each key switch in your physical design will generate one key switch core. The key switch core is the programmable logic
that is used to read the keys state and perform debouncing.

## STM32 USB HID Interface
