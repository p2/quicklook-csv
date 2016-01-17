A QuickLook Plugin for CSV Files
================================

Quick look **CSV files** for Mac OS X 10.5 and newer.
Supports files separated by comma (`,`), tabs (`⇥`), semicolons (`;`) pipes (`|`).
The plugin will generate Icons and show a preview, along with some information (like num rows/columns).
Many thanks to Ted Fischer for valuable input and testing of version 1.1!

Installation
------------

In order to use this Plugin, download [QuickLookCSV.dmg][dmg], open it by double-clicking and in there you will find the actual Plugin named **QuickLookCSV.qlgenerator**.

Place the Plugin into `~/Library/QuickLook/` to install it for yourself only, or into `(Macintosh HD)/Library/QuickLook/` to install it for all users of your Mac.
If the QuickLook-folder does not exist, simply create it manually.
There are aliases to these directories in the disk image you have just downloaded, so you might be able to just drag the plugin onto one of the two aliases to install.

Contributing
------------

If you're interested in contributing, fork the repo and send me a pull request via [GitHub][].

File Maker TSV Files
--------------------

Some hacks were made in earlier versions to support FileMaker tab-separated-value files.
Those hacks have been removed in Version 1.3.
If this means your files no longer preview correctly, [download version 1.2][1.2] again, but please [let me know][issues].


Screenshots
-----------

![Icons](http://pp.hillrippers.ch/blog/2009/07/05/QuickLook%20Plugin%20for%20CSV%20files/Icons.png)
![Preview](http://pp.hillrippers.ch/blog/2009/07/05/QuickLook%20Plugin%20for%20CSV%20files/Preview_2.png)

[dmg]: https://github.com/p2/quicklook-csv/releases/download/1.3/QuickLookCSV-1.3.dmg
[github]: https://github.com/p2/quicklook-csv
[issues]: https://github.com/p2/quicklook-csv/issues
[1.2]: https://github.com/p2/quicklook-csv/releases/tag/1.2
