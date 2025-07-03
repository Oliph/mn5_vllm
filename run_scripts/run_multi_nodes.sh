#!/bin/bash
#SBATCH --job-name=vllm_multi
#SBATCH --ntasks-per-node=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=80
#SBATCH --gres=gpu:4
#SBATCH --time=01:00:00
#SBATCH --output=logs/slurm_multi_%j.out
#SBATCH --error=logs/slurm_multi_%j.err

# ----------------------------
# 0. Load environment and enter project directory
# ----------------------------
cd /gpfs/projects/bsc02/sla_projects/vllm_server

module purge && module load mkl intel python/3.12
unset PYTHONPATH
source venv_mn5/bin/activate

# ----------------------------
# 1. Parse optional --address=ip:port for external Ray head
# ----------------------------
external_address=""
for arg in "$@"; do
  if [[ $arg == --address=* ]]; then
    external_address="${arg#--address=}"
    # Remove it from $@ so it doesn't go into launch_vllm.sh
    set -- "${@/$arg/}"
  fi
done

# ----------------------------
# 2. Get hostnames and define head/worker nodes
# ----------------------------
nodes=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
head_node=${nodes[0]}
worker_nodes=("${nodes[@]:1}")

echo "Head node: $head_node"
echo "Worker nodes: ${worker_nodes[*]}"

# ----------------------------
# 3. Define port and get GPUs
# ----------------------------
port=6379

ntasks=${SLURM_NTASKS:-1}
ntasks_per_node=${SLURM_NTASKS_PER_NODE:-0}
gres_line=$(scontrol show job "$SLURM_JOB_ID" | grep -i "Gres=" | awk -F'Gres=' '{print $2}' | awk '{print $1}')
gpus_per_task=$(echo "$gres_line" | grep -oP 'gpu:\K[0-9]+' || echo 0)

if [[ "$ntasks_per_node" -gt 0 ]]; then
  nodes_count=${SLURM_JOB_NUM_NODES:-1}
  total_gpus=$((nodes_count * ntasks_per_node * gpus_per_task))
else
  total_gpus=$((ntasks * gpus_per_task))
fi

echo "Detected configuration:"
echo "  GRES line      : $gres_line"
echo "  Tasks          : $ntasks"
echo "  GPUs per task  : $gpus_per_task"
echo "  Total GPUs     : $total_gpus"

# ----------------------------
# 4. Start Ray head (if not using external address)
# ----------------------------
if [[ -z "$external_address" ]]; then
  head_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address | awk '{print $1}')
  echo "Starting Ray head on $head_node (IP: $head_ip:$port)"

  srun --nodes=1 --ntasks=1 -w "$head_node" \
    ray start --head &

  ray_address="$head_ip:$port"
else
  echo "Using external Ray head at $external_address"
  ray_address="$external_address"
fi

sleep 10

# ----------------------------
# 5. Start Ray workers
# ----------------------------
for node in "${worker_nodes[@]}"; do
  worker_ip=$(srun --nodes=1 --ntasks=1 -w "$node" hostname --ip-address | awk '{print $1}')
  echo "Starting Ray worker on $node (IP: $worker_ip)"

  srun --nodes=1 --ntasks=1 -w "$node" \
    ray start --address="$ray_address" &
done

wait

# ----------------------------
# 6. Launch Workload (only on head node if no external address)
# ----------------------------
if [[ -z "$external_address" ]]; then
  echo "All Ray nodes started."
  echo "Launching vLLM workload on head node"

  srun --nodes=1 --ntasks=1 -w "$head_node" ./launch_vllm.sh "$total_gpus" "$@"
else
  echo "Ray workers connected to external head. No workload launched."
fi
