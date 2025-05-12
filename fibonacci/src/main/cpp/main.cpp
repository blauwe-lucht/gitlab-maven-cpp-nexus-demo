#include <iostream>
#include <cstdlib>
#include "Fibonacci.h"
#include "version.h"

static void usage(const char* progName) {
    std::cerr << "Usage:\n"
              << "  " << progName << " --version       Show version\n"
              << "  " << progName << " <n>             Compute the nth Fibonacci number\n";
    std::exit(1);
}

int main(int argc, char* argv[]) {
    if (argc != 2) {
        usage(argv[0]);
    }

    std::string arg = argv[1];
    if (arg == "--version") {
        std::cout << "fibonacci version " << APP_VERSION << "\n";
        return 0;
    }

    int n = std::atoi(arg.c_str());
    if (n < 0) {
        std::cerr << "Please enter a non-negative integer." << std::endl;
        return 1;
    }

    Fibonacci fib;
    std::cout << "Fibonacci(" << n << ") = " << fib.compute(n) << std::endl;
    return 0;
}
