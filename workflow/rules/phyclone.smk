
rule run_phyclone:
    input:
        data_file=rules.correct_input.output.corrected,
        clusters_file=rules.write_results_pyclone_vi.output.clusters_file,
    output:
        trace=report(
            phyc_file_mgr.trace_file,
            category="PhyClone",
            subcategory="Sample Trace",
            labels={"Type": "PhyClone Sample Trace"},
        ),
    params:
        b=phyc_file_mgr.prog_config["burnin"],
        d=phyc_file_mgr.prog_config["density"],
        n=phyc_file_mgr.prog_config["num_iters"],
        p=phyc_file_mgr.prog_config["proposal"],
        print=phyc_file_mgr.prog_config["print_freq"],
        seed=phyc_file_mgr.get_seed(),
        time=phyc_file_mgr.prog_config.get("time", ""),
        grid_size=phyc_file_mgr.prog_config["grid_size"],
        num_particles=phyc_file_mgr.prog_config["num_particles"],
        precision=phyc_file_mgr.prog_config["precision"],
        concentration_value=phyc_file_mgr.prog_config["concentration_value"],
        outlier_opts=phyc_file_mgr.get_outlier_options(),
    benchmark:
        phyc_file_mgr.prog_benchmarks_dir.joinpath("run_phyclone.benchmark.txt")
    log:
        stdout=phyc_file_mgr.prog_log_dir.joinpath("run_phyclone.stdout.log"),
        stderr=phyc_file_mgr.prog_log_dir.joinpath("run_phyclone.stderr.log"),
    conda:
        "../envs/phyclone.yaml"
    threads: phyc_file_mgr.prog_config.get("num_chains", 1)
    group:
        "PhyClone-Run"
    shell:
        """
        phyclone run \
        -i {input.data_file} \
        --cluster-file {input.clusters_file} \
        --out-file {output.trace} \
        --burnin {params.b} \
        --density {params.d} \
        --num-iters {params.n} \
        --proposal {params.p} \
        {params.outlier_opts} \
        --grid-size {params.grid_size} \
        --print-freq {params.print} \
        {params.seed} \
        --num-chains {threads} \
        --num-particles {params.num_particles} \
        --precision {params.precision} \
        --concentration-value {params.concentration_value} \
        {params.time} > {log.stdout} 2> {log.stderr}
        """


rule write_map_results_phyclone:
    input:
        trace=rules.run_phyclone.output.trace,
    output:
        results_table=report(
            phyc_file_mgr.map_table,
            category="PhyClone",
            subcategory="Trees",
            labels={"Estimate": "MAP", "Type": "Results table"},
        ),
        newick_file=report(
            phyc_file_mgr.map_newick,
            category="PhyClone",
            subcategory="Trees",
            labels={"Estimate": "MAP", "Type": "Newick tree"},
        ),
    benchmark:
        phyc_file_mgr.prog_benchmarks_dir.joinpath("write_map_results_phyclone.benchmark.txt")
    log:
        stdout=phyc_file_mgr.prog_log_dir.joinpath("write_map_results_phyclone.stdout.log"),
        stderr=phyc_file_mgr.prog_log_dir.joinpath("write_map_results_phyclone.stderr.log"),
    conda:
        "../envs/phyclone.yaml"
    params:
        map_type=phyc_file_mgr.output_props.get("map", {}).get("map_type", "joint-likelihood"),
    group:
        "PhyClone-Write-Output"
    shell:
        """
        phyclone map -i {input.trace} \
        -o {output.results_table} \
        -t {output.newick_file} \
        --map-type {params.map_type} > {log.stdout} 2> {log.stderr}
        """


