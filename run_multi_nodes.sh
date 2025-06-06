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
# 1. Get hostnames and define head/worker nodes
# ----------------------------
nodes=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
head_node=${nodes[0]}
worker_nodes=("${nodes[@]:1}")

echo "Head node: $head_node"
echo "Worker nodes: ${worker_nodes[*]}"

# ----------------------------
# 2. Get internal IP address of head node (used for Ray communication)
# ----------------------------
# head_ip=$(srun --nodes=1 --ntasks=1 -w "$head_node" hostname --ip-address | awk '{print $1}')
port=6379

# ----------------------------
# 3. Calculate total GPUs
# ----------------------------
ntasks=${SLURM_NTASKS:-1}
ntasks_per_node=${SLURM_NTASKS_PER_NODE:-0}
gres_line=${SLURM_JOB_GRES:-$(scontrol show job "$SLURM_JOB_ID" | grep -oP 'Gres=\K[^ ]*')}
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
# 4. Start Ray Head Node
# ----------------------------
echo "Starting Ray head on $head_node ($head_node:$port)"
srun --nodes=1 --ntasks=1 -w "$head_node" \
  ray start --head --node-ip-address="$head_node" --port="$port" &

sleep 10

# ----------------------------
# 5. Start Ray Worker Nodes
# ----------------------------
for node in "${worker_nodes[@]}"; do
  worker_ip=$(srun --nodes=1 --ntasks=1 -w "$node" hostname --ip-address | awk '{print $1}')
  echo "Starting Ray worker on $node ($worker_ip)"
  srun --nodes=1 --ntasks=1 -w "$node" \
    ray start --address="$head_node:$port" --node-ip-address="$worker_ip" &
done

wait

# ----------------------------
# 6. Launch Workload on Head Node
# ----------------------------
echo "All Ray nodes started."
echo "Launching vLLM workload on head node"

srun --nodes=1 --ntasks=1 -w "$head_node" ./launch_vllm.sh "$total_gpus" "$@"
