#
# Copyright (c) 2013, MGRID BV Netherlands
#
# Simple rest client
#

import urllib2
import os
import json

test = {'key1': 'value',
        'key2': ['value2', 'value3']}
print urllib2.urlopen('http://localhost:8080/authenticate', json.dumps(test)).read()
print urllib2.urlopen('http://localhost:8080/observation', json.dumps(test)).read()
