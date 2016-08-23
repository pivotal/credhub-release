#!/bin/bash

set -e

cd $(dirname $0)

gem install bundler
bundle install
bundle exec rspec