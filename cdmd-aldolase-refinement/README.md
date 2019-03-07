# Refinement of aldolase structure

Source files necessary to refine of the aldolase structure (PDB: 6ALD) into the cryo-EM density (EMD: 8743). CHARMM22* force field (Piana et al., 2011. Biophys J., 100(9): L47-9) was modified for GROMACS 5.0 and 2018 compatibility and to include GTP/GDP and HEME. See `forcefield.doc` for details.

For further details, please see the original publication: Igaev et al., 2019. eLife 8: e43542.

# Overview of files

* **charmm22star_dev1.3.ff/** - modified CHARMM22* force field (includes parameters and hydrogen database entries for GTP/GDP and HEME).

* `6ald_fixed.pdb` - starting structure fixed as described in the original paper (Herzik et al., 2017). This structure is close to the target state because this is a tutorial and we want to keeps things simple. But feel free to try more distant starting structures as described in the paper.

* `create_top.bash` - bash script to create topology files.

* **MDP/** - folder containing GROMACS config files:
  * `em.mdp` - config file for initial energy minimization,
  * `pr_pre_NVT_100K.mdp` - config file for equilibration with position restraints in NVT ensemble,
  * `fit_NPT_100K_eq.mdp` - config file for equilibration without position restraints in NPT ensemble,
  * `fit_NPT_100K_protocol_HALF1.mdp` - config file for half-map refinement in NPT ensemble,
  * `fit_NPT_100K_protocol_FULL.mdp` - config file for final short full-map refinement in NPT ensemble.

* `REF_pdb_ALDO_5vy5_emd_8743.pdb` - deposited reference structure (PDB: 5VY5) preprocessed with `gmx pdb2gmx` in the same way as 6ALD.

* `REF_map_HALF(1,2)_ALDO_emd_8743.ccp4` - half-maps zoned with a 3.5 A radius around the reference structure's atoms in Chimera.

* `REF_map_FULL_ALDO_emd_8743.ccp4` - full-map zoned in the same way.

# Setting up the simulation

This section assumes you have already installed either the GROMACS version from [our homepage](https://www.mpibpc.mpg.de/grubmueller/densityfitting) made sure it supports multithreading, MPI, and CUDA. If you are new to GROMACS, please first read, *e.g.*, the great book chapter by Erik Lindahl: "Molecular dynamics simulations" in Methods in Molecular Biology, 1215: 3-26. The procedure described below also assumes you have some basic Linux knowledge.

1. **Create topology files**

Just run: `./create_top.bash 6ald_fixed.pdb gmx_structure`. This will create all necessary topology files as well as a GROMACS-compatible pre-processed PDB - `gmx_structure.pdb`. The options 1 and 4 in `create_top.bash` mean that the user-specified force field (charmm22star_dev1.3.ff) and the charmm-modified TIP3P water will be used. Please double check if this hold for your GROMACS installation.

2. **Make simulation box triclinic and larger**

Run: `gmx editconf -f gmx_structure.pdb -o gmx_structure_box.pdb -bt triclinic -d 1.0 -center x_c y_c z_c`. GROMACS will redefine the periodic box in the original PDB by making it triclinic (`-bt triclinic`) and larger (`-d 1.0`). The latter option means there will be 1.0 nm solvent padding around the structure. The `-center` option makes sure that the structure does not move during this process as we don't want to change the alignment of our structure with the map. x_c, y_c, and z_c define the center of mass of `gmx_structure.pdb` and can be obtained in different ways. I'd use VMD (don't forget that VMD uses angstroms and GROMACS uses nanometers):

```
vmd gmx_structure.pdb
> set sel [atomselect top all]
> measure center $sel
> quit
```

3. **Fill new box with water**

Run: `gmx solvate -cp gmx_structure_box.pdb -cs spc216.gro -o gmx_structure_wb.pdb -p gmx_structure.top`. This command will fill the box with water molecules and save the solvated structure to `gmx_structure_wb.pdb`.

4. **Add salt ions to the system**

First create an empty config file `empty_file.mdp`. Then run: `gmx grompp -f empty_file.mdp -c gmx_structure_wb.pdb -p gmx_structure.top -o dummy.tpr`. This will create `dummy.tpr` - a dummy tpr file that we'll need to add ions to our solvated system.

Run: `gmx genion -s dummy.tpr -o gmx_structure_150mM.pdb -p gmx_structure.top -pname K -nname CL -conc 0.15 -neutral`. Choose "group SOL" to replace waters with the ions. This command will add 0.15M of KCl ions to neutralize the system and save the neutralized structure to `gmx_structure_150mM.pdb`. We are now good to go.

5. **Steepest-descent energy minimization**

Run: `gmx grompp -f MDP/em.mdp -c gmx_structure_150mM.pdb -p gmx_structure.top -o em.tpr`. Use `em.tpr` to run the minimization. Depending on your GROMACS installation, there are different ways to do it. Here, we assume that we have a GROMACS 5.0.7 installation with multithreading and CUDA support and, say, a 20-core node with 1 GPU.

`mdrun -ntmpi 1 -ntomp 20 -s em.tpr -deffnm em -nb gpu -gpu_id 0 -maxh 3 -append`

All non-bonded calculations are offloaded to the GPU. When using GROMACS 2018, one can additionally offload all PME calculations to the GPU via `-pme gpu`.

6. **Pre-equilibration with position restraints**

Take the minimized structure `em.gro` and run: `gmx grompp -f MDP/pr_pre_NVT_100K.mdp -c em.gro -r em.gro -p gmx_structure.top -o pr_pre_NVT_100K.tpr`. Use `pr_pre_NVT_100K.tpr` to run the pre-equilibration as describe above:

`mdrun -ntmpi 1 -ntomp 20 -s pr_pre_NVT_100K.tpr -deffnm pr_pre_NVT_100K -cpi pr_pre_NVT_100K.cpt -nb gpu -gpu_id 0 -maxh 48 -append`

Note that this simulation will take a longer time to finish, so don't forget to save checkpoint files via `-cpi pr_pre_NVT_100K.cpt`. To continue the simulation just use the same command.

7. **Equilibration without position restraints**

Run: `gmx grompp -f MDP/fit_NPT_100K_eq.mdp -c pr_pre_NVT_100K.gro -p gmx_structure.top -o fit_NPT_100K_eq.tpr`. And then:

`mdrun -ntmpi 1 -ntomp 20 -s fit_NPT_100K_eq.tpr -deffnm fit_NPT_100K_eq -cpi fit_NPT_100K_eq.cpt -nb gpu -gpu_id 0 -maxh 48 -append`

8. **Half-map refinement**

Finally, we use the equilibrated structure `fit_NPT_100K_eq.gro` to run the actual refinement. Prepare the `.tpr` file as follows: `gmx grompp -f MDP/fit_NPT_100K_protocol_HALF1.mdp -c fit_NPT_100K_eq.gro -p gmx_structure.top -o fit_NPT_100K_protocol_HALF1.tpr -mi REF_map_HALF1_ALDO_emd_8743.ccp4`.

Take a look at the config file (mdp). There are three important ranges to specify prior to running the refinement: duration (`densfit-npoints` and `densfit-time`), simulated map resolution (`densfit-sigma`) and force constant (`densfit-k`). The duration depends on the protocol temperature (see Figure 2 -- Supplementary Figure 1 in the paper). Here, I will stick to the longest 50-ns protocol at 100K. As the time counter is set to 5000 ps (`tinit = 5000`), we use `densfit-npoints = 2` and `densfit-time = 8000 52000`. In this setup, the refinement begins at t = 5000 ps and runs at starting k and sigma for 3000 ps, after which both parameters are linearly ramped to the target values (from 8000 ps to 52000 ps), and finally runs at final k and sigma for 3000 ps. `densfit-npoints = 2` basically indicates the number of "kink" points in the protocol.

The starting `densfit-sigma` value is 0.6 nm, which essentially turns every structure into a shapeless blob - this is what we want during the early stage. The final `densfit-sigma` value should correspond to the maximum available from the croy-EM map. Now, it's hard to say what this maximum is. One way to estimate this value is to take a structure that fits the map sufficiently well and cross-correlate both in real-space in, *e.g.*, UCSF Chimera or SPIDER. Typical values would be around 0.2-0.3 nm. Going below 0.2 nm, however, should be avoided because "sharp" similated maps can produce high pulling forces and hence LINCS instabilities.

The starting value for `densfit-k` is also easy to choose. Usually, during the early stage, the fitted structure doesn't need to fit the experimental map well. It is enough if the global map-model alignment is good. Low `densfit-k` values from 10000 to 100000 are usually appropriate. The final value for `densfit-k` depends on the outcome of the cross-validation procedure (Figure 2 -- Supplementary Figure 1). Usually, a target force constant that is 4-8 times larger than the initial one is a good choice, and no overfitting will occur. If you see some overfitting (FSC_train deviates strongly from FSC_val), stop the half-map refinement at a point where no overfitting is happening -- this is going to give you the optimal target force constant -- and proceed to full-map refinement (step 9).

If you are satisfied with the choise of `densfit-k` and `densfit-sigma` run: `mdrun -ntmpi 1 -ntomp 20 -s fit_NPT_100K_protocol_HALF1.tpr -deffnm fit_NPT_100K_protocol_HALF1 -cpi fit_NPT_100K_protocol_HALF1.cpt -nb gpu -gpu_id 0 -maxh 48 -append`. This is the most time consuming part of the refinement. Assuming you have a decent computing node (a new generation Intel CPU + a good consumer-class GPU), this part should take no longer than 2 days.

It is _absolutely crucial_ to cross-validate the refined structure against the other half-map `REF_map_HALF2_ALDO_emd_8743.ccp4` in the sense of FSC and/or other validation criteria (*e.g.* EMRinger) to make sure that the chosen range of force constants is fine. If you notice some overfitting, you can always stop the half-map refinement at a point where it has not yet occured and proceed to the next point.

Check out our `gmx map` tool that has some useful features to generate synthetic maps for FSC analysis. Just run: `gmx map -h` (for help). To create a simulated map from a PDB structure, run: `gmx map -f structure.pdb -mo map.ccp4 -sigma 0.2 -sp 0.091`. Here, `-sigma` is the simulated map resolution in nanometers and `-sp 0.091` is the grid size of the simulated map also in nanometers. **IMPORTANT:** the latter has to exactly match the grid size of the experimental maps.

9. **Full-map refinement**

If everything is fine (you got a half-map-refined structure that does not show any signs of overfitting and you got the optimal target value for `densfit-k`) run the full-map refinement:

`gmx grompp -f MDP/fit_NPT_100K_protocol_FULL.mdp -c fit_NPT_100K_protocol_HALF1.gro -p gmx_structure.top -o fit_NPT_100K_protocol_FULL.tpr -mi REF_map_FULL_ALDO_emd_8743.ccp4`

And then: `mdrun -ntmpi 1 -ntomp 20 -s fit_NPT_100K_protocol_FULL.tpr -deffnm fit_NPT_100K_protocol_FULL -cpi fit_NPT_100K_protocol_FULL.cpt -nb gpu -gpu_id 0 -maxh 48 -append`.

Here, the structure is shortly refined against the full reconstruction (5 ns) to account for high-resolution details not present in the half-maps, which is followed by a simulated annealing step (10 ns). The last 5 ns of this run are also equilibration and can be averaged to a single PDB that will be our final model. To this end, extract the last 5 ns from the trajectory and select only the solute's non-hydrogen files:

`gmx trjconv -f fit_NPT_100K_protocol_FULL.xtc -s fit_NPT_100K_protocol_FULL.tpr -o last_5ns.pdb -pbc mol -ur compact -b 70000`

I'd then use VMD to do the averaging:

```
vmd last_5ns.pdb
> set sel [atomselect top all]
> set pos [measure avpos $sel]
> $sel set {x y z} $pos
> $sel writepdb AVERAGE.pdb
> quit
```

IMPORTANT: Don't forget to remove virtual sites from the average structure every time you perform analysis not related to GROMACS. This can be done easily:

`grep -v "M[CN]" AVERAGE.pdb > AVERAGE_no_v-sites.pdb`

Run: `pymol/chimera/vmd -m REF_map_FULL_ALDO_emd_8743.ccp4 REF_pdb_ALDO_5vy5_emd_8743.pdb AVERAGE_no_v-sites.pdb` to visually inspect the map, the reference structure and the refined model in your favorite viewer.

10. **Geometry assessment**

Some useful metrics (asumming here that you have a working PHENIX installation):

```
phenix.molprobity AVERAGE_no_v-sites.pdb
phenix.cablam_validation AVERAGE_no_v-sites.pdb
phenix.emringer AVERAGE_no_v-sites.pdb REF_map_FULL_ALDO_emd_8743.ccp4
```

FSC curves can be calculated using either PHENIX/SPIDER or [the FSC validation server](https://www.ebi.ac.uk/pdbe/emdb/validation/fsc/).
