# rbpi_remote

### Files in this repo

- phone_home.sh: script to run at boot which, among other features, establishes a tcp connection to a C&C server which the pentester can use to establish an SSH connection with device.
- prep.sh: prep script to install required packages from the repos as well as write config files
- config.sh: contains all the configuration. Is imported at runtime by both prep.sh and phone_home.sh

Check out our associated blogpost "https://www.scip.ch/en/?labs.20190905.4574bd48":https://www.scip.ch/en/?labs.20190905.4574bd48 and the config file config.sh which contains documentation for each option.

---

Copyright (C) 2019  scip AG

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
