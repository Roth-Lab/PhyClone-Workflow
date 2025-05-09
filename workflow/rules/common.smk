from pathlib import Path
import re


class ConfigManager(object):
    __slots__ = (
        "out_dir",
        "config",
        "input_dir",
        "log_dir",
        "snakefile_logdir",
        "benchmarks_dir",
    )

    def __init__(self, config):
        self.config = config
        sanitised_exp_name = self.sanitise_expname(config["experiment_name"])
        self.out_dir = Path("results").joinpath(sanitised_exp_name)
        self.log_dir = self.out_dir.joinpath("logs")
        self.benchmarks_dir = self.out_dir.joinpath("benchmarks")
        self.out_dir = self.out_dir.joinpath("pipeline_outputs")
        self.input_dir = self.out_dir.joinpath("input")
        self.snakefile_logdir = self.log_dir.joinpath("main_snakefile_logs")

    @staticmethod
    def sanitise_expname(raw_experiment_name):
        sanitised_exp_name = re.sub(r'[<>:"/\\|?*]', '', raw_experiment_name)
        sanitised_exp_name = sanitised_exp_name.strip()
        sanitised_exp_name = sanitised_exp_name.replace(' ', '_')
        return sanitised_exp_name

    def get_program_config(self, prog):
        return self.config.get(prog, {})

    def get_prog_out_dir(self, prog):
        return self.out_dir.joinpath(prog)


class ProgFileManager(object):
    __slots__ = (
        "cfg_mgr",
        "prog_config",
        "run_dir",
        "prog_log_dir",
        "version_file",
        "prog_benchmarks_dir",
    )

    def __init__(self, config_mgr, prog_name):
        self.cfg_mgr = config_mgr
        self.prog_config = config_mgr.get_program_config(prog_name)
        self.run_dir = Path(config_mgr.get_prog_out_dir(prog_name))
        self.prog_log_dir = self.get_prog_log_dir(prog_name)
        self.version_file = self.run_dir.joinpath("{}.version.txt".format(prog_name))
        self.prog_benchmarks_dir = self.cfg_mgr.benchmarks_dir.joinpath(prog_name)

    def get_output_file_path(self, file_name):
        return self.run_dir.joinpath(file_name)

    def get_prog_log_dir(self, prog_name):
        return self.cfg_mgr.log_dir.joinpath("{}_logs".format(prog_name))

    def get_seed(self):
        seed = self.prog_config.get("seed", None)
        if seed:
            return "--seed {}".format(seed)
        else:
            return ""


class PhyCloneFileManager(ProgFileManager):
    __slots__ = (
        "processed_tree_file",
        "table_file",
        "trace_file",
        "tree_newick_file",
        "topology_report",
        "topology_archive",
        "run_stats_file",
        "write_stats_file",
        "phyclone_stats_file",
        "map_newick",
        "map_table",
        "consensus_newick",
        "consensus_table",
        "output_props",
        "map_opts",
        "consensus_opts",
        "topology_report_opts",
    )

    def __init__(self, config_mgr, prog_name):
        super().__init__(config_mgr, prog_name)

        self.trace_file = self.get_output_file_path("trace.pkl.gz")
        self.tree_newick_file = "tree.nwk"
        self.table_file = "results_table.tsv.gz"
        map_folder = "MAP"
        consensus_folder = "Consensus"
        topology_report_folder = "Topology_Report"

        self.topology_report = self.get_phyclone_result_filepath(topology_report_folder, "topology_report.tsv.gz")
        self.topology_archive = self.get_phyclone_result_filepath(topology_report_folder, "sampled_topologies.tar.gz")

        self.map_newick = self.get_phyclone_result_filepath(map_folder, self.tree_newick_file)
        self.map_table = self.get_phyclone_result_filepath(map_folder, self.table_file)

        self.consensus_newick = self.get_phyclone_result_filepath(consensus_folder, self.tree_newick_file)
        self.consensus_table = self.get_phyclone_result_filepath(consensus_folder, self.table_file)

        self.run_stats_file = self.get_output_file_path("run_stats.txt")

        self.phyclone_stats_file = self.get_output_file_path("stats.tsv")

        self.output_props = self.prog_config.get("output_options", {})

        self.map_opts = self.output_props.get("map", {})
        self.consensus_opts = self.output_props.get("consensus", {})
        self.topology_report_opts = self.output_props.get("topology_report", {})

    def get_phyclone_result_filepath(self, output_type, file_name):
        return self.run_dir.joinpath("tree_outputs", output_type, file_name)

    def make_topology_archive(self):
        return self.topology_report_opts.get("make_topology_archive", False)

    def get_num_trees_in_topology_archive(self):
        top_trees = self.topology_report_opts.get("number_of_top_trees", -1)
        if top_trees == -1:
            return ""
        else:
            return "--top-trees {}".format(top_trees)

    def get_outlier_options(self):
        if not self.prog_config.get("enable_outlier_modelling", True):
            return "-l {}".format(0.0)
        else:
            outlier_modelling_options = self.prog_config.get("outlier_modelling_options", {})
            outlier_opts = "-l {}".format(outlier_modelling_options.get("outlier_prob", 0.0001))
            if outlier_modelling_options.get("assign_loss_prob", True):
                outlier_opts += " --assign-loss-prob"
                outlier_opts += " --high-loss-prob {}".format(outlier_modelling_options.get("high_loss_prob", 0.4))
                outlier_opts += " --low-loss-prob {}".format(outlier_modelling_options.get("low_loss_prob", 0.0001))
            return outlier_opts

    def get_phyclone_outputs(self):
        output_props = self.prog_config.get("output_options", {})

        output_files = []

        for output_type, options in output_props.items():
            if output_type == "map":
                if options["make_map_tree"]:
                    output_files.append(self.map_newick)
                    output_files.append(self.map_table)
            elif output_type == "consensus":
                if options["make_consensus_tree"]:
                    output_files.append(self.consensus_newick)
                    output_files.append(self.consensus_table)
            elif output_type == "topology_report":
                if options["make_topology_report"]:
                    output_files.append(self.topology_report)
                    if options["make_topology_archive"]:
                        output_files.append(self.topology_archive)
            else:
                raise NotImplemented("Tree output type {} is invalid.".format(output_type))

        if len(output_files) == 0:
            print("WARNING: No PhyClone final output tree(s) being made")

        return output_files


class PyCloneFileManager(ProgFileManager):
    __slots__ = (
        "stats_file",
        "trace_file",
        "clusters_file",
    )

    def __init__(self, config_mgr, prog_name):
        super().__init__(config_mgr, prog_name)
        self.trace_file = self.get_output_file_path("trace.h5")
        self.stats_file = self.get_output_file_path("stats.txt")
        self.clusters_file = self.get_output_file_path("clusters.tsv.gz")
