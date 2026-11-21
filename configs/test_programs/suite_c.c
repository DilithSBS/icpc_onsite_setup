#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
    int n;
    if (scanf("%d", &n) != 1 || n <= 0) {
        return 1;
    }

    long long sum = 0;
    long long min_val = 0, max_val = 0;
    int evens = 0, odds = 0;

    for (int i = 0; i < n; i++) {
        long long val;
        if (scanf("%lld", &val) != 1) return 1;
        sum += val;
        if (i == 0) {
            min_val = max_val = val;
        } else {
            if (val < min_val) min_val = val;
            if (val > max_val) max_val = val;
        }
        if (llabs(val) % 2 == 0) {
            evens++;
        } else {
            odds++;
        }
    }

    char s[2048];
    if (scanf("%s", s) != 1) {
        s[0] = '\0';
    }

    int len = (int)strlen(s);
    for (int i = 0; i < len / 2; i++) {
        char temp = s[i];
        s[i] = s[len - 1 - i];
        s[len - 1 - i] = temp;
    }

    printf("Sum: %lld\n", sum);
    printf("Min: %lld Max: %lld\n", min_val, max_val);
    printf("Evens: %d Odds: %d\n", evens, odds);
    printf("Reversed: %s\n", s);

    return 0;
}
