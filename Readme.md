#### Installation

`bundle install` in this dir.

Be sure to have your AWS environment ready to go. We use AWS Ruby SDK in scripts but provide no cmdline options to configure it, thus you have to have it ready via ENV vars. 
Usually, properly configuring `~/.aws/credentials` and setting `export AWS_PROFILE=my_profile` is enough to get it going. 
If you happen to use `aws` standard command suggested by AWS docs to do your AWS management woes, you're pretty much already configured.

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