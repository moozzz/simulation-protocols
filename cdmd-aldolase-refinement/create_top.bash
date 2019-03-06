#!/usr/bin/env bash

filename="$1"
output_prefix="$2"

gmx pdb2gmx -f ${filename} -o ${output_prefix}.pdb -p ${output_prefix}.top -i ${output_prefix}.itp -vsite hydrogens << EOF
1
4
EOF
