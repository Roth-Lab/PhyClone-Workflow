The result of pre-processing the raw input file to remove variants affected by one (or more) of the following:
    * Have a major copy number of 0
    * Have a mutation_id that has been duplicated in a sample
    * Are not present in all samples

For a file containing the variants that were removed please see: {{ snakemake.output["filtered"] }}_