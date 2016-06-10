#!/bin/sh

PORT=22
FILES="lstadmin@lists1-prod-v.dc.nd.edu:/home/listserv/home/*.list"
DESTINATION=/apps/listserv-converter/tmp/listserv/

mkdir -p $DESTINATION
scp -P $PORT $FILES $DESTINATION