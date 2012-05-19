dropbox-for-zaurus
==================

Dropbox client for sl-zaurus using ruby API.
Zaurus is linux PDA made by sharp.

Usage
-----
Usage: d4z [options]
    -i                               Interructive mode
    -d                               Download only(from server to local)
    -u                               Upload only(from local to server)
    -s                               Syncronus(upload and download)
    -h, --help                       Show this message
    -v, --version                    Show version

Configuration files
-------------------
d4z_keys.rb

# Get APP_KEY and APP_SECRET pair from Dropbox developper site.
APP_KEY = 'xxxxxxxxxxxx'
APP_SECRET = 'xxxxxxxxxx'

# Get ACCESS_TOKEN and ACCESS_SECRET pair from authorize_url.
# d4z -i to interructive mode and type 'login' command then you will get authorize_url.
ACCESS_TOKEN = 'xxxxxxxxxxxxx'
ACCESS_SECRET = 'xxxxxxxxxxxxx'

# Syncing directory
# This directory is same to the directory which is defined in Dropbox developper site.
APP_DIRECTORY = File.expand_path("/home/zausur/Dropbox/App/d4z_test/")


Files
-----
README.md    This file.
d4z.rb       Main script file.
d4z.json     Cache file of server information.
dropbox_sdk.rb   Dropbox sdk downloaded from https://www.dropbox.com/developers
sync.sh
dropbox_opie.sh
dropbox.desktop
