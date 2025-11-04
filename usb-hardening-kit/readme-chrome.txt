Google Chrome / Chromium Write-Reduction Notes
==============================================

Chrome/Chromium also generates high write volume by default. These
settings prevent most persistent writes.

To configure (Chromium or Google Chrome):

1. Launch Chrome/Chromium
2. Visit: chrome://settings/cookies
   → Disable/prevent "Preload pages for faster browsing" (privacy → tracking)
     (preloading aggressively caches to disk)

3. Visit: chrome://settings/system
   → Disable "Continue running background apps when Chrome is closed"

4. Visit: chrome://settings/performance
   → Disable "Memory Saver" logs (optional)
   → Enable "Energy Saver" if desired (no storage impact)

Flags (Advanced):
-----------------
Visit: chrome://flags

Search and set:

Disk cache size → 0
Stream media in service → Disabled
Enable new filesystem-based cache → Disabled

Optional:
Zero-copy rasterizer → Enabled (reduces GPU cache writes)

Then reboot Chrome.

Command-Line (Recommended on live USB):
---------------------------------------
You can launch Chrome with the following flags:

google-chrome --disk-cache-size=0 --media-cache-size=0 --disable-background-networking --disable-component-update --disable-crash-reporter --disable-logging --no-default-browser-check

Chromium equivalent:

chromium --disk-cache-size=0 --media-cache-size=0 --disable-background-networking --disable-component-update --disable-crash-reporter --disable-logging --no-default-browser-check

These flags:
------------
- disable disk caching
- suppress crash logging
- disable background tasks
- prevent update pings from generating telemetry writes

What will still persist:
------------------------
- bookmarks
- saved logins
- extensions (changes infrequent)
- cookies

These are tiny and acceptable on persistent media.

For the most write-sensitive setups:
------------------------------------
You may optionally move Chrome’s profile directory to tmpfs.
(Use only if you do NOT need persistent bookmarks.)

mkdir -p /tmp/chrome-profile
google-chrome --user-data-dir=/tmp/chrome-profile

This stores *everything* in RAM, including history, extensions, and logins.
All data is lost on reboot by design.

