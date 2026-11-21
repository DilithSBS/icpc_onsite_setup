#include <iostream>
#include <vector>
#include <string>
#include <algorithm>

using namespace std;

int main() {
    ios_base::sync_with_stdio(false);
    cin.tie(NULL);

    int n;
    if (!(cin >> n) || n <= 0) return 1;

    long long sum = 0;
    long long min_val = 0, max_val = 0;
    int evens = 0, odds = 0;

    for (int i = 0; i < n; i++) {
        long long val;
        cin >> val;
        sum += val;
        if (i == 0) {
            min_val = max_val = val;
        } else {
            min_val = min(min_val, val);
            max_val = max(max_val, val);
        }
        if (abs(val) % 2 == 0) {
            evens++;
        } else {
            odds++;
        }
    }

    string s;
    if (cin >> s) {
        reverse(s.begin(), s.end());
    }

    cout << "Sum: " << sum << "\n";
    cout << "Min: " << min_val << " Max: " << max_val << "\n";
    cout << "Evens: " << evens << " Odds: " << odds << "\n";
    cout << "Reversed: " << s << "\n";

    return 0;
}

