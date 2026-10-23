## Test environments

* local Linux, R 4.6.1

## R CMD check results

0 errors | 0 warnings | 0 notes

## Comments

This is the first CRAN submission of `gpsadb`.

All queries go to the public GPSAdb endpoint
(<https://gpsadb.gzdlab.com/mcp>); no registration or API key is required. Like
any client for an online resource it needs network access at run time, so
examples are wrapped in `if (interactive())` and the live tests are skipped on
CRAN. The unit tests exercise the whole package offline by injecting a fake MCP
client, so the suite has no network dependency.

Data license: CC BY 4.0. Package license: MIT.
