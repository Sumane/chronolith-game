#!/bin/bash
# Self-contained RSS probe: runs the smoke test detached, samples the real
# godot process RSS every 3s for 3 min, writes everything to .rss-probe.
# Survives session crashes (setsid); results persist on disk either way.
cd /home/marc/AI/Chronolith-Game || exit 1
OUT=.rss-probe
{
  echo "probe start: $(date)"
  echo "mem: $(free -h | awk '/^Mem/{print $3" used, "$7" available"}')"
} > $OUT
env XDG_DATA_HOME=$PWD/.xdg setsid nohup timeout 300 godot --headless --path . res://tests/smoke_test.tscn > .testlog 2>&1 &
GP=$(pgrep -x godot | head -1)
echo "godot pid: $GP" >> $OUT
for i in $(seq 1 60); do
  sleep 3
  G=$(pgrep -x godot | head -1)
  if [ -n "$G" ]; then
    RSS=$(awk '/^VmRSS/{print $2}' /proc/$G/status 2>/dev/null)
    SWP=$(awk '/^VmSwap/{print $2}' /proc/$G/status 2>/dev/null)
    echo "t=$((i*3))s rss=${RSS}kB swap=${SWP}kB sys_avail=$(awk '/MemAvailable/{print $2/1048576"GB"}' /proc/meminfo)" >> $OUT
  else
    echo "t=$((i*3))s: godot gone" >> $OUT
    break
  fi
done
echo "probe end: $(date)" >> $OUT
echo "testlog tail: $(tail -2 .testlog 2>/dev/null | tr '\n' ' | ')" >> $OUT
