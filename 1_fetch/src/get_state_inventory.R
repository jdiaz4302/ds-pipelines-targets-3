get_state_inventory <- function(sites_info, state) {
  site_info <- dplyr::filter(sites_info, state_cd == state)
}
