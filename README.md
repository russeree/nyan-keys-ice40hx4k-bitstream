# Nyan Keys - An FPGA Powered Keyboard

An FPGA based mechanical keybaord controller design based around the Lattice ice40hx series of FPGA chips.

## Why?

The biggest question to be asked is why? The answer is simple. A quest to create the most performant keyboard
on planet earth. The additional performance is extracted through four means.

 - Per key programmable debounce counters (8 bit)
 - Per key parallel input _All keys are parallel without a scanning matrix_
 - Ultra fast SPI based serialization (1.6Mhz Tested)
 - nKRO - Though standard now it's nice to have becuase of the parallel interface

This design is targeted toward few primary groups.

 - __Gamers__ For the lowest possible latency.
 - __Power Users__ For the programability.
 - __Hobbyists__ For the hacks.
 - __Non standard layouts__ For users that need to be able to create a custom layout

## FPGA IP

FPGA IP is designed to be build using Yosys and Nextpnr. Functional and tested on the Lattice ICE40HX1K 144TQFP.
The IP is designed and seperated into 3 main parts.

 - Key switch cores (keys.v)
 - SPI core (MODE 0) COPL=0, CPHA=0 (spi.v)
 - Global glue logic (spi_keys.v)

### Key Switching Core
Each key switch in the nyan keys physical design will generate one key switch 'core'. The key switch core is the programmable logic
that is used to read the keys state and perform debouncing as well as produce an output state.

All mehcnial switches have some form of bounce to them. The term bounce is used to refer to the total time a singal takes
to settle. _As a real world example when you press a Cherry MX Blue/Green switch it could take up to 5ms before the singal has
stopped bouncing between high and low._ Removing debouncing logic on a keyboard would have the effect of the user seeing
double key presses.

This design uses a tunable 8 bit counter and a 'direction vector' store the output state of each key.

Switches are considered active low and this design leverages the interal pull resistors that are available on the 
outputs of the Lattice Ice40hx series ICs.

 - __Key state__ - Represents the physical key. [Pressed/Released]
 - __Logic Level__ - The logic level of net to the key itself.
 - __Direction State__ - Internal debounced logic level of the one hot key state register.

| Key State | Logic Level | Direction State |
| --------- | ----------- | --------------- |
| Depressed | Low         | Low             |
| Released  | High        | High            |

The debounce is handeled by an up down counter in each key core. The counter starts at zero. When the key is depressed the counter will
increment by one each clock cycle while the key is pressed. The inverse is also true when a key is released. Once the counter has reached the top.
The direction register if it is not already depressed _1'b1_ will change to a _1'b1_. As long as the key is depressed the counter will remain at the top.
When the key is released or even in a glitch counter begins to count down but the state is not allowed to change until the switch hits a 0 value.
This prevents noise or a bounce from triggering a key press.

### FPGA Limits

| FPGA           | Debounce Counter |
| -------------- | ---------------- |
| Ice40HX1k      | 3 bit            |
| Ice40HX4k      | 8 bit            |

### Future

One of the major features that could be implemented at a later time would be the use of in memory per switch debounce counter thresholds.
This means that instead of having a global state of all switches are debounced in at count value 8'bxxxxxxxx. The user could tune each switch
to the lowest possible latency before bouncing occours. This would work extremely well for designs that have multiple switch types.

## STM32 USB HID Interface
