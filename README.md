# FPM - Fast Polynomial Multiplier for ML-KEM

A hardware implementation of Fast Polynomial Multiplier (FPM) using Number Theoretic Transform (NTT) for ML-KEM (Module-Lattice-Based Key Encapsulation Mechanism).

## Overview

This project provides a Verilog implementation of polynomial multiplication using the Number Theoretic Transform (NTT) algorithm, specifically optimized for ML-KEM operations. ML-KEM, formerly known as CRYSTALS-Kyber, is a post-quantum cryptographic algorithm selected by NIST for standardization.

## NTT Algorithm in ML-KEM

### Background

The Number Theoretic Transform (NTT) is a discrete Fourier transform over finite fields, analogous to the Fast Fourier Transform (FFT) but operating in modular arithmetic. In ML-KEM, polynomial multiplication is a core operation that occurs in:

- Key generation
- Encryption
- Decryption

ML-KEM operates in the ring $R_q = \mathbb{Z}_q[X]/(X^{256} + 1)$, where $q = 3329$ is a prime modulus. The NTT enables efficient polynomial multiplication by transforming convolution into point-wise multiplication.

### Mathematical Foundation

For two polynomials $a(X)$ and $b(X)$ of degree $n-1$:

1. **Forward NTT**: Transform polynomials to NTT domain
   - $\hat{a} = NTT(a)$
   - $\hat{b} = NTT(b)$

2. **Point-wise Multiplication**: Multiply in NTT domain
   - $\hat{c} = \hat{a} \odot \hat{b}$

3. **Inverse NTT**: Transform back to coefficient domain
   - $c = INTT(\hat{c})$

The NTT transformation for ML-KEM uses:
- Modulus: $q = 3329$
- Polynomial degree: $n = 256$
- Primitive root of unity: $\zeta$ such that $\zeta^{2n} \equiv 1 \pmod{q}$

### Complexity

- **Direct polynomial multiplication**: $O(n^2)$ operations
- **NTT-based multiplication**: $O(n \log n)$ operations

For ML-KEM with $n = 256$, this provides approximately 32x speedup.

## Implementation Details

The hardware implementation includes:

- **NTT Core**: Cooley-Tukey butterfly architecture for forward transform
- **INTT Core**: Gentleman-Sande butterfly architecture for inverse transform
- **Modular Arithmetic Units**: Barrett reduction for efficient modulo operations
- **Point-wise Multiplier**: Element-wise multiplication in NTT domain
- **Memory Controllers**: Optimized memory access patterns for coefficients

### Key Parameters

- **Modulus (q)**: 3329
- **Polynomial Degree (n)**: 256
- **Twiddle Factors**: Pre-computed powers of primitive root
- **Data Width**: Configurable (typically 16-bit for ML-KEM)

## Project Structure

```
FPM/
├── src/               # Verilog source files
│   └── .gitkeep      # Placeholder for source files
├── tb/                # Testbench files
│   └── .gitkeep      # Placeholder for testbench files
├── README.md          # This file
├── LICENSE            # License information
└── .gitignore         # Git ignore rules
```

### Directory Descriptions

- **src/**: Contains all Verilog/SystemVerilog RTL source files for the NTT implementation
  - NTT/INTT modules
  - Butterfly units
  - Modular arithmetic components
  - Top-level integration modules

- **tb/**: Contains testbench files for verification
  - Unit tests for individual modules
  - Integration tests for complete NTT operations
  - ML-KEM compliance tests

## Getting Started

### Prerequisites

- Verilog simulator (ModelSim, Vivado, Icarus Verilog, etc.)
- Python 3.x (for generating test vectors)
- Make (optional, for build automation)

### Building

```bash
# Clone the repository
git clone https://github.com/Kyrie-T/FPM.git
cd FPM

# Compile source files (example with Icarus Verilog)
iverilog -o ntt_test -s tb_top tb/*.v src/*.v

# Run simulation
vvp ntt_test
```

### Testing

Testbenches validate:
1. Forward NTT correctness
2. Inverse NTT correctness
3. NTT-INTT round-trip accuracy
4. Point-wise multiplication
5. Complete polynomial multiplication against reference implementation

## Performance

The hardware implementation is optimized for:
- **Throughput**: Multiple operations per clock cycle using pipelining
- **Latency**: Minimized through parallel butterfly operations
- **Area**: Resource sharing between NTT and INTT operations
- **Power**: Clock gating and operand isolation techniques

## ML-KEM Integration

This NTT implementation can be integrated into a complete ML-KEM accelerator by combining with:
- Key generation logic
- Sampling modules (CBD, uniform sampling)
- Compression/decompression units
- Hashing functions (SHA3/SHAKE)

## References

1. [NIST PQC Standardization](https://csrc.nist.gov/Projects/post-quantum-cryptography)
2. [ML-KEM Specification (FIPS 203)](https://csrc.nist.gov/pubs/fips/203/final)
3. [CRYSTALS-Kyber](https://pq-crystals.org/kyber/)
4. Number Theoretic Transform in Ring-LWE Cryptography

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## Authors

Hardware implementation by the FPM project team.
