#!/usr/bin/env bash

# exit on error
set -o errexit

export NODE_OPTIONS=--openssl-legacy-provider

bundle config set --local frozen false
bundle config unset deployment
bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:prepare
# bundle exec rails db:seed  # disabled – run manually via `rails db:seed` in Render shell when needed
