#!/bin/bash

if [ $# -ne 3 -a $# -ne 5 -a $# -ne 6 ]; then
  echo "Usage: $0 host-file plugin_home micromamba_env_name [prep iso-date [iso-end-date]]"
  echo "$0 $PWD/envs/ATOS-Bologna $PWD surfExp true 2025-01-01T00:00:00Z 2025-01-02T00:00:00Z"
  exit 1
else
  echo
  echo "##################################################################" 
  date
  echo "##################################################################" 
  echo

  host_file=$1
  [ ! -f $host_file ] && echo "No $host file found" && exit 1
  . $host_file

  plugin_home=$2
  micromamba_env_name=$3
  do_prep="false"
  [ $# -gt 3 ] && do_prep="$4"
  if [ $# -gt 4 ]; then
    start_time=$5
  else
    start_time=`date -d "today" '+%Y-%m-%d'`"T00:00:00Z"
  fi
  end_time=$start_time
  if [ $# -gt 5 ]; then
    end_time=$6
  fi
fi

# Experiment
exp="CY49DT_OFFLINE_dt_2_5_2500x2500"

# Platform specific variables
[ "$scratch" == "" ] && echo "scratch not set!" && exit 1
[ "$binaries_opt" == "" ] && echo "binaries_opt not set!" && exit 1
[ "$binaries_de" == "" ] && echo "binaries_de not set!" && exit 1
[ "$micromamba_path" == "" ] && echo "micromamba_path not set!" && exit 1

# Experiment specific
config="dt_offline_dt_2_5_2500x2500_running.toml"
domain="surfexp/data/config/domains/dt_2_5_2500x2500.toml"

# Micromamba
export PATH=${micromamba_path}/bin/:$PATH
export MAMBA_ROOT_PREFIX=${micromamba_path}  # optional, defaults to ~/micromamba
eval "$(micromamba shell hook -s posix)"

micromamba activate $micromamba_env_name || exit 1

set -x
cd $plugin_home

# Clean
$plugin_home/bin/clean.sh "$scratch/$exp"

mods="mods_run.toml"
cat > $mods << EOF
[general]
  max_tasks = 60

[general.times]
  start = "$start_time"
  end = "$end_time"


[scheduler.ecfvars]
  ecf_files = "/perm/@USER@/deode_ecflow/ecf_files"
  ecf_files_remotely = "/perm/@USER@/deode_ecflow/ecf_files"
  ecf_home = "/perm/@USER@/deode_ecflow/jobout"
  ecf_jobout = "/perm/@USER@/deode_ecflow/jobout"
  ecf_out = "/perm/@USER@/deode_ecflow/jobout"

[suite_control]
  create_static_data = false
  create_time_dependent_suite = true
  do_archiving = true
  do_cleaning = true
  do_extractsqlite = true
  do_marsprep = true
  do_pgd = false
  do_PrefetchMars = true
  do_prep = $do_prep

[submission]
  bindir = "$binaries_de"
[submission.task_exceptions.Forecast]
  bindir = "$binaries_de"
[submission.task_exceptions.Pgd]
  bindir = "$binaries_de"
[submission.task_exceptions.Prep]
  bindir = "$binaries_opt"
[submission.task_exceptions.QualityControl.MODULES]
  PRGENV = ["load", "prgenv/gnu"]

EOF

surfExp -o $config \
--case-name $exp \
--plugin-home $plugin_home  \
--troika troika \
surfexp/data/config/configurations/dt.toml \
surfexp/data/config/domains/dt_2_5_2500x2500.toml \
surfexp/data/config/mods/dev-CY49T2h_deode/dt.toml \
surfexp/data/config/mods/dev-CY49T2h_deode/dt_prep_from_namelist.toml \
$mods \
--start-time $start_time \
--end-time $end_time

time deode start suite --config-file $config || exit 1

