#include "Vmontmult.h"
#include "verilated.h"

int main(int argc, char** argv){
    VerilatedContext* contextp = new VerilatedContext;
    contextp->commandArgs(argc, argv);
    // Example 128-bit test values (can be expanded to 1024-bit values)
    uint64_t A_lo = 0x12345678;
    uint64_t B_lo = 0x87654321;
    uint64_t M_lo = 0xFFFFFFFF;
    uint64_t MP_lo = 0x00000001;  // placeholder for -M⁻¹ mod R

    top->clk = 0;
    top->rst = 1;
    top->eval();

    top->rst = 0;
    top->a = A_lo;
    top->b = B_lo;
    top->modulus = M_lo;
    top->m_prime = MP_lo;
    top->start = 1;

    for (int i = 0; i < 100; i++) {
        top->clk = !top->clk;
        top->eval();

        if (top->done) {
            std::cout << "Montgomery Product = 0x" << std::hex << top->result << std::endl;
            break;
        }
    }

    delete top;
    return 0;
}