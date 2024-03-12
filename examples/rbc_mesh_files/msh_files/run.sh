#!/bin/bash -l
# The -l above is required to get the full environment with modules

##salloc --nodes=1 -t 0:30:00 -A snic2022-3-25 -p shared

# Set the allocation to be charged for this job
# not required if you have set a default allocation
#SBATCH -A snic2022-3-25

# The name of the script is myjob
#SBATCH -J mesh_generation_250
#SBATCH --output=log.o%j # Name of stdout output file
#SBATCH --error=log.e%j  # Name of stderr error file

# The partition
#SBATCH -p main

# 1 hour wall-clock time will be given to this job
#SBATCH -t 06:00:00

# Number of nodes
#SBATCH --nodes=1

# Number of MPI processes per node
#SBATCH --ntasks-per-node=1

#SBATCH --mail-type=all         # Send email at begin and end of job
#SBATCH --mail-user=adperez@kth.se

#SBATCH --mem=250GB 

./batch_create_msh.sh
