#!/bin/bash
# Use the Infiniteband Ip address as VLLM_HOST_IP to ensure it uses it and not the ethernet
export VLLM_HOST_IP=$(ip -4 -o addr show ib0 | awk '{print $4}' | cut -d/ -f1)
set -x
node=$1
head_node=$2
port=$3
echo "[WORKER] Node: $node"
echo "[WORKER] Head node: $head_node"
echo "[WORKER] Port: $port"

cd /gpfs/projects/bsc02/sla_projects/vllm_server || exit 1
echo "[WORKER] Changed to working directory."

module purge && module load mkl intel nccl/2.24.3-1 python/3.12
echo "[WORKER] Modules loaded."

echo "[WORKER] PYTHONPATH BEFORE UNSETTING: $PYTHONPATH"
unset PYTHONPATH
echo "[WORKER] PYTHONPATH unsetted"

source venv_mn5/bin/activate
echo "[WORKER] Virtual environment activated."

head_ip=$(getent hosts "$head_node" | awk '{ print $1 }')
echo "[WORKER] Resolved head IP: ${head_ip}"

# Auto-detect resources
num_cpus=$(nproc)
num_gpus=$(nvidia-smi -L | wc -l)

echo "[WORKER] Connecting to Ray head at ${head_ip}:${port} with resources: CPU=$num_cpus, GPU=$num_gpus"
ray start --address="${head_ip}:${port}" \
  --num-cpus="$num_cpus" \
  --num-gpus="$num_gpus" \
  --resources="{\"node:$VLLM_HOST_IP\": 1}"

echo "[WORKER] Ray worker started and connected."

echo "[WORKER] Run tail -f /dev/null to keep the server alive"
tail -f /dev/null
