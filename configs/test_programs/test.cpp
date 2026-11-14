#include <iostream>
#include <vector>
#include <numeric>

int main() {
    std::vector<int> nums = {10, 20, 30, 40};
    int sum = std::accumulate(nums.begin(), nums.end(), 0);
    std::cout << "C++ Compiler OK (STL Working): Sum = " << sum << std::endl;
    return 0;
}

