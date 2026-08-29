#!/bin/bash
# Crash-proof bisect: (A) idle game main.tscn, (B) smoke test.
# Each: detached godot, 5s RSS samples to .rss-main / .rss-test on disk.
# Session crashes lose nothing — both files persist.
cd /home/marc/AI/Chronolith-Game || exit 1
export XDG_DATA_HOME=$PWD/.xdg

run_probe() {
  local name=$1 scene=$2 dur=$3
  local out=".rss-$name"
  {
    echo "=== $name start: $(date)"
    echo "mem: $(free -h | awk '/^Mem/{print $3" used, "$7" avail"}')"
  } > $out
  setsid nohup timeout $dur godot --headless --path . $scene > ".log-$name" 2>&1 &
  for i in $(seq 1 $((dur/5))); do
    sleep 5
    local G
    G=$(pgrep -x godot | head -1)
    if [ -n "$G" ]; then
      echo "t=$((i*5))s rss=$(awk '/^VmRSS/{print $2}' /proc/$G/status 2>/dev/null)kB" >> $out
    else
      echo "t=$((i*5))s: godot gone" >> $out
      break
    fi
  done
  echo "=== $name end: $(date)" >> $out
  echo "last log line: $(tail -1 .log-$name 2>/dev/null)" >> $out
}

run_probe empty res://tests/empty.tscn 60
sleep 8
run_probe main res://core/main.tscn 120
sleep 8
run_probe test res://tests/smoke_test.tscn 120
echo "ALL DONE: $(date)" > .rss-bisect-done
