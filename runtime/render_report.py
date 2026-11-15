"""Optional post-analysis Word entry. Never imported by the R runtime."""
import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True)
    parser.add_argument("--output")
    parser.add_argument("--internal-dir")
    parser.add_argument("--enable", action="store_true", help="Explicitly opt in to Word reporting")
    args = parser.parse_args()
    from reporting.workflow import run
    result = run(args.config, args.output, args.internal_dir, args.enable)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
