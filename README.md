# Nyan Keys - An FPGA Powered Keyboard

An FPGA based mechanical keybaord controller design based around the Lattice ice40hx series of FPGA chips.

## Why?

The biggest question to be asked is why? The answer is simple. A quest to create the most performant keyboard
on planet earth. The additional performance is extracted through four means.

 - Per key programmable debounce counters (8 bit)
 - Per key parallel input _All keys are parallel without a scanning matrix_
 - Ultra fast SPI based serialization (12.25Mhz Tested)
 - nKRO - Though standard now it's nice to have becuase of the parallel interface

This design is targeted toward few primary groups.

 - __Gamers__ For the lowest possible latency.
 - __Power Users__ For the programability.
 - __Hobbyists__ For the hacks.
 - __Non standard layouts__ For users that need to be able to create a custom layout

## FPGA IP

FPGA IP is designed to be build using [Yosys](https://github.com/YosysHQ/yosys) and [Nextpnr](https://github.com/YosysHQ/nextpnr). This parallel keys interface has been validated on the Lattice ICE40HX1K and ICE40HX4K 144TQFP FPGAs.
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

In it's simplest form this design outputs a one hot vector that represents the states of each key as 0 or 1 (_high_ or _low_) and send that over a SPI slave interface to the masteter
as often as it can be requested. Switches are considered active low and this design leverages the interal pull resistors that are available on the 
outputs of the Lattice Ice40hx series ICs.

 - __Key state__ - Represents the physical key. [Pressed/Released]
 - __Logic Level__ - The logic level of net to the key itself.
 - __Direction State__ - Internal debounced logic level of the one hot key state register.

| Key State | Logic Level | Direction State |
| --------- | ----------- | --------------- |
| Depressed | Low         | Low             |
| Released  | High        | High            |


Certainly! Here's the corrected text for your GitHub readme.md:

The actual mechanism for debouncing is incredibly simple. It involves an up counter that locks out the state change of a key until it has reached a threshold value. Compared to the original Nyan Keys FPGA design, which had an up and down counter, using an up-only counter allows for the design to have a smaller footprint. It also enables instant response to switch state changes as long as the debounce period has elapsed.

After configuration, the FPGA resets all 8-bit counters (Ice40HX4K) to 0xff. When the counter is at ```0xff```, the state may be changed because that signals the debounce timer has completed. Once any key is pressed, the FPGA immediately changes that key's bit in the bit vector to represent the new state. Then, the counter is reset to ```0x00``` and will begin to increment with each clock cycle to the key's module. While the counter is not equal to ```0xff```, the state won't change, so any bouncing of the switch is ignored. After the timer reaches 0xff again, the state of the key can be changed instantly.

The bit vector size is dependent on the number of keys on a keyboard; in the case of a 61-key, 60% board, the total number of bits needed is 61. However, since the SPI slave only reads out bytes, we have to use 8 bytes (64 bits). This bit vector is continuously written to block RAM, which is then addressed and read out directly by the SPI slave.

### FPGA Limits

| FPGA           | Debounce Counter |
| -------------- | ---------------- |
| Ice40HX1k      | 3 bit            |
| Ice40HX4k      | 8 bit            |

### Future

One of the major features that could be implemented at a later time would be the use of in memory per switch debounce counter thresholds.
This means that instead of having a global state of all switches are debounced in at count value 8'bxxxxxxxx. The user could tune each switch
to the lowest possible latency before bouncing occours. This would work extremely well for designs that have multiple switch types.
