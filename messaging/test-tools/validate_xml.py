#
# validate a xml file
#
# Copyright (c) 2013, 2014, MGRID BV Netherlands
#
import sys
from lxml import etree
import os

entryschemafile = open(sys.argv[1], 'r')
schemadoc = etree.parse(entryschemafile)
schema = etree.XMLSchema(schemadoc)
doc = etree.parse(sys.argv[2])

print schema.validate(doc)
print schema.error_log
