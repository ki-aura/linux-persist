Firefox Write-Reduction Notes
=============================

Firefox is the single largest source of persistent overlay writes on
live USB systems. These changes ensure that temporary data stays in RAM
or is not written at all.

To apply:

1. Open Firefox
2. Type: about:config
3. Accept risk prompt

Search and set the following:

browser.cache.disk.enable → false
browser.cache.disk.smart_size.enabled → false

media.cache_size → 0
media.memory_cache_max_size → 65536
media.memory_caches_combined_limit_kb → 65536

browser.sessionstore.interval → 60000
browser.sessionstore.max_tabs_undo → 3
browser.sessionstore.max_windows_undo → 1

(Optional, more aggressive)
browser.sessionstore.restore_on_demand → true

Close the tab when done.

What these do:
--------------
- disables all on-disk cache
- forces memory-only media buffering
- significantly reduces sessionstore writes
- limits how much session metadata Firefox keeps
- prevents write storms while browsing media-heavy websites

Note:
-----
These settings *do not* affect:
- bookmarks
- saved logins
- extensions
- sync

All of those still work normally.

