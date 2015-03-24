#!/usr/bin/env python

"""Collect stats from perf data"""

__author__ = "Adria Armejach"

__version__ = "1.0"

import re
import fileinput
import os
import sys

query = sys.argv[1]

functions = "ExecHashJoin ExecAgg ExecSort ExecScanFetch ExecQual numeric_add numeric_sub numeric_mul numeric_div numeric_inc numeric_mod numeric_cmp numeric_eq numeric_ne numeric_gt numeric_ge numeric_lt numeric_le page_fault".split()

regex = r"\\n(%s)\\n(\d+\.\d+)" % "|".join(functions)

# Get first row right
print "Query\t",
for func in functions:
    print func + "\t",
print ""

input = sys.stdin.read()

m = re.findall(regex,input)

d = dict(m)

print query + "\t",
for func in functions:
    if func in d:
        print d[func] + "\t",
    else:
        print "0.00\t",
print ""
