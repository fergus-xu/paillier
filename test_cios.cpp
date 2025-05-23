#include "Vmontgomery_cios.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <gmpxx.h>
#include <iostream>
#include <cassert>

#define W 8
#define S 2

void mpz_to_words(const mpz_class& val, vluint64_t out[S]) {
    for (int i = 0; i < S; ++i) out[i] = 0;
    mpz_export(out, nullptr, -1, sizeof(vluint64_t), 0, 0, val.get_mpz_t());
}

mpz_class words_to_mpz(const vluint64_t in[S]) {
    mpz_class result;
    mpz_import(result.get_mpz_t(), S, -1, sizeof(vluint64_t), 0, 0, in);
    return result;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    Vmontgomery_cios* top = new Vmontgomery_cios;
    VerilatedVcdC* tfp = new VerilatedVcdC;
    top->trace(tfp, 99);
    tfp->open("montgomery_cios.vcd");

    // ==== Tiny test values ====
    mpz_class a = 9;
    mpz_class b = 3;
    mpz_class m = 13;
    mpz_class R = mpz_class(1) << (W * S);  // R = 2^(W*S) = 2^16 = 65536

    mpz_class m_inv;
    if (mpz_invert(m_inv.get_mpz_t(), m.get_mpz_t(), R.get_mpz_t()) == 0) {
        std::cerr << "Modular inverse does not exist\n";
        return 1;
    }

    mpz_class m_prime = R - m_inv;
    mpz_class aR = (a * R) % m;
    mpz_class bR = (b * R) % m;
    mpz_class expected = ((a * b) % m * R) % m;

    vluint64_t a_words[S], b_words[S], m_words[S];
    mpz_to_words(aR, a_words);
    mpz_to_words(bR, b_words);
    mpz_to_words(m, m_words);

    mpz_class mask = (mpz_class(1) << W) - 1;
    mpz_class m_prime_low = m_prime & mask;
    vluint64_t m_prime_word = m_prime_low.get_ui();

    // === Reset ===
    top->clk = 0;
    top->rst_n = 0;
    top->eval(); tfp->dump(0);
    for (int i = 1; i <= 4; ++i) {
        top->clk ^= 1;
        top->eval();
        tfp->dump(i * 10);
    }
    top->rst_n = 1;

    // === Apply inputs ===
    top->a_0 = a_words[0]; top->a_1 = a_words[1];
    top->b_0 = b_words[0]; top->b_1 = b_words[1];
    top->m_0 = m_words[0]; top->m_1 = m_words[1];
    top->m_prime = m_prime_word;
    top->start = 1;

    // === Run until done ===
    int cycle = 0;
    while (!top->done && cycle < 500) {
        top->clk ^= 1;
        top->eval();
        tfp->dump(10 * cycle + 5);
        if (top->clk == 1) top->start = 0;
        cycle++;
    }

    // === Read result ===
    vluint64_t result_words[S] = {
        top->result_0,
        top->result_1
    };

    mpz_class hw_result = words_to_mpz(result_words);

    std::cout << "a        = " << a.get_str() << "\n";
    std::cout << "b        = " << b.get_str() << "\n";
    std::cout << "modulus  = " << m.get_str() << "\n";
    std::cout << "expected = " << expected.get_str() << "\n";
    std::cout << "hardware = " << hw_result.get_str() << "\n";

    if (hw_result == expected)
        std::cout << "✅ PASS\n";
    else
        std::cout << "❌ FAIL\n";

    tfp->close();
    delete tfp;
    delete top;
    return 0;
}
