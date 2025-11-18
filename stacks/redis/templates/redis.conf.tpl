port 6379
bind 0.0.0.0
protected-mode yes

dir /data
logfile /data/redis-${HOST_PORT}.log
dbfilename dump-${HOST_PORT}.rdb

requirepass ${REDIS_PASSWORD}
masterauth ${REDIS_PASSWORD}

appendonly yes
appendfsync everysec

save 900 1
save 300 100
save 60 10000

maxmemory-policy allkeys-lru

###############################################
# Replica announce fix (NO CONDITION HERE)
###############################################
#slave-announce-ip ${PUBLIC_IP}
#slave-announce-port ${HOST_PORT}

# Use NetBird private IP instead of public IP
replica-announce-ip ${NETBIRD_IP}
replica-announce-port ${HOST_PORT}

announce-ip ${NETBIRD_IP}
announce-port ${HOST_PORT}
