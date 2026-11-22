#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Runner trial: samples memory and disk use every 5 s and keeps the peaks
# in $RUNNER_TEMP/trial (mempeak, diskpeak in MiB). Started detached.
state=${RUNNER_TEMP:-/tmp}/trial
root=${1:-$PWD}
mkdir -p "$state"
pm=0
pd=0
while true; do
  if [ "$(uname -s)" = Darwin ]; then
    m=$(vm_stat | awk -v ps="$(sysctl -n hw.pagesize)" '
      /Pages active/ {a=$3} /Pages wired down/ {w=$4} /occupied by compressor/ {c=$5}
      END {gsub("\\.","",a); gsub("\\.","",w); gsub("\\.","",c); print int((a+w+c)*ps/1048576)}')
  else
    m=$(free -m | awk '/^Mem:/ {print $3}')
  fi
  d=$(df -Pk "$root" | awk 'NR==2 {print int($3/1024)}')
  if [ "${m:-0}" -gt "$pm" ]; then pm=$m; echo "$pm" > "$state/mempeak"; fi
  if [ "${d:-0}" -gt "$pd" ]; then pd=$d; echo "$pd" > "$state/diskpeak"; fi
  sleep 5
done
