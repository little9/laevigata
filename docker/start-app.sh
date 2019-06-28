#!/bin/bash

bundle check || bundle install
bundle exec sidekiq -d
bundle exec rails s -b 0.0.0.0