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
# Replica announce — FIXED for NetBird + Docker
###############################################
# Always announce the HOST port (6380, 6381, etc.)
# Always announce the NetBird private IP (10.50.x.x)

replica-announce-ip ${PUBLIC_IP}
replica-announce-port ${HOST_PORT}

# Backward compatibility (Redis still accepts)
slave-announce-ip ${PUBLIC_IP}
slave-announce-port ${HOST_PORT}


###############################################
# Replica settings (added automatically)
###############################################
# setup-instance.sh will append:
# replicaof <master_ip> <master_port>


###############################################
# Redis Stack Modules (ALL)
###############################################
# RedisJSON (JSON.SET / JSON.GET)
loadmodule /opt/redis-stack/lib/rejson.so

# RediSearch (FT.SEARCH / FT.CREATE)
loadmodule /opt/redis-stack/lib/redisearch.so

# RedisBloom (Bloom/Cuckoo/TopK/CountMin)
loadmodule /opt/redis-stack/lib/redisbloom.so

# RedisTimeSeries (TS.ADD / TS.GET / TS.RANGE)
loadmodule /opt/redis-stack/lib/redistimeseries.so

# RedisGraph (GRAPH.QUERY)
loadmodule /opt/redis-stack/lib/redisgraph.so