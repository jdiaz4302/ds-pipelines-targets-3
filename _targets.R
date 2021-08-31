
library(targets)
library(tarchetypes)
library(tibble)
options(tidyverse.quiet = TRUE)
library(tidyverse)

tar_option_set(packages = c("tidyverse", "dataRetrieval", "urbnmapr",
                            "rnaturalearth", "cowplot", "lubridate",
                            "leaflet", "leafpop", "htmlwidgets"))

# Load functions needed by targets below
source("1_fetch/src/find_oldest_sites.R")
source("1_fetch/src/get_site_data.R")
source("2_process/src/tally_site_obs.R")
source("2_process/src/summarize_targets.R")
source("3_visualize/src/map_sites.R")
source("3_visualize/src/plot_data_coverage.R")
source("3_visualize/src/plot_site_data.R")
source("3_visualize/src/map_timeseries.R")

# Configuration
states <- c('WI','MN','MI','IL','IN','IA','OH')
parameter <- c('00060')

mapped_by_state_targets <- tar_map(
  tibble(state_abb = states) %>%
    mutate(state_plot_files = sprintf("3_visualize/out/timeseries_%s.png", state_abb)),
  tar_target(nwis_inventory, dplyr::filter(oldest_active_sites,
                                           state_cd == state_abb)),
  tar_target(nwis_data, get_site_data(nwis_inventory, state_abb, parameter)),
  # Insert step for tallying data here
  tar_target(tally, tally_site_obs(nwis_data)),
  # Insert step for plotting data here
  tar_target(timeseries_png,
             plot_site_data(state_plot_files,
                            nwis_data,
                            parameter),
             format = 'file'),
  names = state_abb,
  unlist = FALSE
)

# Targets
list(
  # Identify oldest sites
  tar_target(oldest_active_sites, find_oldest_sites(states, parameter)),
  # Reference/define the split targets
  mapped_by_state_targets,
  # Combine the split targets tallies
  tar_combine(
    obs_tallies,
    mapped_by_state_targets$tally,
    command = combine_obs_tallies(!!!.x)),
  # Combine the split targets time series
  tar_combine(
    summary_state_timeseries_csv,
    mapped_by_state_targets$timeseries_png,
    command = summarize_targets('3_visualize/log/summary_state_timeseries.csv', !!!.x),
    format="file"
  ),
  # Create coverage plot for the combined tallies
  tar_target(data_coverage_png,
             plot_data_coverage(obs_tallies,
                                '3_visualize/out/data_coverage.png',
                                parameter),
             format = 'file'),

  # Map oldest sites
  tar_target(
    site_map_png,
    map_sites("3_visualize/out/site_map.png", oldest_active_sites),
    format = "file"
  ),
  # Map the time series interactively
  tar_target(
    timeseries_map_html,
    map_timeseries(
      oldest_active_sites,
      summary_state_timeseries_csv,
      out_file = '3_visualize/out/timeseries_map.html'),
    format = "file"
  )
)
