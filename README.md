# FxA Firefox Launcher


This script supports launching Firefox and pointing it at a specific testing environment.

This repo assumes you have Firefox nightly installed. To run, simply specify the environment you
want to target.

- To point nightly at your local stack run `./launcher`
- To point nightly at stage run `./laucher.sh stage`
- To point nightly at prod run `./laucher.sh prod`


You can optionally override the default Firefox nightly binary by specifying 
a location using the `FIREFOX_BIN` env. e.g.

`FIREFOX_BIN=~/firefox/obj-aarch64-apple-darwin25.4.0/dist/Nightly.app/Contents/MacOS/firefox ./launcher.sh stage`
