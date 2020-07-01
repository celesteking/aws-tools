#### Installation

`bundle install` in this dir.

#### AWS Route53 Zone deletion

Handled by `route53-delete-zones` script.

Script expects the list of domains (separated by newlines) on input (stdin):

```
# SAFE to run
bundle exec route53-delete-zones.rb < /tmp/zonelist.txt
```

Once you're satisfied with the lookup results, run it for real by supplying `--doit` option. Without that option the script is safe to run and will try to find the zone, list found zone IDs and retrieve RRs for respective zone IDs.

`--stop-on-error` might be supplied in order for the script to stop on first error

`--help` will list available options.

Script will exit with `0` status on success and with non-`0` if at least 1 error occurred during zone deletion process.