rule write_consensus_results_phyclone:
    input:
        trace=rules.run_phyclone.output.trace,
    output:
        results_table=report(
            phyc_file_mgr.consensus_table,
            category="PhyClone",
            subcategory="Trees",
            labels={"Estimate": "Consensus", "Type": "Results table"},
        ),
        newick_file=report(
            phyc_file_mgr.consensus_newick,
            category="PhyClone",
            subcategory="Trees",
            labels={"Estimate": "Consensus", "Type": "Newick tree"},
        ),
    benchmark:
        phyc_file_mgr.prog_benchmarks_dir.joinpath("write_consensus_results_phyclone.benchmark.txt")
    log:
        stdout=phyc_file_mgr.prog_log_dir.joinpath("write_consensus_results_phyclone.stdout.log"),
        stderr=phyc_file_mgr.prog_log_dir.joinpath("write_consensus_results_phyclone.stderr.log"),
    params:
        consensus_threshold=phyc_file_mgr.output_props.get("consensus", {}).get('consensus_threshold', 0.5),
        weight_type=phyc_file_mgr.output_props.get("consensus", {}).get('weight_type', "joint-likelihood"),
    conda:
        "../envs/phyclone.yaml"
    group:
        "PhyClone-Write-Output"
    shell:
        """
        phyclone consensus -i {input.trace} \
        -o {output.results_table} \
        -t {output.newick_file} \
        --consensus-threshold {params.consensus_threshold} \
        --weight-type {params.weight_type} > {log.stdout} 2> {log.stderr}
        """


rule get_phyclone_version:
    output:
        file=report(
            phyc_file_mgr.version_file,
            category="PhyClone",
            subcategory="Version",
            labels={"Type": "PhyClone version used to run analysis."},
        ),
    log:
        phyc_file_mgr.prog_log_dir.joinpath("get_phyclone_version.log"),
    conda:
        "../envs/phyclone.yaml"
    group:
        "PhyClone-Run"
    shell:
        "phyclone --version > {output.file} 2> {log}"


if phyc_file_mgr.make_topology_archive:

    rule write_phyclone_topology_archive_and_report:
        input:
            trace=rules.run_phyclone.output.trace,
        output:
            report=report(
                phyc_file_mgr.topology_report,
                category="PhyClone",
                subcategory="Trees",
                labels={"Estimate": "All Unique Topologies", "Type": "Topology Report Table"},
            ),
            archive=report(
                phyc_file_mgr.topology_archive,
                category="PhyClone",
                subcategory="Trees",
                labels={"Estimate": "All Unique Topologies", "Type": "Sampled Topologies Archive"},
            ),
        benchmark:
            phyc_file_mgr.prog_benchmarks_dir.joinpath("write_phyclone_topology_archive_and_report.benchmark.txt")
        log:
            stdout=phyc_file_mgr.prog_log_dir.joinpath("write_phyclone_topology_archive_and_report.stdout.log"),
            stderr=phyc_file_mgr.prog_log_dir.joinpath("write_phyclone_topology_archive_and_report.stderr.log"),
        params:
            top_trees=phyc_file_mgr.get_num_trees_in_topology_archive(),
        conda:
            "../envs/phyclone.yaml"
        group:
            "PhyClone-Write-Output"
        shell:
            """
            phyclone topology-report -i {input.trace} \
            -o {output.report} \
            -t {output.archive} \
            {params.top_trees} > {log.stdout} 2> {log.stderr}
            """

else:

    rule write_phyclone_topology_report:
        input:
            trace=rules.run_phyclone.output.trace,
        output:
            report=report(
                phyc_file_mgr.topology_report,
                category="PhyClone",
                subcategory="Trees",
                labels={"Estimate": "All Unique Topologies", "Type": "Topology Report Table"},
            ),
        benchmark:
            phyc_file_mgr.prog_benchmarks_dir.joinpath("write_phyclone_topology_report.benchmark.txt")
        log:
            stdout=phyc_file_mgr.prog_log_dir.joinpath("write_phyclone_topology_report.stdout.log"),
            stderr=phyc_file_mgr.prog_log_dir.joinpath("write_phyclone_topology_report.stderr.log"),
        conda:
            "../envs/phyclone.yaml"
        group:
            "PhyClone-Write-Output"
        shell:
            """phyclone topology-report -i {input.trace} -o {output.report} > {log.stdout} 2> {log.stderr}"""
