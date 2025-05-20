#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vmontmult.h"
#include <iostream>
#include <tuple>
#include <vector>
#include <stdexcept>

vluint64_t main_time = 0;
double sc_time_stamp() { return main_time; }

uint64_t compute_n_prime(uint64_t n, uint64_t R) {
    if ((n & 1) == 0) throw std::invalid_argument("Modulus n must be odd");
    for (uint64_t x = 1; x < R; ++x) {
        if ((n * x) % R == 1)
            return R - x;
    }
    throw std::runtime_error("No inverse found");
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmontmult* top = new Vmontmult;

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Verilated::traceEverOn(true);
    top->trace(tfp, 99);
    tfp->open("wave.vcd");

    const uint64_t R = 256;
    std::vector<std::tuple<uint64_t, uint64_t, uint64_t>> tests = {
        {28, 18, 47}
    };

    for (size_t i = 0; i < tests.size(); ++i) {
        uint64_t a = std::get<0>(tests[i]);
        uint64_t b = std::get<1>(tests[i]);
        uint64_t n = std::get<2>(tests[i]);

        uint64_t n_prime = compute_n_prime(n, R);
        uint64_t a_bar = (a * R) % n;
        uint64_t b_bar = (b * R) % n;
        uint64_t expected = (((a * b) % n) * R) % n;
        top->a = a_bar;
        top->b = b_bar;
        top->n = n;
        top->n_prime = n_prime;

        // Apply start pulse
        top->clk = 0;
        top->rst = 0;
        top->start = 1;
        top->eval();
        tfp->dump(main_time++);
        top->clk = 1;
        top->eval();
        tfp->dump(main_time++);
        top->start = 0;

        // Wait for computation to complete
        int max_cycles = 200;
        int cycle = 0;
        while (!top->done && cycle++ < max_cycles) {
            top->clk = 0;
            top->eval();
            tfp->dump(main_time++);
            top->clk = 1;
            top->eval();
            tfp->dump(main_time++);
        }

        if (!top->done) {
            std::cerr << " ERROR: computation did not complete in time\n";
            return 1;
        }

        uint64_t result = top->result;
        if (result != expected) {
            std::cerr << "Test " << i << " failed! Expected " << expected << ", got " << result << "\n";
        } else {
            std::cout << "Test " << i << " passed: result = " << result << std::endl;
            std::cout << "Finished in " << cycle << " cycles" << std::endl;
        }
    }

    tfp->close();
    delete tfp;
    delete top;
    std::cout << "All tests passed.\n";
    return 0;
}