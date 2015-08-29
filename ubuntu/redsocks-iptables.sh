#!/bin/sh

IPTABLES="/sbin/iptables"
REDSOCKS="/usr/bin/redsocks"
REDSOCKSCFG="/home/nemo/.redsocks/redsocks.conf"
REDSOCKS_PORT="12345" #local_port in $REDSOCKSCFG

if [ "$1" = "start" ]; then
        echo '(Re)starting redsocks...'
        pkill -U $USER redsocks 2>/dev/null
        sleep 1
        $REDSOCKS -c $REDSOCKSCFG
        echo '(Re)starting pdnsd'
        pkill -U $USER pdnsd 2>/dev/null
        pdnsd -d -mto -c $PDNSDCFG
        $IPTABLES -t nat -F
        $IPTABLES -t nat -X


        $IPTABLES -t nat -D PREROUTING -p tcp -j REDSOCKS_FILTER 2>/dev/null
        $IPTABLES -t nat -D OUTPUT     -p tcp -j REDSOCKS_FILTER 2>/dev/null
        $IPTABLES -t nat -F REDSOCKS_FILTER 2>/dev/null
        $IPTABLES -t nat -X REDSOCKS_FILTER 2>/dev/null
        $IPTABLES -t nat -F REDSOCKS 2>/dev/null
        $IPTABLES -t nat -X REDSOCKS 2>/dev/null

# Create our own chain
        $IPTABLES -t nat -N REDSOCKS
        $IPTABLES -t nat -N REDSOCKS_FILTER

# Do not try to redirect local traffic
        $IPTABLES -t nat -I REDSOCKS_FILTER -o lo -j RETURN


# Do not redirect LAN traffic and some other reserved addresses. (blacklist option)
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 0.0.0.0/8 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 10.0.0.0/8 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 127.0.0.0/8 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 169.254.0.0/16 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 172.16.0.0/12 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 192.168.0.0/16 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 224.0.0.0/4 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d 240.0.0.0/4 -j RETURN
        $IPTABLES -t nat -A REDSOCKS_FILTER -d $SERVER -j RETURN 
        $IPTABLES -t nat -A REDSOCKS_FILTER -j REDSOCKS

# Redirect all traffic that gets to the end of our chain
        $IPTABLES -t nat -A REDSOCKS   -p tcp -j REDIRECT --to-port $REDSOCKS_PORT

## Filter all traffic from the own host
## BE CAREFULL HERE IF THE SOCKS-SERVER RUNS ON THIS MACHINE
        $IPTABLES -t nat -A OUTPUT     -p tcp -j REDSOCKS_FILTER

# Filter all traffic that is routed over this host
        $IPTABLES -t nat -A PREROUTING -p tcp -j REDSOCKS_FILTER

        echo IPtables reconfigured.
        exit 0;
elif [ "$1" = "stop" ]; then
        $IPTABLES -t nat -F
        $IPTABLES -t nat -X
        killall redsocks
        killall pdnsd
        exit 0;
else
        exit 1;
fi
