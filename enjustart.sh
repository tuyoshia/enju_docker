#!/bin/sh
/etc/init.d/postgresql start
/etc/init.d/redis-server start
foreman start
