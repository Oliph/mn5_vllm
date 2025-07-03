#!/bin/bash
export VLLM_HOST_IP=$(hostname --ip-address | awk '{print $1}')
node=$1
port=$2

echo "[HEAD] Node: $node"
echo "[HEAD] Port: $port"
echo "[HEAD] Args passed to vLLM: $@"

cd /gpfs/projects/bsc02/sla_projects/vllm_server || exit 1
echo "[HEAD] Changed to working directory."

module purge && module load mkl intel nccl/2.24.3-1 python/3.12
echo "[HEAD] Modules loaded."

echo "[HEAD] PYTHONPATH BEFORE UNSETTING: $PYTHONPATH"
unset PYTHONPATH
echo "[HEAD] PYTHONPATH unsetted"

source venv_mn5/bin/activate
echo "[HEAD] Virtual environment activated."

ip=$(hostname --ip-address | awk '{print $1}')
echo "[HEAD] Host IP: $ip"

# Auto-detect resources
num_cpus=$(nproc)
num_gpus=$(nvidia-smi -L | wc -l)

# echo "[HEAD] Starting Ray head"
echo "[HEAD] Starting Ray head with resources: CPU=$num_cpus, GPU=$num_gpus"
ray start --head --port="$port" \
  --num-cpus="$num_cpus" \
  --num-gpus="$num_gpus" \
  --resources="{\"node:0.0.0.0\": 1}"

echo "[HEAD] Ray head started successfully."

expected_nodes=${VLLM_EXPECTED_WORKERS:-1}
max_wait_seconds=120
waited=0
time_waiting_workers=15

echo "[HEAD] Waiting $waiting_workers sec for $expected_nodes Ray nodes to connect..."

sleep $time_waiting_workers
#
# while true; do
#   connected_nodes=$(ray status --json | python -c "import sys, json; print(len(json.load(sys.stdin)['nodes']))")
#   echo "[HEAD] Connected Ray nodes: $connected_nodes / $expected_nodes"
#
#   if [ "$connected_nodes" -ge "$expected_nodes" ]; then
#     echo "[HEAD] All Ray nodes are connected."
#     break
#   fi
#
#   sleep 5
#   waited=$((waited + 5))
#
#   if [ "$waited" -ge "$max_wait_seconds" ]; then
#     echo "[HEAD] Timeout: Not all Ray nodes connected after ${max_wait_seconds}s"
#     break
#   fi
# done

echo "[HEAD] Launching vLLM workload..."
echo "[HEAD] ENV VLLM_GPUs passed as tensor-parallel-size args: $VLLM_GPUS"
echo "[HEAD] ENV VLLM_NTASKS passed as pipeline-parallel-size args: $VLLM_NTASKS"
echo "[HEAD] ENV VLLM_MAX_NUM_SEQS passed as max_args: $VLLM_MAX_NUM_SEQS"
./launch_vllm.sh "$VLLM_GPUS" "$VLLM_NTASKS" \
  --max-num-seqs "${VLLM_MAX_NUM_SEQS:-256}" \
  "$@"
# echo "[HEAD] Run tail -f /dev/null to keep the server alive"
# tail -f /dev/null
