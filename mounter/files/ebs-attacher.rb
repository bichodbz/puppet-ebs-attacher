#!/usr/bin/ruby

require 'rubygems'
require 'aws-sdk'
require 'optparse'

MAX_RETRIES = 5

options = Hash.new

OptionParser.new do |opts|

  opts.on('-n','--name NAME','volume name') do |n|
    options[:name] = n
  end

  opts.on('-d','--device DEVICE','device name') do |d|
    options[:device] = d
  end

  opts.on('-f','--region REGION','AWS region') do |d|
    options[:region] = d
  end

  opts.on('-i','--volume-id VOLUME_ID','Volume Id') do |id|
    options[:volume_id] = id
  end

end.parse! 

if not options.has_key? :device
  puts "missing device option"
  exit(1)
end

if File.exists?(options[:device])
  puts "nothing to do, filesystem exists"
  exit(0)
end

if not options.has_key? :name and options.has_key? :volume_id
  puts "missing volume name and volume id, one must be specified"
  exit(1)
end


instance_id = %x(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
zone = %x(curl --silent http://169.254.169.254/latest/meta-data/placement/availability-zone)

ec2 = Aws::EC2::Client.new(region: options[:region])

def link_nvme_device(volume_id,device)
  found = false
  while not found
    Dir['/dev/disk/by-id/*'].each do |volume|
      if volume.match(/#{volume_id.tr('-','')}$/)
        found = true
        File.symlink(volume,device)
      end
    end
    sleep 2
  end
end

def find_nvme_devices
  Dir['/dev/nvme*'].collect do |d| d[0,10] end.uniq
end

retries = 0
initial_devices = find_nvme_devices
begin
  if not options.has_key? :volume_id
    volume = ec2.describe_volumes(filters: [{name: 'tag:Name', values: [options[:name]] }, {name: 'status', values: ['available'] } , { name: 'availability-zone', values: [zone]}] )[0][0]
    if volume.nil?
      puts "error, there aren any volumes under the name #{options[:name]} that are available for attaching"
      exit(1)
    end
    options[:volume_id] = volume['volume_id']
  end
  if File.symlink? options[:device]
    File.delete(options[:device])
  end
  ec2.attach_volume(volume_id: options[:volume_id], instance_id: instance_id, device: options[:device])
rescue
  if retries < MAX_RETRIES
    retries += 1
    retry
  else
    raise
  end
end

if initial_devices.size == 0
  while not File.exists?(options[:device])
    sleep 5
  end
else
  new_devices = find_nvme_devices
  while new_devices.size == initial_devices
    sleep 1
    new_devices = find_nvme_devices
  end
  link_nvme_device(volume['volume_id'],options[:device])
end