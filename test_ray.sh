#!/bin/bash
#SBATCH --job-name=test_ray
#SBATCH --ntasks=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --time=00:10:00
#SBATCH --output=logs/ray_test_%j.out
#SBATCH --error=logs/ray_test_%j.err

# Load your environment (adjust as needed)
# Load your environment (adjust as needed)
cd /gpfs/projects/bsc02/sla_projects/vllm_server
module purge
module purge && module load mkl intel python/3.12

source venv_mn5/bin/activate

# Get allocated nodes
nodes=($(scontrol show hostnames $SLURM_JOB_NODELIST))
head_node=${nodes[0]}
worker_nodes=("${nodes[@]:1}")
port=6379

echo "HEAD NODE: $head_node"
echo "WORKERS  : ${worker_nodes[*]}"

# Start Ray head
srun --nodes=1 --ntasks=1 -w $head_node \
  ray start --head --node-ip-address=$head_node --port=$port &

sleep 10 # Wait for head to start

# Start Ray workers
for node in "${worker_nodes[@]}"; do
  echo "Starting worker on $node"
  srun --nodes=1 --ntasks=1 -w $node \
    ray start --address="$head_node:$port" &
done

wait

echo "Ray cluster should now be up"
echo "Testing connection from head node..."

# Test ray.init from the head node
srun --nodes=1 --ntasks=1 -w $head_node python -c "
import ray
print('Connecting to ray://$head_node:$port')
ray.init(address='ray://$head_node:$port')
print('Ray initialized successfully. Cluster resources:')
print(ray.cluster_resources())
"
