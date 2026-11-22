#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Runner trial: one line per phase, "TRIAL| <phase> | <seconds since the
# previous mark> | disk now | disk peak | memory peak | sizes", then df -h.
# TRIAL_ROOT names the build disk; TRIAL_SIZES is a list of name=path.
label=${1:?label}
state=${RUNNER_TEMP:-/tmp}/trial
mkdir -p "$state"
now=$(date +%s)
last=$(cat "$state/last" 2> /dev/null || echo "$now")
echo "$now" > "$state/last"
root=${TRIAL_ROOT:-$PWD}
disk=$(df -Pk "$root" | awk 'NR==2 {printf "used %.1fG free %.1fG", $3/1048576, $4/1048576}')
sizes=
for entry in ${TRIAL_SIZES:-}; do
  name=${entry%%=*}
  path=${entry#*=}
  if [ -e "$path" ]; then
    sizes="$sizes $name=$(du -sk "$path" 2> /dev/null | awk '{printf "%.2fG", $1/1048576}')"
  fi
done
echo "TRIAL| $label | $((now - last)) s | $disk | disk peak $(( $(cat "$state/diskpeak" 2> /dev/null || echo 0) / 1024 ))G | mem peak $(cat "$state/mempeak" 2> /dev/null || echo '?') MiB |$sizes"
df -h 2> /dev/null | grep -v -E '^(tmpfs|devfs|map|udev)' || true
