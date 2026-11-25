#!/usr/bin/env python3
"""Align the `// ` comments in every code block of a tour file.

In each ```ts / ```tsx / ```js / ```jsx block, every comment moves to one column:
2 spaces after the longest code line (box headers `┌─ …` and the card lines
under them, up to the first empty `│` line, don't count).
A line holding only a comment is the 2nd line of the comment above it,
or stands alone (a `// 🔴 removed: …` mark, or after a line with no comment).
Usage: align-comments.py <tour.md>   (rewrites the file in place)
"""
import re
import sys

LANGS = re.compile(r'^```(ts|tsx|js|jsx)\s*$')


def parse(line):
    only = re.match(r'^([\s│]*)(// .*)$', line)
    if only:
        return None, only.group(2)
    m = re.match(r'^(.*?\S)\s+(// .*)$', line)
    if m and m.group(1).strip(' │'):
        return m.group(1), m.group(2)
    return line.rstrip(), None


def align(block):
    rows, card = [], False
    for line in block:
        if '┌─' in line:
            card = True
        elif card and (not line.strip(' │') or '└─' in line):
            card = False
        elif card:
            rows.append((line.rstrip(), [], True))
            continue
        code, comment = parse(line)
        if code is None and rows and rows[-1][1] and '🔴 removed' not in comment:
            rows[-1][1].append(comment)
            continue
        rows.append((code if code is not None else '', [comment] if comment else [], False))
    if not any(comments for _, comments, _ in rows):
        return block
    widths = [len(code) for code, _, is_card in rows
              if code.strip(' │') and '┌─' not in code and not is_card]
    column = max(widths) + 2
    out = []
    for code, comments, _ in rows:
        if not comments:
            out.append(code)
            continue
        bars = re.match(r'^[\s│]*', code).group(0).rstrip()
        out.append(code.ljust(column) + comments[0])
        out.extend(bars.ljust(column) + c for c in comments[1:])
    return out


def main(path):
    out, block, inside = [], [], False
    for line in open(path, encoding='utf-8').read().split('\n'):
        if not inside and LANGS.match(line):
            inside, block = True, []
            out.append(line)
        elif inside and line.startswith('```'):
            out.extend(align(block))
            out.append(line)
            inside = False
        else:
            (block if inside else out).append(line)
    open(path, 'w', encoding='utf-8').write('\n'.join(out))


if __name__ == '__main__':
    main(sys.argv[1])
