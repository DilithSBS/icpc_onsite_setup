import sys

def main():
    data = sys.stdin.read().split()
    if not data:
        return
    
    n = int(data[0])
    nums = [int(x) for x in data[1:1+n]]
    s = data[1+n] if len(data) > 1+n else ""

    sum_val = sum(nums)
    min_val = min(nums)
    max_val = max(nums)
    evens = sum(1 for x in nums if abs(x) % 2 == 0)
    odds = len(nums) - evens
    reversed_str = s[::-1]

    print(f"Sum: {sum_val}")
    print(f"Min: {min_val} Max: {max_val}")
    print(f"Evens: {evens} Odds: {odds}")
    print(f"Reversed: {reversed_str}")

if __name__ == "__main__":
    main()

