require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'bin/bbr/metadata template' do
    let(:template) { job.template('bin/bbr/metadata') }

    it 'the metadata script should have default that specifies UAA as a BBR locking dependency' do
      manifest = { 'credhub' => {} }
      script = template.render(manifest)
      expect(script).to include('echo "---
  backup_should_be_locked_before:
  - job_name: uaa
    release: uaa
  restore_should_be_locked_before:
  - job_name: uaa
    release: uaa')
    end

    context 'when credhub.authentication.uaa.enabled is set to false' do
      let(:manifest) do
        {
          'credhub' => {
            'authentication' => {
              'uaa' => {
                'enabled' => false
              }
            }
          }
        }
      end

      it 'the metadata script should be empty (aka no locking BBR locking dependencies)' do
        script = template.render(manifest)
        expect(script).to eq('#!/usr/bin/env bash

')
      end
    end
  end
end
