# ExportStaffMP3s

This plugin helps to export all the staffs individually, but can leave all the other staffs more quietly in the background.

## Current features
- Export also non pitched staffs
- Export other staffs but quieter
- How quiet to export other staffs

After clicking the export button, the whole score is exported as an MP3 with all staffs enabled and saved to a file with suffix `-all.mp3`. Then for all staffs separately, an individual MP3 is generated and saved with a suffix containing the instruments name (the long name).

The first checkbox specifies if we want to include non pitched staffs or do not want to generate the individual MP3 for those.

The second checkbox specifies what is included in the individual MP3s. If unchecked, only the individual staffs will be heared. If checked, a slider will appear to set a silencing factor from -127 (quiet) to 0 (no change). This factor is used to still allow all the instruments to be heared in the individual files, but silenced by that amount. This is done using the velocity value of each note up to this point.

## Installation
[Download](https://github.com/simonstuder/ExportNumbersNLetters/archive/main.zip) the zip file and install according to the default MuseScore [Plugin Installation](https://musescore.org/en/handbook/3/plugins#installation) method

## Translations
The languages this is available in are English and German. For others I would accept help with translation if wanted.

