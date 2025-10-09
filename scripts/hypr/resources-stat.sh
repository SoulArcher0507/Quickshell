#!/usr/bin/env bash
# resources-stat.sh — JSON CPU/GPU/RAM/DISK senza sudo
# Fix: parsing nvidia-smi (no CSV), locale C, sanitizzazione numeri
set -euo pipefail
export LC_ALL=C LANG=C

# ---------- CPU: total + per-core via /proc/stat ----------
read_cpu_snap() {
  awk '/^cpu[0-9]* /{
    id=$1;
    user=$2; nice=$3; sys=$4; idle=$5; iowait=$6; irq=$7; softirq=$8; steal=$9; guest=$10; gnice=$11;
    busy=user+nice+sys+irq+softirq+steal;
    total=busy+idle+iowait+guest+gnice;
    printf "%s %.0f %.0f\n", id, busy, total
  }' /proc/stat
}

mapfile -t S1 < <(read_cpu_snap)
sleep 0.25
mapfile -t S2 < <(read_cpu_snap)

calc_pct() { awk -v b1="$1" -v t1="$2" -v b2="$3" -v t2="$4" 'BEGIN{dt=t2-t1; db=b2-b1; print (dt>0? (db/dt*100):0)}'; }

cpu_total=0
per_core=()
for i in "${!S1[@]}"; do
  read -r id b1 t1 <<<"${S1[i]}"
  read -r _  b2 t2 <<<"${S2[i]}"
  p=$(calc_pct "$b1" "$t1" "$b2" "$t2")
  if [[ "$id" == "cpu" ]]; then cpu_total="$p"; else per_core+=("$p"); fi
done

per_core_csv=""
for v in "${per_core[@]}"; do per_core_csv+=$(printf '%.2f,' "$v"); done
per_core_csv="${per_core_csv%,}"

# ---------- RAM ----------
read -r mem_used_gb mem_total_gb mem_pct < <(
  awk '
    /MemTotal:/     {t=$2}
    /MemAvailable:/ {a=$2}
    END{
      used=t-a;
      printf "%.2f %.2f %.2f\n", used/1024/1024, t/1024/1024, (used/t*100)
    }' /proc/meminfo
)

# ---------- DISK (main: / ; tooltip: /home se separata) ----------
disk_root_pct=$(df -P /     | awk 'NR==2{gsub("%","",$5); print $5}')
disk_home_pct=$(df -P /home 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')
[[ -z "${disk_home_pct:-}" ]] && disk_home_pct=$disk_root_pct

# ---------- GPU ----------
gpu_name=""
gpu_total=0
gpu_detail_json=""

num_ok() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] && echo "$1" || echo "0"; }

if command -v nvidia-smi >/dev/null 2>&1; then
  # chiedi campi separati (niente CSV)
  gpu_total=$(nvidia-smi --query-gpu=utilization.gpu     --format=csv,noheader,nounits | head -n1 | tr -d '[:space:]')
  mem_util=$(nvidia-smi  --query-gpu=utilization.memory  --format=csv,noheader,nounits | head -n1 | tr -d '[:space:]')
  gpu_name=$(nvidia-smi  --query-gpu=name                --format=csv,noheader        | head -n1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  gpu_total=$(num_ok "$gpu_total")
  mem_util=$(num_ok "$mem_util")

  gpu_name_esc=${gpu_name//\"/\\\"}
  gpu_detail_json=$(printf '"detail":[{"name":"graphics","percent":%s},{"name":"memory","percent":%s}]' "$gpu_total" "$mem_util")

elif [[ -e /sys/class/drm/card0/device/gpu_busy_percent ]]; then
  # AMDGPU (totale busy)
  gpu_total=$(cat /sys/class/drm/card0/device/gpu_busy_percent 2>/dev/null || echo 0)
  gpu_total=$(num_ok "$gpu_total")
  gpu_name_esc="AMDGPU"

elif ls /sys/class/drm/card0/engine/*/busy_percent >/dev/null 2>&1; then
  # Intel (per-engine, media + dettaglio)
  gpu_name_esc="Intel"
  sum=0; count=0; details=""
  for f in /sys/class/drm/card0/engine/*/busy_percent; do
    v=$(cat "$f" 2>/dev/null || echo 0)
    v=$(num_ok "$v")
    name=$(basename "$(dirname "$f")")
    sum=$(awk -v s="$sum" -v x="$v" 'BEGIN{print s+x}')
    count=$((count+1))
    details+=$(printf '{"name":"%s","percent":%s},' "$name" "$v")
  done
  if ((count>0)); then
    gpu_total=$(awk -v s="$sum" -v c="$count" 'BEGIN{print s/c}')
    gpu_detail_json=$(printf '"detail":[%s]' "${details%,}")
  else
    gpu_total=0
  fi
fi

# ---------- JSON ----------
printf '{'
printf '"cpu":{"total":%.2f,"per_core":[%s]},' "$cpu_total" "$per_core_csv"
printf '"gpu":{"name":"%s","total":%.2f%s},' "${gpu_name_esc:-""}" "$(num_ok "$gpu_total")" "${gpu_detail_json:+,$gpu_detail_json}"
printf '"mem":{"used_gb":%.2f,"total_gb":%.2f,"percent":%.2f},' "$mem_used_gb" "$mem_total_gb" "$mem_pct"
printf '"disk":{"root_percent":%s,"home_percent":%s}' "$disk_root_pct" "$disk_home_pct"
printf '}\n'
