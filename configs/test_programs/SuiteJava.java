import java.util.Scanner;

public class SuiteJava {
    public static void main(String[] args) {
        Scanner sc = new Scanner(System.in);
        if (!sc.hasNextInt()) return;

        int n = sc.nextInt();
        if (n <= 0) return;

        long sum = 0;
        long minVal = 0, maxVal = 0;
        int evens = 0, odds = 0;

        for (int i = 0; i < n; i++) {
            long val = sc.nextLong();
            sum += val;
            if (i == 0) {
                minVal = val;
                maxVal = val;
            } else {
                if (val < minVal) minVal = val;
                if (val > maxVal) maxVal = val;
            }
            if (Math.abs(val) % 2 == 0) {
                evens++;
            } else {
                odds++;
            }
        }

        String s = sc.hasNext() ? sc.next() : "";
        String reversed = new StringBuilder(s).reverse().toString();

        System.out.println("Sum: " + sum);
        System.out.println("Min: " + minVal + " Max: " + maxVal);
        System.out.println("Evens: " + evens + " Odds: " + odds);
        System.out.println("Reversed: " + reversed);
    }
}

