#!/bin/bash
#SBATCH --job-name=test_ray
#SBATCH --ntasks-per-node=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=80
#SBATCH --gres=gpu:4
#SBATCH --time=01:00:00
#SBATCH --output=logs/ray_test_%j.out
#SBATCH --error=logs/ray_test_%j.err

cd /gpfs/projects/bsc02/sla_projects/vllm_server
module purge
module purge && module load mkl intel python/3.12

source venv_mn5/bin/activate

# 2. Get the IP of the node (not hostname)
port=6359
head_ip=$(hostname --ip-address | awk '{print $1}')
echo "Using IP: $head_ip"
export RAY_ADDRESS="$head_ip:$port"

# 3. Start Ray head with correct binding and debug logging
ray start --head \
  --node-ip-address="$head_ip" \
  --port="$port" \
  --dashboard-host=0.0.0.0 \
  --include-dashboard true

# 4. Sleep to keep node alive for interaction/debugging
echo "Ray head started on $head_ip:$port"
echo "Use: ray status --address=$head_ip:$port"
tail -f /dev/null
# Start Ray workers
# for node in "${worker_nodes[@]}"; do
#   echo "Starting worker on $node"
#   srun --nodes=1 --ntasks=1 -w $node \
#     ray start --address="$head_node:$port" &
# done
#
# wait
#
# echo "Ray cluster should now be up"
# echo "Testing connection from head node..."
#
# # Test ray.init from the head node
# srun --nodes=1 --ntasks=1 -w $head_node python -c "
# import ray
# print('Connecting to ray://$head_node:$port')
# ray.init(address='ray://$head_node:$port')
# print('Ray initialized successfully. Cluster resources:')
# print(ray.cluster_resources())
# "
