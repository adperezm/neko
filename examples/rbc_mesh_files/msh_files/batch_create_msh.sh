# Make sure nek5000 tools are installed.

cp placeholderrea cylinder.rea

nekpath="/cfs/klemming/projects/supr/snic2021-5-555/adperez/software/rbc_mesh_tools/Nek5000/"
tools=$nekpath"tools/"
bin=$nekpath"bin/"

nekopath="/cfs/klemming/projects/supr/snic2021-5-555/adperez/software/cpu_installations/neko/"
contrib=$nekopath"contrib/rea2nbin/"

export PATH=$tools:$PATH
export PATH=$bin:$PATH
export PATH=$contrib:$PATH

# Generate file from gmsh
gmsh pipeMesh.geo -2 -order 2

# Convert to re2
srun -n 1 gmsh2nek < gmsh2nek_input

# Convert to rea
srun -n 1 re2torea < re2torea_input

# Extrude to 3d
srun -n 1 n2to3 < n2to3_input

# Not needed to do this transformation from rea to re2 if n2ton3 outputs in binary
#reatore2 < reatore2_input

# Convert to neko mesh
srun --unbuffered -n 1 rea2nbin cylinder_3d.re2 cylinder.nmsh
