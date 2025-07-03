#!/bin/bash
#SBATCH --job-name=vllm_multi
#SBATCH --ntasks-per-node=1
#SBATCH --ntasks=2
#SBATCH --cpus-per-task=80
#SBATCH --gres=gpu:4
#SBATCH --time=01:00:00
#SBATCH --output=logs/slurm_multi_%j.out
#SBATCH --error=logs/slurm_multi_%j.err

# To catch any error and exit directly
set -e

echo "[MULTI] === Starting multi_nodes.sh ==="
echo "[MULTI] SLURM Job ID: $SLURM_JOB_ID"

# ----------------------------
# 0. Project setup
# ----------------------------
cd /gpfs/projects/bsc02/sla_projects/vllm_server || exit 1
echo "[MULTI] Changed to project directory."

module purge && module load mkl intel nccl/2.24.3-1 python/3.12
echo "[MULTI] Loaded required modules."

echo "[MULTI] PYTHONPATH BEFORE UNSETTING: $PYTHONPATH"
unset PYTHONPATH
echo "[MULTI] PYTHONPATH unsetted"

source venv_mn5/bin/activate
echo "[MULTI] Activated Python virtual environment."

# ----------------------------
# 1. Parse optional --address flag
# ----------------------------
external_address=""
for arg in "$@"; do
  if [[ $arg == --address=* ]]; then
    external_address="${arg#--address=}"
    set -- "${@/$arg/}"
  fi
done

# ----------------------------
# 2. Detect allocated nodes
# ----------------------------
nodes=($(scontrol show hostnames "$SLURM_JOB_NODELIST"))
head_node=${nodes[0]}
head_ip=$(hostname --ip-address | awk '{print $1}')
worker_nodes=("${nodes[@]:1}")
port=6379

echo "[MULTI] Allocated nodes: ${nodes[*]}"
echo "[MULTI] Head node: $head_node"
echo "[MULTI] Worker nodes: ${worker_nodes[*]}"
echo "[MULTI] Port: $port"

# ----------------------------
# 3. Calculate GPU configuration
# ----------------------------
ntasks=${SLURM_NTASKS:-1}
ntasks_per_node=${SLURM_NTASKS_PER_NODE:-0}
gres_line=$(scontrol show job "$SLURM_JOB_ID" | grep -i "Gres=" | awk -F'Gres=' '{print $2}' | awk '{print $1}')

gpus_per_task=$(scontrol show job "$SLURM_JOB_ID" | grep -oP 'gres/gpu=\K[0-9]+' | head -n1)

expected_workers=$((ntasks - 1))

total_gpus=$((gpus_per_task * ntasks))
echo "[MULTI] GRES line      : $gres_line"
echo "[MULTI] Tasks          : $ntasks"
echo "[MULTI] GPUs per task  : $gpus_per_task"
echo "[MULTI] Total GPUs     : $total_gpus"

# ----------------------------
# 4. Settint up all the environment variables
# ----------------------------
#
#

# FIXME: Hardcoded pipe-parralelism to 1 and total_gpus. Need to add a flag to chose between them

# export VLLM_GPUS="$gpus_per_task"
# export VLLM_NTASKS="$ntasks"

export VLLM_GPUS="$total_gpus"
export VLLM_NTASKS=1
export VLLM_EXPECTED_WORKERS="$expected_workers"
export NCCL_IB_HCA="mlx5"
# export NCCL_IB_HCA="all"  # Not working.
export NCCL_SOCKET_IFNAME=ib
export NCCL_DEBUG=INFO

# FIXME: Change the 32 to 256 (normal value)
target_total_seqs=32
if [[ "$expected_workers" -eq 0 ]]; then
  # Single-node mode (no distributed workers)
  export VLLM_MAX_NUM_SEQS=$target_total_seqs
else
  export VLLM_MAX_NUM_SEQS=$((target_total_seqs / (expected_workers + 1)))
fi

echo "[MULTI] Setting VLLM_MAX_NUM_SEQS to $VLLM_MAX_NUM_SEQS"

# ----------------------------
# 5. Launch head and workers
# ----------------------------
if [[ -z "$external_address" ]]; then
  echo "[MULTI] No external address provided. Launching head on $head_node"

  echo "[MULTI] Submitting head script on $head_node"
  srun --nodes=1 --ntasks=1 -w "$head_node" \
    --export=ALL \
    ./ray_head.sh "$head_ip" "$port" "$@" &

  ray_address="$head_ip:$port"
  sleep 10 # Give time for head to initialize
else
  echo "[MULTI] Using external Ray head at $external_address"
  ray_address="$external_address"
fi

# ----------------------------
# 6. Launch workers
# ----------------------------
for node in "${worker_nodes[@]}"; do
  echo "[MULTI] Submitting worker script on $node"
  srun --nodes=1 --ntasks=1 -w "$node" \
    --export=ALL \
    ./ray_worker.sh "$node" "$head_ip" "$port" &
done

echo "[MULTI] Waiting for all Ray processes to finish..."
wait

echo "[MULTI] === multi_nodes.sh complete ==="
