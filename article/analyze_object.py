#!/usr/bin/env python3
"""Count instructions of selected functions in an ARM object file.

Usage: analyze_object.py OBJDUMP OBJECT_FILE LABEL=SYMBOL [LABEL=SYMBOL ...]

For every function prints a Markdown table row: size in bytes, number of
instructions, multiplications (split into 32-bit and 64-bit result ones),
hardware divisions, FPU instructions and calls to library routines.
"""
import re
import subprocess
import sys
from collections import Counter

MULTIPLY_32 = {"mul", "muls", "mla", "mls", "smulbb", "smulbt", "smultb",
               "smultt", "smlabb", "smlabt", "smlatb", "smlatt", "smulwb",
               "smulwt", "smlawb", "smlawt", "smmul", "smmla", "smmls"}
MULTIPLY_64 = {"smull", "umull", "smlal", "umlal", "smlalbb", "smlalbt",
               "smlaltb", "smlaltt", "umaal"}
DIVIDE = {"sdiv", "udiv"}
CONDITIONS = {"eq", "ne", "cs", "cc", "hs", "lo", "mi", "pl", "vs", "vc",
              "hi", "ls", "ge", "lt", "gt", "le", "al"}


def base_mnemonic(mnemonic):
    """Drop width (.w/.n) and condition (inside IT blocks) suffixes."""
    base = mnemonic.split(".")[0]
    known = MULTIPLY_32 | MULTIPLY_64 | DIVIDE | {"bl", "blx"}
    if base not in known and base[-2:] in CONDITIONS and base[:-2] in known:
        base = base[:-2]
    return base


def disassemble(objdump, object_file):
    """Return {symbol: [(mnemonic, operands), ...]}."""
    output = subprocess.run([objdump, "-d", "--no-show-raw-insn", object_file],
                            check=True, capture_output=True, text=True).stdout
    functions = {}
    current = None
    for line in output.splitlines():
        header = re.match(r"^[0-9a-f]+ <(.+)>:$", line)
        if header:
            current = functions.setdefault(header.group(1), [])
            continue
        instruction = re.match(r"^\s+[0-9a-f]+:\s+(\S+)\s*(.*)$", line)
        if instruction and current is not None:
            current.append((instruction.group(1), instruction.group(2)))
    return functions


def describe(instructions):
    multiply_32 = multiply_64 = divide = floating = 0
    calls = Counter()
    for mnemonic, operands in instructions:
        base = base_mnemonic(mnemonic)
        if base in MULTIPLY_32:
            multiply_32 += 1
        elif base in MULTIPLY_64:
            multiply_64 += 1
        elif base in DIVIDE:
            divide += 1
        elif base.startswith("v"):
            floating += 1
        elif base in ("bl", "blx"):
            target = re.search(r"<([^>+]+)", operands)
            calls[target.group(1) if target else operands] += 1
    return multiply_32, multiply_64, divide, floating, calls


def main():
    objdump, object_file, *requests = sys.argv[1:]
    functions = disassemble(objdump, object_file)
    nm = objdump.replace("objdump", "nm")
    sizes = {}
    for line in subprocess.run([nm, "-S", object_file], check=True,
                               capture_output=True, text=True).stdout.splitlines():
        fields = line.split()
        if len(fields) == 4:
            sizes[fields[3]] = int(fields[1], 16)

    for request in requests:
        label, symbol = request.split("=")
        instructions = functions.get(symbol, [])
        multiply_32, multiply_64, divide, floating, calls = describe(instructions)
        call_text = ", ".join(f"{count}× `{name}`"
                              for name, count in sorted(calls.items())) or "—"
        print(f"| {label} | {sizes.get(symbol, 0)} | {len(instructions)} "
              f"| {multiply_32} | {multiply_64} | {divide} | {floating} "
              f"| {call_text} |")


if __name__ == "__main__":
    main()
