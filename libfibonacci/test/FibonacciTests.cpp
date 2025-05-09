#include "Fibonacci.h"
#include <gtest/gtest.h>
#include <stdexcept>

class FibonacciTest : public ::testing::Test {
protected:
    Fibonacci fib;
};

TEST_F(FibonacciTest, ThrowsOnNegativeInput) {
    EXPECT_THROW(fib.compute(-1), std::invalid_argument);
    EXPECT_THROW(fib.compute(-10), std::invalid_argument);
}

struct FibParam {
    int input;
    int expected;
};

class FibonacciParamTest : public ::testing::TestWithParam<FibParam> {
protected:
    Fibonacci fib;
};

TEST_P(FibonacciParamTest, ComputesCorrectFibonacci) {
    auto [input, expected] = GetParam();
    EXPECT_EQ(fib.compute(input), expected);
}

INSTANTIATE_TEST_SUITE_P(
    FibonacciValues,
    FibonacciParamTest,
    ::testing::Values(
        FibParam{0, 0},
        FibParam{1, 1},
        FibParam{6, 8},
        FibParam{7, 13},
        FibParam{8, 21},
        FibParam{9, 34},
        FibParam{11, 89}
    )
);
