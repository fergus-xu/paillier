
#include "Vmontgomery_cios.h"
#include "verilated.h"
#include <gmpxx.h>
#include <iostream>
#include <random>
#include <cassert>

#define W 32
#define S 8
#define WORDS S

void mpz_to_words(mpz_class val, vluint64_t out[WORDS]) {
    for (int i = 0; i < WORDS; ++i) out[i] = 0;
    mpz_export(out, nullptr, -1, sizeof(vluint64_t), 0, 0, val.get_mpz_t());
}

mpz_class words_to_mpz(const vluint64_t in[WORDS]) {
    mpz_class result;
    mpz_import(result.get_mpz_t(), WORDS, -1, sizeof(vluint64_t), 0, 0, in);
    return result;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vmontgomery_cios* top = new Vmontgomery_cios;

    gmp_randclass rng(gmp_randinit_default);
    rng.seed(time(NULL));

    mpz_class R = mpz_class(1) << (W * S);

    mpz_class a = rng.get_z_bits(W * S);
    mpz_class b = rng.get_z_bits(W * S);
    mpz_class m;
    do {
        m = rng.get_z_bits(W * S - 1) | 1;
    } while (m >= R);

    mpz_class m_inv;
    if (mpz_invert(m_inv.get_mpz_t(), m.get_mpz_t(), R.get_mpz_t()) == 0) {
        std::cerr << "Failed to compute m^{-1} mod R\n";
        return 1;
    }

    mpz_class m_prime = R - m_inv;
    mpz_class aR = (a * R) % m;
    mpz_class bR = (b * R) % m;

    mpz_class expected = (((a * b) % m) * R) % m;

    vluint64_t a_words[WORDS], b_words[WORDS], m_words[WORDS], mprime_word;
    mpz_to_words(aR, a_words);
    mpz_to_words(bR, b_words);
    mpz_to_words(m, m_words);
    mpz_class mask;
    mpz_ui_pow_ui(mask.get_mpz_t(), 2, W);
    mask -= 1;

    mpz_class m_prime_low;
    mpz_and(m_prime_low.get_mpz_t(), m_prime.get_mpz_t(), mask.get_mpz_t());
    mprime_word = m_prime_low.get_ui();

    // Reset
    top->clk = 0;
    top->rst_n = 0;
    for (int i = 0; i < 4; ++i) {
        top->clk ^= 1;
        top->eval();
    }
    top->rst_n = 1;

    for (int i = 0; i < S; ++i) {
        top->a[i] = a_words[i];
        top->b[i] = b_words[i];
        top->m[i] = m_words[i];
    }
    top->m_prime = mprime_word;
    top->start = 1;

    // Clock until done
    while (!top->done) {
        top->clk ^= 1;
        top->eval();
        if (top->clk == 1) top->start = 0;
    }

    vluint64_t result_words[WORDS];
    for (int i = 0; i < S; ++i) {
        result_words[i] = top->result[i];
    }

    mpz_class hw_result = words_to_mpz(result_words);

    std::cout << "a        = " << a.get_str(16) << "\n";
    std::cout << "b        = " << b.get_str(16) << "\n";
    std::cout << "modulus  = " << m.get_str(16) << "\n";
    std::cout << "expected = " << expected.get_str(16) << "\n";
    std::cout << "hardware = " << hw_result.get_str(16) << "\n";

    if (hw_result == expected) {
        std::cout << "✅ PASS: Output matches expected\n";
    } else {
        std::cout << "❌ FAIL: Mismatch\n";
    }

    delete top;
    return 0;
}
