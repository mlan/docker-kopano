#!/bin/bash
pkg=${1-kopano-server}
dpkg -l | sed -nr 's/.*'"$pkg"'\s+([^ ]+).*/\1/p'
