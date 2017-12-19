# Free tubulin simulation

Source files necessary to start a free GTP-tubulin simulation using CHARMM22* force field and GROMACS 4.6. The force field was modified to include GTP/GDP parameters adapted from CHARMM27.

# Overview of files

- charmm22star_dev1.2.ff.tar.gz - modified CHARMM22* force field

- input_1_preparation/3jat_chainABQX_GMPCPP.pdb - starting structure

- input_1_preparation/create_top_CP_prep.bash - bash script to create topology files

- input_1_preparation/em.mdp - config file for initial energy minimization

- input_1_preparation/pr_pre_NVT_100K.mdp - config file for subsequent equilibration with position restraints in NVT ensemble

- input_1_preparation/heating_NPT_100K-300K - config files for step-wise heating from 100K to 300K in NPT ensemble

- input_2_production/
