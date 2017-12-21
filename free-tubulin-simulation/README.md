# Free tubulin simulation

Source files necessary to start simulations of straight GTP-tubulin (PDB IDs: 3JAT) using CHARMM22* force field (*Piana et al., 2011. Biophys J., 100(9):L47-9*) and GROMACS 4.6. The force field was modified to include GTP/GDP parameters adapted from CHARMM27. Simulations of other tubulin dimers were performed using the same protocol.

# Overview of files

* `charmm22star_dev1.2.ff.tar.gz` - modified CHARMM22* force field

* **input_1_preparation**:
  * `3jat_chainABQX_GMPCPP.pdb` - starting structure
  * `create_top_CP_prep.bash` - bash script to create topology files for preparation
  * `em.mdp` - config file for initial energy minimization
  * `pr_pre_NVT_100K.mdp` - config file for subsequent equilibration with position restraints in NVT ensemble
  * `heating_NPT_100K-300K/` - set of config files for step-wise heating from 100K to 300K in NPT ensemble

* **input_2_production**:
  * `LAST_6000ps_3jat_heating_300K.pdb` - starting structure for production runs (the last frame from preparation)
  * `create_top_CP_prod.bash` - bash script to create topology files for production
  * `em2.mdp` - config file for initial energy minimization
  * `pr_NVT_300K.mdp` - config file for equilibration with position restraints in NVT ensemble at 300K
  * `run_NPT_300K.mdp` - config file for 1 microsecond production run

# Setting up the simulation

**Preparation**:
 1. Create topology files using `create_top_CP_prep.bash` and the starting structure
 2. Larger simulation box: `editconf -f gmx_structure.pdb -n gmx_structure_box.pdb -bt dodecahedron -d 1.5`
 3. Add waters: `genbox -cp gmx_structure_box.pdb -cs spc216.gro -o gmx_structure_wb.pdb -p gmx_structure.top`
 4. Create a dummy `*.tpr` to add ions later: `grompp -f empty_file.mdp -c gmx_structure_wb.pdb -p gmx_structure.top -o dummy.tpr`
 5. Add 150mM KCL using the dummy file: `genion -s dummy.tpr -o gmx_structure_150mM.pdb -p gmx_structure.top -pname K -nname CL -conc 0.15 -neutral`
 6. Create `*.tpr` for energy minimization: `grompp -f em.mdp -c gmx_structure_150mM.pdb -p gmx_structure.top -o em.tpr`
 7. Once the minimization is done, proceed to equilibration with position restraints and heating simulations
 
 **Production**:
  1. Extract the last frame from the heating simulation at 300K: `trjconv -f heating_NPT_300K.xtc -s heating_NPT_300K.tpr -o LAST_6000ps_3jat_heating_300K.pdb -pbc mol -ur compact -b 6000 -e 6000`
  2. Trim the structure to remove all waters, KCL ions, and hydrogens. The resulting structure should contain only alpha- and beta-chains and 2 GTP + 2 Mg2+ (GDP and GTP + Mg2+, if GDP-tubulin is simulated)
  3. Follow the procedure in **Preparation** to set up the production simulation
