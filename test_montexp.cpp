#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vmontexp.h"
#include <iostream>
#include <cassert>
#include <vector>
#include <tuple>

const uint32_t WIDTH = 8;
const uint64_t R = 1ULL << WIDTH;
const int MAX_CYCLES = 1000;

uint32_t mont_encode(uint32_t x, uint32_t mod) {
    return ((uint64_t)x * R) % mod;
}

uint32_t mont_pow(uint32_t base, uint32_t exp, uint32_t mod) {
    uint32_t result = 1;
    for (int i = 0; i < exp; i++){
        result *= base;
    }
    return (result * R) % mod;
}

uint64_t compute_n_prime(uint64_t A, uint64_t M) {
    int m0 = M;
    int y = 0, x = 1;

    if (M == 1)
        return 0;

    while (A > 1) {
        // q is quotient
        int q = A / M;
        int t = M;

        // m is remainder now, process same as
        // Euclid's algo
        M = A % M, A = t;
        t = y;

        // Update y and x
        y = x - q * y;
        x = t;
    }

    // Make x positive
    if (x < 0)
        x += m0;

    return M - x;
}

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    auto* top = new Vmontexp;

    Verilated::traceEverOn(true);
    auto* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("mont_exp.vcd");

    vluint64_t timestamp = 0;

    auto tick = [&]() {
        top->clk = 0;
        top->eval();
        tfp->dump(timestamp++);
        top->clk = 1;
        top->eval();
        tfp->dump(timestamp++);
    };

    std::vector<std::tuple<uint32_t, uint32_t, uint32_t>> tests = {
        {7, 3, 13},
        {4, 7, 47},
        {2, 5, 17}
    };

    for (size_t i = 0; i < tests.size(); ++i) {
        uint32_t a = std::get<0>(tests[i]);
        uint32_t e = std::get<1>(tests[i]);
        uint32_t n = std::get<2>(tests[i]);

        uint32_t a_bar = mont_encode(a, n);
        uint32_t expected_bar = mont_pow(a, e, n);
        uint64_t n_prime = compute_n_prime(n, R);
        uint32_t mont_one = R % n;

        // Reset
        top->rst = 1;
        tick();
        top->rst = 0;

        // Set inputs
        top->start = 1;
        top->base = a_bar;
        top->exponent = e;
        top->n = n;
        top -> n_prime = n_prime;
        top->mont_one = mont_one;
        tick();
        top->start = 0;
        

        int cycle = 0;
        while (!top->done && cycle++ < MAX_CYCLES) {
            tick();
        }

        if (!top->done) {
            std::cerr << "Test " << i << " timed out!\n";
        } else if (top->result != expected_bar) {
            std::cerr << "Test " << i << " failed!\n";
            std::cerr << "Expected: " << expected_bar << ", Got: " << top->result << std::endl;
        } else {
            std::cout << "Test " << i << " passed: " << top->result << std::endl;
        }
    }

    tfp->close();
    delete tfp;
    delete top;
    std::cout << "All Montgomery-form tests completed." << std::endl;
    return 0;
}
