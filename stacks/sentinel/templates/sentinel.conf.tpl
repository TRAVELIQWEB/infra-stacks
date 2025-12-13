###############################################
# Basic Sentinel Config (Template)
###############################################

port ${SENTINEL_PORT}
bind 0.0.0.0

# Sentinel must NEVER run in protected mode
protected-mode no

# 🔐 Sentinel authentication
requirepass ${SENTINEL_PASSWORD}

# Run in foreground (docker handles daemon)
daemonize no

# Data directory
dir /data

###############################################
# NOTE:
# - Actual cluster monitor lines are appended
#   by setup-sentinel.sh for every redis instance.
# - NOTHING else should be added here.
###############################################
