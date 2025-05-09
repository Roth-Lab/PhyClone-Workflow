
rule run_pyclone_vi:
    input:
        data_file=rules.correct_input.output.corrected,
    output:
        trace=pyvi_file_mgr.trace_file,
    benchmark:
        pyvi_file_mgr.prog_benchmarks_dir.joinpath("run_pyclone_vi.benchmark.txt")
    log:
        stdout=pyvi_file_mgr.prog_log_dir.joinpath("run_pyclone_vi.stdout.log"),
        stderr=pyvi_file_mgr.prog_log_dir.joinpath("run_pyclone_vi.stderr.log"),
    conda:
        "../envs/pyclone-vi.yaml"
    threads: pyvi_file_mgr.prog_config.get("num_threads", 1)
    params:
        num_clusters=pyvi_file_mgr.prog_config["num_clusters"],
        density=pyvi_file_mgr.prog_config["density"],
        restarts=pyvi_file_mgr.prog_config["restarts"],
        weight_prior=pyvi_file_mgr.prog_config["mix_weight_prior"],
        grid_size=pyvi_file_mgr.prog_config["num_grid_points"],
        print=pyvi_file_mgr.prog_config["print_freq"],
        max_iters=pyvi_file_mgr.prog_config["max_iters"],
        precision=pyvi_file_mgr.prog_config["precision"],
        seed=pyvi_file_mgr.get_seed(),
    group:
        "PyClone-VI-Run"
    shell:
        """
        pyclone-vi fit \
        -i {input.data_file} \
        -o {output.trace} \
        --num-clusters {params.num_clusters} \
        --density {params.density} \
        --num-restarts {params.restarts} \
        --num-grid-points {params.grid_size} \
        --mix-weight-prior {params.weight_prior} \
        --num-threads {threads} \
        --max-iters {params.max_iters} \
        --precision {params.precision} \
        {params.seed} \
        --print-freq {params.print} > {log.stdout} 2> {log.stderr}
        """


rule write_results_pyclone_vi:
    input:
        trace=rules.run_pyclone_vi.output.trace,
    output:
        clusters_file=report(
            pyvi_file_mgr.clusters_file,
            category="PyClone-VI",
            labels={"Type": "PyClone-VI clusters."},
        ),
    benchmark:
        pyvi_file_mgr.prog_benchmarks_dir.joinpath("write_results_pyclone_vi.benchmark.txt")
    log:
        stdout=pyvi_file_mgr.prog_log_dir.joinpath("write_results_pyclone_vi.stdout.log"),
        stderr=pyvi_file_mgr.prog_log_dir.joinpath("write_results_pyclone_vi.stderr.log"),
    conda:
        "../envs/pyclone-vi.yaml"
    group:
        "PyClone-VI-Run"
    shell:
        "pyclone-vi write-results-file -i {input.trace} -o {output.clusters_file} -c > {log.stdout} 2> {log.stderr}"


rule get_pyclone_version:
    output:
        file=report(
            pyvi_file_mgr.version_file,
            category="PyClone-VI",
            labels={"Type": "PyClone-VI version used to run analysis."},
        ),
    log:
        pyvi_file_mgr.prog_log_dir.joinpath("get_pyclone_version.log"),
    conda:
        "../envs/pyclone-vi.yaml"
    group:
        "PyClone-VI-Run"
    shell:
        "pyclone-vi --version > {output.file} 2> {log}"
