# Syscoin Scripts

This is a collection of scripts that make life around syscoin masternodes a little bit more convenient.

## Scripts

### mnKeepUp

This script will keep a number of masternodes running and restart them if necessary. Setup instructions can be found inside.


### get-syscoin-binaries

This script fetches syscoin release binaries from github and installs them into /usr/local/bin. It will ask you for the release version you want to install. It will also ask you for your password, as it needs root privileges to write to /usr/local/bin. 
You can run it right from the repository like this:

`bash <(curl -sL https://raw.githubusercontent.com/einalex/syscoin-scripts/master/get-syscoin-binaries)`

### update-syscoin-manual-installation

This script updates your manual masternode installation (if you installed via the initial manual guide) to a release version of your choice. This requires that you run it as the same user, that you used to install in the first place, and that runs syscoind. It will ask you for the release version you want to install. 
You can run it fright from the repository like this:

`bash <(curl -sL https://raw.githubusercontent.com/einalex/syscoin-scripts/master/update-syscoin-manual-installation)`

## Tips
If you find some of this useful and want to leave a tip: sys1qwdy4clmdr6tgjvk7fugcdg2d46k52xaqzysm3f
