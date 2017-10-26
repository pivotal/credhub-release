#!/usr/bin/env ruby

require 'yaml'
require 'open-uri'
require 'fileutils'

$java_base_version = '1.8'
puts "\nThis script is pinned to base version: #{$java_base_version}"

def latest_for(yaml_url, package_name)
  yaml = YAML.load(open(yaml_url).read)
  yaml = yaml.inject({}) do |memo, (key, value)|
    memo[Gem::Version.new(key.gsub("_", "."))] = value
    memo
  end

  # Filter results to match pinned base version, then sort
  matching_versions = yaml.select { |key, value| key.to_s.match(/^#{$java_base_version}/) }
  sorted_versions = matching_versions.keys.sort

  yaml[sorted_versions.last].tap do |latest|
    puts "Guessed latest #{package_name}: #{latest} (please confirm!)"
  end
end

def latest_jre
  latest_for 'http://download.pivotal.io.s3.amazonaws.com/openjdk/trusty/x86_64/index.yml', 'jre'
end

def latest_jdk
  latest_for 'https://java-buildpack.cloudfoundry.org/openjdk-jdk/trusty/x86_64/index.yml', 'jdk'
end

jre_url = latest_jre
jdk_url = latest_jdk
jre_filename = File.basename(URI(jre_url).path)
jdk_filename = File.basename(URI(jdk_url).path)

# Write JDK URL to the packages/credhub/pre_packaging script. We need the JDK to build our code on CI.
pre_packaging_script_path = 'packages/credhub/pre_packaging'
pre_packaging_script = File.read(pre_packaging_script_path)
File.open(pre_packaging_script_path, 'w') do |f|
  f.print pre_packaging_script.sub(/JDK_URL="[^"]+"/, "JDK_URL=\"#{jdk_url}\"")
end

# Download current JRE
blobs_dir = "blobs/openjdk_#{$java_base_version}.0"
FileUtils.mkdir_p(blobs_dir)
system "cd #{blobs_dir} && curl \"#{jre_url}\" -o \"#{jre_filename}\""

# Download current JDK and add it as a blob
openjdk_dir = "openjdk_#{$java_base_version}.0"
FileUtils.mkdir(openjdk_dir)
system "cd #{openjdk_dir} && curl \"#{jdk_url}\" -o \"#{jdk_filename}\""

# Update blobs/openjdk_1.8.0/spec
spec_path = 'packages/openjdk_'+ $java_base_version + '.0/spec'
spec = YAML.load_file(spec_path)
spec['files'][0] = "openjdk_#{$java_base_version}.0/#{jre_filename}"
File.open(spec_path, 'w') { |f| f.puts YAML.dump(spec) }

# Add new JDK to blobs
spec_path = 'packages/openjdk_'+ $java_base_version + '.0/spec'
spec = YAML.load_file(spec_path)
spec['files'][0] = "openjdk_#{$java_base_version}.0/#{jre_filename}"
File.open(spec_path, 'w') { |f| f.puts YAML.dump(spec) }

puts "\nIf this looks good, do a dev release for testing, and finally \"bosh upload blobs\" and commit when you're happy."
