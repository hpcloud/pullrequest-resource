#!/usr/bin/env ruby

destination = ARGV.shift

require 'rubygems'
require 'json'
require 'octokit'
require_relative 'common'

id = nil
Dir.chdir(destination) do
  id = `git config --get pullrequest.id`.chomp
  warn "id: #{id}"
  warn "destination: #{destination}"
end

repo = Repository.new(name: input['source']['repo'])
pr   = repo.pull_request(id: id)

pr.status!(input['params']['status'])

json!({
  version: pr.as_json,
  metadata: [
    {name: 'url', value: pr.url},
    {name: 'status', value: input['params']['status']}
  ]
})
