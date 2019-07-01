require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/validation_encryption.yml template' do
    let(:template) { job.template('config/validation_encryption.yml') }

    it 'checks that there is an active key' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties'
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('Exactly one encryption key must be marked as active in the deployment manifest. Please update your configuration to proceed.')
    end

    it 'checks that there is only one active key' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties',
                'active' => true
              },
              {
                'provider_name' => 'some-other-provider',
                'key_properties' => 'some-other-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('Exactly one encryption key must be marked as active in the deployment manifest. Please update your configuration to proceed.')
    end

    it 'checks that provider type is supported' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'my-fancy-provider'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('The provided encryption provider type is not valid. Valid provider types are "hsm", "internal", and "kms-plugin".')
    end

    it 'checks that there is only one hsm provider' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'hsm'
              },
              {
                'type' => 'hsm'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('More than one hsm provider is not supported. Please update your configuration to proceed.')
    end

    it 'checks that there is only one kms-plugin provider' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'kms-plugin'
              },
              {
                'type' => 'kms-plugin'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('More than one kms-plugin provider is not supported. Please update your configuration to proceed.')
    end

    it 'checks that connection_properties is not set if using internal encryption' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'internal',
                'connection_properties' => {}
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('connection_properties should only be provided for providers of type "hsm" or "kms-plugin".')
    end

    it 'checks that endpoint is set if using kms-plugin provider type' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'kms-plugin',
                'connection_properties' => {}
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('connection_properties for a provider of type "kms-plugin" must provide an "endpoint".')
    end

    it 'checks that partition and partition_password are not set in multiple places' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'hsm',
                'connection_properties' => {},
                'partition' => '',
                'partition_password' => ''
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => 'some-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('`partition` and `partition_password` cannot be provided both through `connection_properties` and directly')
    end

    it 'checks that key provider name matches provider name' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'internal',
                'name' => 'my-cool-provider'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'not-listed-provider',
                'key_properties' => 'some-properties',
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('`provider_name` provided for key is not in list of providers')
    end

    it 'allows both encryption_key_name and encryption_password to be set' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'internal',
                'name' => 'some-provider'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => {
                  'encryption_key_name' => 'some-key-name',
                  'encryption_password' => 'some-password-longer-than-20-chars'
                },
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.not_to raise_error
    end

    it 'checks that encryption_password is valid' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'internal',
                'name' => 'some-provider'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => {
                  'encryption_password' => ''
                },
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('credhub.encryption.keys[].key_properties.encryption_password is not valid (must not be empty if provided).')
    end

    it 'checks that active encryption_password length is greater than 20 characters' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'internal',
                'name' => 'some-provider'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => {
                  'encryption_password' => 'weak-password'
                },
                'active' => true
              }
            ]
          }
        }
      }

      expect { template.render(manifest) }.to raise_error('The encryption_password value must be at least 20 characters in length. Please update and redeploy.')
    end

    it 'does not check that inactive encryption_password length is greater than 20 characters' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'internal',
                'name' => 'some-provider'
              }
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => {
                  'encryption_password' => 'weak-password'
                },
                'active' => false              },
                {
                  'provider_name' => 'some-provider',
                  'key_properties' => {
                    'encryption_password' => 'not-weak-password-not-weak-password-not-weak-password'
                  },
                  'active' => true              }
            ]
          }
        }
      }

      template.render(manifest)
    end

    it 'flattens the keys array' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              {
                'type' => 'internal',
                'name' => 'some-provider'
              }
            ],
            'keys' => [
              [{
                'provider_name' => 'some-provider',
                'key_properties' => {
                  'encryption_password' => 'some-strong-password'
                },
                'active' => true
              }],
              [{
                'provider_name' => 'some-provider',
                'key_properties' => {
                  'encryption_password' => 'some-other-strong-password'
                },
                'active' => false
              }]
            ]
          }
        }
      }

      template.render(manifest)
    end

    it 'flattens the providers array' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'providers' => [
              [{
                'type' => 'internal',
                'name' => 'some-provider'
              }],
              [{
                'type' => 'internal',
                'name' => 'some-other-provider'
              }]
            ],
            'keys' => [
              {
                'provider_name' => 'some-provider',
                'key_properties' => {
                  'encryption_password' => 'some-strong-password'
                },
                'active' => true
              },
              {
                'provider_name' => 'some-other-provider',
                'key_properties' => {
                  'encryption_password' => 'some-other-strong-password'
                },
                'active' => false
              }
            ]
          }
        }
      }

      template.render(manifest)
    end
  end
end
