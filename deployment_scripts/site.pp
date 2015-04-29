$fuel_settings = parseyaml($astute_settings_yaml)
if $fuel_settings {
  class {'plugin_cinder_eqlx':}
}
else {
  notify {'Empty fuel_settings, plugin deployment canceled.':}
}
