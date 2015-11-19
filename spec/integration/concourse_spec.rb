require 'spec_helper'
require 'tmpdir'
require 'fileutils'

describe 'full concourse emulation' do
  let(:dest_dir) { Dir.mktmpdir }
  let(:git_dir) { Dir.mktmpdir }
  let(:git_uri)  { "file://#{git_dir}" }
  let(:proxy) { Billy::Proxy.new }

  def git(cmd, dir = git_dir)
    Dir.chdir(dir) { `git #{cmd}`.chomp }
  end

  def commit(msg)
    git("-c user.name='test' -c user.email='test@example.com' commit -q --allow-empty -m '#{msg}'")
    git('log --format=format:%H HEAD')
  end

  def task(cmd)
    tmp_dir = Dir.mktmpdir
    FileUtils.cp_r(dest_dir, File.join(tmp_dir, 'repo'))
    Dir.chdir(tmp_dir) { `#{cmd}` }
  end

  before do
    git('init -q')
    @ref = commit('init')
    commit('second')

    git("update-ref refs/pull/1/head #{@ref}")
    proxy.start
  end

  specify do
    source = { uri: git_uri, repo: 'jtarchie/test' }

    proxy
      .stub('https://api.github.com:443/repos/jtarchie/test/pulls')
      .and_return(json: [{url:'http://example.com', number: 1, head: {sha: @ref}}])
    proxy
      .stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@ref}")
      .and_return(json: [])
    versions = check({source: source})
    proxy.reset

    proxy
      .stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
      .and_return(json: {url:'http://example.com', number: 1, head: {sha: @ref}})
    get(version: versions.first, source: source)
    proxy.reset

    proxy
      .stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
      .and_return(json: {url:'http://example.com', number: 1, head: {sha: @ref}})
    proxy
      .stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@ref}", method: :post)
    put(params: { status: 'pending' }, source: source)
    proxy.reset

    expect(task('cd repo && git show')).to include 'init'

    proxy
      .stub('https://api.github.com:443/repos/jtarchie/test/pulls/1')
      .and_return(json: {url:'http://example.com', number: 1, head: {sha: @ref}})
    proxy
      .stub("https://api.github.com:443/repos/jtarchie/test/statuses/#{@ref}", method: :post)
    put(params: { status: 'success' }, source: source)
  end
end
