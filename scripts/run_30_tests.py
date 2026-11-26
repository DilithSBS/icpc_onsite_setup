import os
import sys
import subprocess
import tempfile
import random

def generate_30_test_cases():
    cases = []
    # 1-5: Basic small tests
    cases.append((3, [1, 2, 3], "icpc"))
    cases.append((5, [10, -5, 20, -15, 0], "contest"))
    cases.append((1, [42], "a"))
    cases.append((4, [2, 4, 6, 8], "evennumbers"))
    cases.append((4, [1, 3, 5, 7], "oddnumbers"))

    # 6-10: Negative numbers & zeroes
    cases.append((6, [-10, -20, -30, -40, -50, -60], "allnegative"))
    cases.append((8, [0, 0, 0, 0, 0, 0, 0, 0], "allzeroes"))
    cases.append((6, [-5, 5, -10, 10, -15, 15], "balancedzero"))
    cases.append((7, [-100, 50, 0, -25, 25, -50, 100], "mixednumbers"))
    cases.append((2, [-999999, 999999], "symmetry"))

    # 11-15: 64-bit Large integers (overflow test)
    cases.append((4, [3000000000, 4000000000, 5000000000, 6000000000], "int64overflow"))
    cases.append((3, [-5000000000, 10000000000, -2000000000], "int64mixed"))
    cases.append((2, [2147483647, 2147483647], "int32max"))
    cases.append((2, [-2147483648, -2147483648], "int32min"))
    cases.append((5, [100000000000, 200000000000, 300000000000, -500000000000, 0], "hundredbillion"))

    # 16-20: Varying lengths & arrays
    cases.append((15, list(range(1, 16)), "ascending15"))
    cases.append((15, list(range(15, 0, -1)), "descending15"))
    cases.append((20, [i * (-1 if i % 2 == 0 else 1) for i in range(1, 21)], "alternating20"))
    cases.append((30, [7] * 30, "identical30"))
    cases.append((50, [i * i for i in range(1, 51)], "squares50"))

    # 21-25: Strings & Palindromes
    cases.append((5, [1, 2, 3, 4, 5], "racecar"))
    cases.append((3, [10, 20, 30], "abcdefghijklmnopqrstuvwxyz"))
    cases.append((4, [100, 200, 300, 400], "UPPERANDlowerCASE"))
    cases.append((1, [0], "SingleCharX"))
    cases.append((6, [2, 3, 5, 7, 11, 13], "madamimadam"))

    # 26-30: Edge cases & Stress
    cases.append((1, [-9223372036854775807 // 2], "minedge"))
    cases.append((2, [9223372036854775807 // 4, 9223372036854775807 // 4], "maxedge"))
    cases.append((100, [random.Random(42).randint(-10000, 10000) for _ in range(100)], "stress100"))
    cases.append((500, [random.Random(1337).randint(-50000, 50000) for _ in range(500)], "stress500"))
    cases.append((1000, [random.Random(2026).randint(-1000000, 1000000) for _ in range(1000)], "icpcstress1000"))

    # Format inputs & expected outputs
    formatted_tests = []
    for n, nums, s in cases:
        inp = f"{n}\n" + " ".join(str(x) for x in nums) + f"\n{s}\n"
        
        sum_val = sum(nums)
        min_val = min(nums)
        max_val = max(nums)
        evens = sum(1 for x in nums if abs(x) % 2 == 0)
        odds = len(nums) - evens
        rev = s[::-1]

        expected = (
            f"Sum: {sum_val}\n"
            f"Min: {min_val} Max: {max_val}\n"
            f"Evens: {evens} Odds: {odds}\n"
            f"Reversed: {rev}"
        )
        formatted_tests.append((inp, expected))

    return formatted_tests

def run_tests_for_target(name, cmd, tests):
    sys.stdout.write(f"  [{name:<6}] ")
    sys.stdout.flush()

    passed = 0
    for i, (inp, expected) in enumerate(tests, start=1):
        try:
            proc = subprocess.run(
                cmd,
                input=inp,
                text=True,
                capture_output=True,
                timeout=5
            )
            got = proc.stdout.strip().replace("\r\n", "\n")
            exp = expected.strip().replace("\r\n", "\n")
            if proc.returncode == 0 and got == exp:
                passed += 1
                sys.stdout.write(".")
            else:
                sys.stdout.write("F")
        except Exception:
            sys.stdout.write("E")
        sys.stdout.flush()

    pct = (passed / len(tests)) * 100
    if passed == len(tests):
        print(f" [{passed}/{len(tests)} PASSED] (100% OK)")
        return True
    else:
        print(f" [{passed}/{len(tests)} PASSED] (FAILED)")
        return False

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)
    test_src_dir = os.path.join(repo_root, "configs", "test_programs")

    print("============================================================")
    print("      COMPREHENSIVE 30-TEST-CASE COMPILER & RUNTIME SUITE")
    print("============================================================")
    print("Testing 30 automated test cases per language:")
    print("  - Small values, Negative numbers, 64-bit integer overflow")
    print("  - Strings, Palindromes, Stress tests (N=1 to N=1000)")
    print("------------------------------------------------------------")

    tests = generate_30_test_cases()
    temp_dir = tempfile.mkdtemp(prefix="icpc_30tests_")
    overall_pass = True

    try:
        # 1. Test C++
        cpp_src = os.path.join(test_src_dir, "suite_cpp.cpp")
        cpp_exe = os.path.join(temp_dir, "suite_cpp.exe")
        c_compile = subprocess.run(["g++", "-O2", "-std=c++17", cpp_src, "-o", cpp_exe], capture_output=True)
        if c_compile.returncode == 0 and os.path.exists(cpp_exe):
            ok = run_tests_for_target("C++", [cpp_exe], tests)
            if not ok: overall_pass = False
        else:
            print("  [C++]    [FAIL] Could not compile C++ test suite!")
            if c_compile.stderr:
                print(c_compile.stderr.decode(errors="replace").strip())
            overall_pass = False

        # 2. Test C
        c_src = os.path.join(test_src_dir, "suite_c.c")
        c_exe = os.path.join(temp_dir, "suite_c.exe")
        c_compile = subprocess.run(["gcc", "-O2", "-std=c11", c_src, "-o", c_exe], capture_output=True)
        if c_compile.returncode == 0 and os.path.exists(c_exe):
            ok = run_tests_for_target("C", [c_exe], tests)
            if not ok: overall_pass = False
        else:
            print("  [C]      [FAIL] Could not compile C test suite!")
            if c_compile.stderr:
                print(c_compile.stderr.decode(errors="replace").strip())
            overall_pass = False

        # 3. Test Java
        java_src = os.path.join(test_src_dir, "SuiteJava.java")
        java_compile = subprocess.run(["javac", "-d", temp_dir, java_src], capture_output=True)
        if java_compile.returncode == 0:
            ok = run_tests_for_target("Java", ["java", "-cp", temp_dir, "SuiteJava"], tests)
            if not ok: overall_pass = False
        else:
            print("  [Java]   [FAIL] Could not compile Java test suite!")
            overall_pass = False

        # 4. Test Python
        py_src = os.path.join(test_src_dir, "suite_py.py")
        if os.path.exists(py_src):
            ok = run_tests_for_target("Python", [sys.executable, py_src], tests)
            if not ok: overall_pass = False
        else:
            print("  [Python] [FAIL] Could not find Python test suite!")
            overall_pass = False

    finally:
        # Cleanup
        for f in os.listdir(temp_dir):
            try: os.remove(os.path.join(temp_dir, f))
            except Exception: pass
        try: os.rmdir(temp_dir)
        except Exception: pass

    print("------------------------------------------------------------")
    if overall_pass:
        print(" RESULT: [ALL 120 TEST CASES PASSED] Toolchains 100% operational!")
        print("============================================================")
        sys.exit(0)
    else:
        print(" RESULT: [ONE OR MORE TEST SUITES FAILED]")
        print("============================================================")
        sys.exit(1)

if __name__ == "__main__":
    main()

