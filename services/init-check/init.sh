#!/bin/sh
# init-check: used as an INIT CONTAINER (EKS) / non-essential dependency container (ECS)
# Waits until dependent services respond healthy before allowing the main app container to start.

set -e
echo "[init-check] starting dependency checks..."

check_url() {
  url="$1"
  name="$2"
  tries=0
  max_tries=30
  until curl -fs "$url" > /dev/null 2>&1; do
    tries=$((tries + 1))
    if [ "$tries" -ge "$max_tries" ]; then
      echo "[init-check] ERROR: $name at $url did not become healthy after $max_tries tries"
      exit 1
    fi
    echo "[init-check] waiting for $name ($url) ... attempt $tries/$max_tries"
    sleep 2
  done
  echo "[init-check] OK: $name is healthy ($url)"
}

# DEPENDENCY_URLS is a comma separated list, e.g:
# "http://users-service:4001/health,http://products-service:4002/health"
IFS=','
for entry in $DEPENDENCY_URLS; do
  check_url "$entry" "dependency"
done

echo "[init-check] all dependencies healthy. Exiting 0 so main container can start."
exit 0
