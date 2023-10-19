# Nyan Keys

An FPGA based mechanical keybaord controller design based around the Lattice ice40hx series of FPGA chips.

## Why?

The biggest question to be asked is why? The answer is simple. A quest to create the most performant keyboard
on planet earth. The additional performance is extracted through four means.

 - Per key programmable debounce counters (3 bit)
 - Per key parallel input _All keys are parallel without a scanning matrix_
 - Ultra fast SPI based serialization (1.6Mhz Tested)
 - nKRO - Though standard now it's nice to have becuase of the parallel interface

## FPGA IP

FPGA IP is designed to be build using Yosys and Nextpnr. Functional and tested on the Lattice ICE40HX1K 144TQFP. 
The IP is designed and seperated into 3 main parts.

 - Key switch cores keys.v)
 - SPI core (MODE 1) COPL=0, CPHA=1 (spi.v)
 - Global glue logic (spi_keys.v)

### Key Switching Core
Each key switch in your physical design will generate one key switch core. The key switch core is the programmable logic
that is used to read the keys state and perform debouncing. Since all mechanical switches will have some form of bounce to them.
This design uses a tunable 3 bit counter and a 'direction vector' store the output state of each key.

Switches are considered active low and this design leverages the interal pull resistors that are available on the 
outputs of the Lattice Ice40hx series ICs. 

| Key State | Logic Level |
| --------- | ----------- |
| Depressed | Low         |
| Released  | High        |

The debounce is handeled by an up down counter on each key. The counter starts at zero. When the key is depressed the counter will
increment by one each clock cycle. Once the counter has reached the top. The direction register if it is not already depressed _1'b1_ will change to a _1'b1_.
As long as the key is depressed the counter will remain at the top. If the logic for the key switches low the counter begins to count
down but the state is not allowed to change until the switch hits a 0 value the prevents noise from triggering a state switch.

## STM32 USB HID Interface
