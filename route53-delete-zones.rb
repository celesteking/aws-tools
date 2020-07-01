#!/usr/bin/env ruby

require 'optparse'
require 'logger'
require 'aws-sdk-route53'

Version = '0.2'

@options = { dry_run: true }
@logger = Logger.new($stderr)

# -----------------------------------------------------------------------------
class HostedZones
  include Enumerable
  attr_reader :name

  def initialize(r53, zone)
    @r53 = r53
    @zone = zone
  end

  # yields Aws::Route53::Types::HostedZone
  def each(&block)
    next_zoneid = nil
    dns_name = @zone

    loop do
      opts = {dns_name: dns_name, max_items: 100}
      opts.update(hosted_zone_id: next_zoneid) if next_zoneid
      resp = @r53.list_hosted_zones_by_name(opts)
      matches = resp.hosted_zones.select {|o| o.name.delete_suffix('.') == @zone }.each(&block)

      break if resp.hosted_zones.size > matches.size or not resp.is_truncated #
      next_zoneid, dns_name = resp.next_hosted_zone_id, resp.next_dns_name
    end
  end
end

# -----------------------------------------------------------------------------
def parse_options
  OptionParser.new do |opts|
    opts.on('--doit', 'Actually do it') { @options[:dry_run] = false }
    opts.on('--stop-on-error', 'Stop on first error') { @options[:error_stop] = true }
    opts.on('--verbose') { @options[:verbose] = true }
  end.parse!
end

def init_aws
  opts = {}
  @logger.formatter = -> (severity, datetime, progname, msg) { "[%s] %5s: %s\n" % [datetime.strftime('%T.%3N'), severity, msg] }
  opts.update(logger: @logger, log_formatter: Aws::Log::Formatter.colored) if verbose?

  @r53 = Aws::Route53::Client.new(opts)
end

# -----------------------------------------------------------------------------
def find_zones_by_name(name)
  HostedZones.new(@r53, name).map(&:id)
end

def wipe_rrs(zoneid)
  # Array<Aws::Route53::Types::ResourceRecordSet>
  arrs = @r53.list_resource_record_sets(hosted_zone_id: zoneid).map(&:resource_record_sets).flatten.reject {|rrs| %w(SOA NS).include?(rrs.type) }
  if arrs.size > 0
    @logger.debug("Would delete the following RRs from #{zoneid}: " + arrs.map{|rrs| "#{rrs.name.chop}[#{rrs.type}]" }.join(', ')) if verbose?

    unless dryrun?
      resp = @r53.change_resource_record_sets(hosted_zone_id: zoneid,
                change_batch: {
                    changes: arrs.map {|rrs| { action: 'DELETE', resource_record_set: rrs }}
                })
    end
  end
end

def process_domain(dom)
  print "#{dom}: "
  zones = find_zones_by_name(dom)
  if zones.size > 0
    zones.each do |zoneid|
      wipe_rrs(zoneid)
      @r53.delete_hosted_zone(id: zoneid) unless dryrun?

      if verbose?
        @logger.warn("---> deleted #{zoneid}")
      else
        print "OK[#{format_zone(zoneid)}] "
      end
    end
  else
    print "NOTFOUND"
  end
  true
rescue Aws::Errors::ServiceError => exc
  @logger.error("Got error: #{exc}") if verbose?
  print "FAIL "
  return false
ensure
  puts
end

# -----------------------------------------------------------------------------
def verbose?; @options[:verbose] end
def dryrun?; @options[:dry_run] end
def format_zone(zone); zone.delete('/hostedzone/'); end
# -----------------------------------------------------------------------------
def main
  parse_options
  init_aws

  ok = true
  while (dom = gets&.chomp)
    ok &= process_domain(dom)
    break if not ok and @options[:error_stop]
  end

  exit(ok ? 0 : 1)
end

main