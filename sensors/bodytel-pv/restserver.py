#
# Copyright (c) 2013, MGRID BV Netherlands
#
# Simple example json server that inserts incoming json strings straight into
# the database
#
import sys

from bottle import post, run, request, abort
import json
import psycopg2

conn = psycopg2.connect('host=127.0.0.1 dbname=sensor user=ec2-user')
cur = conn.cursor()

@post('/observation')
def put_document():
        global cur, conn

	data = request.body.readline()
	if not data:
		abort(400, 'No data received')
	entity = json.loads(data)

        sql = cur.mogrify('INSERT INTO sensor_data(message) VALUES (%s)', (data,))
        print sql
        cur.execute(sql)
        conn.commit()

@post('/authenticate')
def put_auth():
        data = request.body.readline()
	if not data:
		abort(400, 'No data received')
        print data

        return {'scope': 'all', 'access_token': 'banana'}

run(host='10.33.170.16', port=80, debug=True)
