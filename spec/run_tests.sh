#!/bin/bash

set -e

gem install bundler
bundle install
bundle exec rspec