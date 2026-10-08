#!/usr/bin/env python3
"""Explicit, opt-in copy of an existing Nomi development data directory."""
import argparse
import shutil
from pathlib import Path


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--source', required=True, type=Path)
parser.add_argument('--destination', required=True, type=Path)
parser.add_argument('--apply', action='store_true', help='perform the copy after interactive confirmation')
args = parser.parse_args()
source = args.source.expanduser().resolve(strict=True)
destination = args.destination.expanduser().resolve()

if not source.is_dir() or not (source / 'journal.db').is_file():
    parser.error('source must be a directory containing journal.db')
if source == destination or source in destination.parents or destination in source.parents:
    parser.error('source and destination must be separate, non-nested directories')
if destination.exists():
    parser.error('destination already exists; refusing to merge or overwrite data')

print(f"{'APPLY' if args.apply else 'DRY RUN'}: copy {source} -> {destination}")
print('The journal database may contain private data; this script does not open or inspect it.')
if not args.apply:
    print('No files copied. Add --apply and type IMPORT to proceed.')
    raise SystemExit(0)
if input('Type IMPORT to confirm this copy: ') != 'IMPORT':
    raise SystemExit('Cancelled; no files copied.')
shutil.copytree(source, destination, symlinks=True)
print('Copy complete.')
