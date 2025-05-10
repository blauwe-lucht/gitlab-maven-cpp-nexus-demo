#include <iostream>
#include <cstdlib>
#include "Fibonacci.h"

int main(int argc, char* argv[]) {
    if (argc != 2) {
        std::cerr << "Usage: fibonacci <n>" << std::endl;
        return 1;
    }

    int n = std::atoi(argv[1]);
    if (n < 0) {
        std::cerr << "Please enter a non-negative integer." << std::endl;
        return 1;
    }

    Fibonacci fib;
    std::cout << "Fibonacci(" << n << ") = " << fib.compute(n) << std::endl;
    return 0;
}
