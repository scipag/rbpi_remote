# rbpi_remote

Raspberry Pi remote access script.

Files in this repo:
phone_home.sh: script to run at boot which, among other features, establishes a tcp connection to a C&C server which the pentester can use to establish an SSH connection with device.
prep.sh: prep script to install required packages from the repos as well as write config files
config.sh: contains all the configuration. Is imported at runtime by both prep.sh and phone_home.sh

Check out our associated blogpost "https://www.scip.ch/en/?labs.20190905.4574bd48":https://www.scip.ch/en/?labs.20190905.4574bd48 and the config file config.sh which contains documentation for each option.
