# fxa-firefox-launcher


This repo assumes you have firefox nightly installed.

- To point nightly at your local stack run `./launcher`
- To point nightly at stage run `./laucher.sh stage`
- To point nightly at prod run `./laucher.sh prod`


You can override the default firefox nightly binary by specifying 
a location using FXA_ENV. e.g.

`FIREFOX_BIN=~/firefox/obj-aarch64-apple-darwin25.4.0/dist/Nightly.app/Contents/MacOS/firefox ./launcher.sh stage`
