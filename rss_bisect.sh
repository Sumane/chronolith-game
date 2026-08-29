#!/bin/bash
# Leaking-bisect: three smoke-test arms, 60s each, RSS sampled every 2s.
# Arm1: SMOKE_SKIP=compile,json   (tests pre-boot script/JSON loads)
# Arm2: SMOKE_SKIP=combat         (tests laser kill + rewind path)
# Arm3: no skip                   (control: expect the ramp)
cd /home/marc/AI/Chronolith-Game || exit 1
run_arm() {
	local name="$1"; shift
	local envs=("$@")
	rm -f ".rss-bisect-$name"
	setsid nohup env "${envs[@]}" XDG_DATA_HOME=$PWD/.xdg timeout 60 \
		godot --headless --path . res://tests/smoke_test.tscn > ".log-bisect-$name" 2>&1 &
	local G=""
	for i in $(seq 1 30); do
		sleep 2
		G=$(pgrep -x godot | head -1)
		if [ -n "$G" ]; then
			echo "s=$((i*2)) rss=$(awk '/^VmRSS/{print $2}' /proc/$G/status 2>/dev/null)kB" >> ".rss-bisect-$name"
		else
			echo "s=$((i*2)) gone" >> ".rss-bisect-$name"
			break
		fi
	done
	sleep 8
}
echo "BISPECT START $(date)"
run_arm skiploads SMOKE_SKIP=compile,json
echo "ARM1 done"
run_arm skipcombat SMOKE_SKIP=combat
echo "ARM2 done"
run_arm control
echo "ARM3 done"
echo "BISPECT END $(date)"
