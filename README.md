TPU-inspired AI Hardware Accelerator (SystemVerilog)
•	Designed and verified a weight-stationary 4×4 systolic array (parameterized to arbitrary N, INT8 in / 32-bit accumulate) inspired by Google's first TPU paper by Jouppi et al., achieving 1.84 GMAC/s (3.68 GOP/s) at a synthesized 115 MHz clock
•	Implemented double-buffered weight banks in each PE to hide weight-tile loading behind ongoing compute to improve efficiency, coordinated via a streaming FIFO weight loader with a hardware handshake protocol
•	Built a skew and deskew network to align the array's input and output timings while route partial sums into banked accumulators supporting read-modify-write accumulation across tiles
•	Synthesized on a Xilinx Artix-7 (XC7A200T), using under 2% of device LUTs and under 3.4% of slices, leaving substantial headroom to scale N or replicate the array
Jouppi, N. P., et al. "In-Datacenter Performance Analysis of a Tensor Processing Unit." Proceedings of the 44th Annual International Symposium on Computer Architecture (ISCA), 2017, pp. 1–12.
