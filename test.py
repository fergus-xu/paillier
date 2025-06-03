from typing import List

def montgomery_cios_mul(a: List[int], b: List[int], p: List[int], pinv: int, w=32, s=8) -> List[int]:
    BASE = 1 << w
    T = [0] * (s + 2)

    for i in range(s):
        C = 0
        for j in range(s):
            u = a[i] * b[j] + T[j] + C
            T[j] = u & (BASE - 1)
            C = u >> w

        u = T[s] + C
        T[s] = u & (BASE - 1)
        T[s+1] = u >> w
        m = (T[0] * pinv) & (BASE - 1)
        u = T[0] + m * p[0]
        T[0] = u & (BASE - 1)
        C = u >> w
        for j in range(1, s):
            u = T[j] + m * p[j] + C
            T[j-1] = u & (BASE - 1)
            C = u >> w
        u = T[s] + C
        T[s-1] = u & (BASE - 1)
        T[s] = (T[s+1] + (u >> w)) & (BASE - 1)  # final carry

    return T[:s]

# === Test ===
w = 32
s = 8
BASE = 1 << w

# Example inputs
a = [4, 4, 4, 4, 4, 4, 4, 0]
b = [7, 7, 7, 7, 7, 7, 7, 0]
p = [65793, 1, 1, 1, 1, 1, 1, 1]
def compute_p_prime(p, w):
    modulus = 2**w
    p_inv = pow(p[0], -1, modulus)        # p⁻¹ mod 2^w
    p_prime = (-p_inv) % modulus       # -p⁻¹ mod 2^w
    return p_prime
pinv = compute_p_prime(p, 32)
print("p′ =", pinv)

result = montgomery_cios_mul(a, b, p, pinv, w=w, s=s)
print("Montgomery result:", result)
