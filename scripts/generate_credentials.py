import secrets
import csv
import os

# Character pools excluding ambiguous characters:
# - No zero (0) or capital O
# - No one (1), lowercase L (l), or capital I (I)
UPPER = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
LOWER = 'abcdefghijkmnpqrstuvwxyz'
DIGITS = '23456789'
SYMBOLS = '!@#$%&*?'
ALL_CHARS = UPPER + LOWER + DIGITS + SYMBOLS

def generate_strong_password(length=12):
    """Generates a secure 12-char password that is easy for humans to type accurately."""
    pwd = [
        secrets.choice(UPPER),
        secrets.choice(UPPER),
        secrets.choice(LOWER),
        secrets.choice(LOWER),
        secrets.choice(DIGITS),
        secrets.choice(DIGITS),
        secrets.choice(SYMBOLS),
        secrets.choice(SYMBOLS)
    ]
    pwd += [secrets.choice(ALL_CHARS) for _ in range(length - len(pwd))]
    secrets.SystemRandom().shuffle(pwd)
    return ''.join(pwd)

def main():
    root_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    teams_path = os.path.join(root_dir, "teams.txt")
    txt_path = os.path.join(root_dir, "contestant_credentials.txt")
    csv_path = os.path.join(root_dir, "contestant_credentials.csv")

    if not os.path.exists(teams_path):
        print(f"Error: Could not find {teams_path}")
        return

    teams = []
    with open(teams_path, "r", encoding="utf-8") as f:
        for idx, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split("\t") if p.strip()]
            if len(parts) >= 3:
                username = parts[0]
                team_name = parts[1]
                university = parts[2]
            elif len(parts) == 2:
                username = parts[0]
                team_name = parts[1]
                university = "N/A"
            else:
                username = parts[0]
                team_name = f"Team {idx:02d}"
                university = "N/A"
            
            pwd = generate_strong_password(12)
            teams.append({
                "index": idx,
                "pc": f"PC-{idx:02d}",
                "username": username,
                "password": pwd,
                "team_name": team_name,
                "university": university
            })

    # 1. Human-Readable TXT File
    with open(txt_path, "w", encoding="utf-8") as f:
        f.write("=" * 115 + "\n")
        f.write("                       ICPC 2026 - CONTESTANT OFFICIAL CREDENTIALS\n")
        f.write("=" * 115 + "\n")
        f.write(f"  Total Participating Teams: {len(teams)}\n")
        f.write("  Password Standard        : 12-char strong (Upper, Lower, Digit, Symbol)\n")
        f.write("  Usability Note           : Ambiguous characters (0/O, 1/l/I) removed to avoid typing mistakes\n")
        f.write("-" * 115 + "\n")
        f.write(f"{'PC':<7} | {'Username':<17} | {'Password':<15} | {'Team Name':<25} | {'University / Institution':<40}\n")
        f.write("-" * 115 + "\n")
        for t in teams:
            f.write(f"{t['pc']:<7} | {t['username']:<17} | {t['password']:<15} | {t['team_name']:<25} | {t['university']:<40}\n")
        f.write("=" * 115 + "\n")

    # 2. CSV File for DOMjudge / PC^2 / Kattis Import
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["seat", "username", "password", "team_name", "institution"])
        for t in teams:
            writer.writerow([t["pc"], t["username"], t["password"], t["team_name"], t["university"]])

    print(f"Successfully generated credentials for {len(teams)} teams:\n  - {txt_path}\n  - {csv_path}")

if __name__ == "__main__":
    main()
