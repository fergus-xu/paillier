from typing import List

"""
This file provides reference implementations of montgomery multiplication and encryption and decryption
in the paillier cryptosystem.
"""

def lcm(a, b):
    return abs(a * b) // gcd(a, b)

def modinv(a, m):
    g, x, y = extended_gcd(a, m)
    if g != 1:
        raise Exception("Modular inverse does not exist")
    return x % m

def extended_gcd(a, b):
    if a == 0:
        return b, 0, 1
    else:
        g, y, x = extended_gcd(b % a, a)
        return g, x - (b // a) * y, y

def generate_keypair(bits=512):
    while True:
        p = random.getrandbits(bits // 2)
        q = random.getrandbits(bits // 2)
        if gcd(p * q, (p - 1) * (q - 1)) == 1 and p != q:
            break
    n = p * q
    n_sq = n * n
    lam = lcm(p - 1, q - 1)
    g = n + 1  # safe default
    mu = modinv((pow(g, lam, n_sq) - 1) // n, n)
    return (n, g), (lam, mu)

def encrypt(m, pubkey):
    n, g = pubkey
    n_sq = n * n
    while True:
        r = random.randint(1, n - 1)
        if gcd(r, n) == 1:
            break
    c = (pow(g, m, n_sq) * pow(r, n, n_sq)) % n_sq
    return c

def decrypt(c, privkey, pubkey):
    lam, mu = privkey
    n, _ = pubkey
    n_sq = n * n
    u = pow(c, lam, n_sq)
    L = (u - 1) // n
    return (L * mu) % n

def montgomery_reduce(T, n, n_prime, R):
    m = ((T % R) * n_prime) % R
    t = (T + m * n) // R
    if t >= n:
        t -= n
    return t

def montgomery_multiply(a, b, n, n_prime, R):
    return montgomery_reduce(a * b, n, n_prime, R)

def cios(a: List[int], b: List[int], p: List[int], pinv: int, w=32, s=8) -> List[int]:
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
        T[s] = (T[s+1] + (u >> w)) & (BASE - 1)

    return T[:s]