import cocotb
import os
import random
import sys
import math
import logging
import matplotlib.pyplot as plt
from pathlib import Path
from cocotb.triggers import Timer
from cocotb.utils import get_sim_time
from cocotb.runner import get_runner

test_file = os.path.basename(__file__).replace(".py","")

CLK_FREQ_HZ = 100_000_000
CLK_PERIOD_NS = 1/CLK_FREQ_HZ * 1e9
BAUD_RATE = 115200
BAUD_PERIOD_NS = math.floor(CLK_FREQ_HZ/BAUD_RATE) * CLK_PERIOD_NS

# 100 MHz

def eval_freq_sum(series, angle):
    return sum([
        cos_amplitude * math.cos(freq * angle)
        + sin_amplitude * math.sin(freq * angle)
        for cos_amplitude, sin_amplitude, freq in series
    ])


class SimMotor():

    def __init__(self, kv, ka, disturbance_frequencies):
        self.KV = kv # analogous to back EMF
        self.KA = ka # analogous to mass
        self.DISTURBANCE_FREQUENCIES = disturbance_frequencies

        self.angle_rad = 0.0
        self.velocity_rad_s = 0.0 # 
        self.sim_time = 0.0

    def update(self, voltage, timestep):
        # old formula for a very simplistic motor model
        # stolen from an old robotics lecture i made
        accel = 1/self.KA * (voltage - self.KV * self.velocity_rad_s) \
            + eval_freq_sum(self.DISTURBANCE_FREQUENCIES, self.angle_rad)
        self.velocity_rad_s += accel * timestep
        self.angle_rad += self.velocity_rad_s * timestep

        self.sim_time += timestep


"""@cocotb.test()
async def test_always_transmit(dut):
    await cocotb.start( generate_clock( dut.clk ) )
    
    assert dut.dout.value == 1, "not high when not transmitting"

    bytes_to_try = [
        random.randint(0, 255)
        for _ in range(10)
    ]

    dut.trigger.value = 1
    dut.din.value = bytes_to_try[0]
    await Timer(CLK_PERIOD_NS, "ns")

    for i, byte in enumerate(bytes_to_try[0:-1]):
        print(f"iteration {i}")
        print(f"{dut.data_buf.value = }, {bin(byte) = }")

        dut.din.value = bytes_to_try[i + 1]

        out_byte = await uart_byte_interpret(dut)
        assert out_byte == byte, "wrong byte was transmitted"

def counter_runner():
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    hdl = proj_path / "hdl"
    sys.path.append(str(proj_path / "sim" / "model"))
    
    sources = [hdl / "uart_transmit.sv"] #grow/modify this as needed.

    hdl_toplevel = "uart_transmit"
    build_test_args = ["-Wall"]#,"COCOTB_RESOLVE_X=ZEROS"]
    parameters = {
        "INPUT_CLOCK_FREQ": CLK_FREQ_HZ,
        "BAUD_RATE": BAUD_RATE,
        "DATA_BITS": 8
    }
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        test_args=run_test_args,
        waves=True
    )"""
 
if __name__ == "__main__":

    target_vel_rpm = 60.0
    target_vel_rad_s = target_vel_rpm * 2.0 * math.pi / 60.0 
    target_voltage = 12.0
    target_time_const = 0.001

    kv = target_voltage/target_vel_rad_s
    ka = kv * target_time_const

    print(ka)

    DISTURBANCE_FREQUENCIES = []
    NUM_POLE_PAIRS = 24
    for harmonic in range(1, 4 + 1):
        unit = 1.0/ka
        DISTURBANCE_FREQUENCIES.append(
            (
                unit * random.uniform(-1.0, 1.0),
                unit * random.uniform(-1.0, 1.0),
                harmonic * NUM_POLE_PAIRS
            )
        )

    my_motor = SimMotor(kv, ka, DISTURBANCE_FREQUENCIES)
    x_series = []
    motor_velocity_series = []
    target_velocity_series = []

    # run the motor for some amount of time
    TIMESTEP = 0.00004
    DURATION = 0.5

    VELOCITY_FREQUENCIES = []
    for harmonic in range(1, 4 + 1):
        unit = 10.0/harmonic
        VELOCITY_FREQUENCIES.append(
            (
                unit * random.uniform(-1.0, 1.0),
                unit * random.uniform(-1.0, 1.0),
                harmonic/DURATION
            )
        )

    for i in range(math.ceil(DURATION/TIMESTEP)):
        velocity_command = eval_freq_sum(VELOCITY_FREQUENCIES, my_motor.sim_time)
        voltage_command = velocity_command * kv
        x_series.append(my_motor.sim_time)
        motor_velocity_series.append(my_motor.velocity_rad_s/(2 * math.pi) * 60.0) # convert to rpm
        target_velocity_series.append(velocity_command/(2 * math.pi) * 60.0)
        my_motor.update(voltage_command, TIMESTEP)
    
    plt.plot(x_series, motor_velocity_series)
    plt.plot(x_series, target_velocity_series)
    plt.show()

    #counter_runner()