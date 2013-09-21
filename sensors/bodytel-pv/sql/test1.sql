/*
 * test1.sql
 *
 * Copyright (c) 2013, Portavita BV Netherlands
 */
COPY sensor_data(message) FROM stdin;
{"diastolic":71.0,"systolic":129.0,"type":"blood_pressure","date":"20130920103026.995+0200","token":"banana"}
{"type":"heart_rate","value":62,"date":"20130920103026.995+0200","token":"banana"}
{"type":"heart_rate","value":63,"date":"20130920103026.995+0200","token":"banana"}
{"period":"BB","status":"N","type":"glucose","value":2.2222,"date":"20130920103500.0+0200","token":"banana"}
\.
