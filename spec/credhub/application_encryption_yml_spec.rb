require 'rspec'
require 'json'
require 'yaml'
require 'bosh/template/test'

describe 'credhub job' do
  let(:release) { Bosh::Template::Test::ReleaseDir.new(File.join(File.dirname(__FILE__), '..', '..')) }
  let(:job) { release.job('credhub') }

  describe 'config/application/encryption.yml template' do
    let(:template) { job.template('config/application/encryption.yml') }

    it 'flattens key arrays into one key array' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'keys' => [
              [
                {
                  'provider_name' => 'some-internal-provider',
                  'key_properties' => {
                    'encryption_password' => 'some-encryption-password'
                  }
                }
              ],
              [
                {
                  'provider_name' => 'some-internal-provider',
                  'key_properties' => {
                    'encryption_password' => 'some-second-encryption-password'
                  },
                  'active' => true
                }
              ],
              [
                {
                  'provider_name' => 'some-internal-provider',
                  'key_properties' => {
                    'encryption_password' => 'some-third-encryption-password'
                  }
                }
              ]
            ],
            'providers' => [
              {
                'name' => 'some-internal-provider',
                'type' => 'internal'
              }
            ]
          }
        }
      }
      rendered_template = YAML.safe_load(template.render(manifest))

      expect(rendered_template['encryption']['providers']).to eq([
                                                                   {
                                                                     'provider_name' => 'some-internal-provider',
                                                                     'provider_type' => 'internal',
                                                                     'keys' => [
                                                                       {
                                                                         'encryption_password' => 'some-encryption-password'
                                                                       },
                                                                       {
                                                                         'encryption_password' => 'some-second-encryption-password',
                                                                         'active' => true
                                                                       },
                                                                       {
                                                                         'encryption_password' => 'some-third-encryption-password'
                                                                       }
                                                                     ]
                                                                   }
                                                                 ])
    end

    it 'flattens providers arrays into one providers array' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'keys' => [
              {
                'provider_name' => 'some-internal-provider',
                'key_properties' => {
                  'encryption_password' => 'some-encryption-password'
                }
              },
              {
                'provider_name' => 'some-other-internal-provider',
                'key_properties' => {
                  'encryption_password' => 'some-encryption-password'
                }
              }
            ],
            'providers' => [
              [
                {
                  'name' => 'some-internal-provider',
                  'type' => 'internal'
                }
              ],
              [
                {
                  'name' => 'some-other-internal-provider',
                  'type' => 'internal'
                }
              ]
            ]
          }
        }
      }
      rendered_template = YAML.safe_load(template.render(manifest))

      expect(rendered_template['encryption']['providers']).to eq([
                                                                   {
                                                                     'provider_name' => 'some-internal-provider',
                                                                     'provider_type' => 'internal',
                                                                     'keys' => [
                                                                       {
                                                                         'encryption_password' => 'some-encryption-password'
                                                                       }
                                                                     ]
                                                                   },
                                                                   {
                                                                     'provider_name' => 'some-other-internal-provider',
                                                                     'provider_type' => 'internal',
                                                                     'keys' => [
                                                                       {
                                                                         'encryption_password' => 'some-encryption-password'
                                                                       }
                                                                     ]
                                                                   }

                                                                 ])
    end

    it 'maps keys to providers' do
      manifest = {
        'credhub' => {
          'encryption' => {
            'keys' => [
              {
                'provider_name' => 'some-internal-provider',
                'key_properties' => {
                  'encryption_password' => 'some-encryption-password'
                }
              },
              {
                'provider_name' => 'some-internal-provider',
                'key_properties' => {
                  'encryption_password' => 'some-second-encryption-password'
                },
                'active' => true
              },
              {
                'provider_name' => 'some-kms-plugin-provider',
                'key_properties' => {
                  'encryption_key_name' => 'some-kms-plugin-encryption-key-name'
                }
              },
              {
                'provider_name' => 'some-kms-plugin-provider',
                'key_properties' => {
                  'encryption_key_name' => 'some-second-kms-plugin-encryption-key-name'
                }
              },
              {
                'provider_name' => 'some-hsm-provider',
                'key_properties' => {
                  'encryption_key_name' => 'some-hsm-encryption-key-name'
                }
              }
            ],
            'providers' => [
              {
                'name' => 'some-internal-provider',
                'type' => 'internal'
              },
              {
                'name' => 'some-kms-plugin-provider',
                'type' => 'kms-plugin',
                'connection_properties' => {
                  'endpoint' => 'some-endpoint'
                }
              },
              {
                'name' => 'some-hsm-provider',
                'type' => 'hsm',
                'connection_properties' => {
                  'partition' => 'some-partition',
                  'partition_password' => 'some-partition-password',
                  'client_certificate' => 'some-client-certificate',
                  'client_key' => 'some-client-key'
                }
              }
            ]
          }
        }
      }
      rendered_template = YAML.safe_load(template.render(manifest))

      expect(rendered_template['encryption']['providers']).to eq([
                                                                   {
                                                                     'provider_name' => 'some-internal-provider',
                                                                     'provider_type' => 'internal',
                                                                     'keys' => [
                                                                       {
                                                                         'encryption_password' => 'some-encryption-password'
                                                                       },
                                                                       {
                                                                         'encryption_password' => 'some-second-encryption-password',
                                                                         'active' => true
                                                                       }
                                                                     ]
                                                                   },
                                                                   {
                                                                     'provider_name' => 'some-kms-plugin-provider',
                                                                     'provider_type' => 'kms-plugin',
                                                                     'keys' => [
                                                                       {
                                                                         'encryption_key_name' => 'some-kms-plugin-encryption-key-name'
                                                                       },
                                                                       {
                                                                         'encryption_key_name' => 'some-second-kms-plugin-encryption-key-name'
                                                                       }
                                                                     ],
                                                                     'configuration' => {
                                                                       'endpoint' => 'some-endpoint'
                                                                     }
                                                                   },
                                                                   {
                                                                     'provider_name' => 'some-hsm-provider',
                                                                     'provider_type' => 'hsm',
                                                                     'keys' => [
                                                                       {
                                                                         'encryption_key_name' => 'some-hsm-encryption-key-name'
                                                                       }
                                                                     ],
                                                                     'configuration' => {
                                                                       'partition' => 'some-partition',
                                                                       'partition_password' => 'some-partition-password',
                                                                       'client_certificate' => 'some-client-certificate',
                                                                       'client_key' => 'some-client-key'
                                                                     }
                                                                   }
                                                                 ])
    end

    context 'internal provider' do
      context 'when an internal provider is configured without an encryption password' do
        it 'raises an exception' do
          manifest = {
            'credhub' => {
              'encryption' => {
                'keys' => [
                  {
                    'provider_name' => 'some-internal-provider',
                    'key_properties' => {}
                  }
                ],
                'providers' => [
                  {
                    'name' => 'some-internal-provider',
                    'type' => 'internal'
                  }
                ]
              }
            }
          }

          expect { template.render(manifest) }.to raise_error('`internal` providers require `encryption_password`')
        end
      end
    end

    context 'kms-plugin provider' do
      context 'when a kms-plugin provider is configured without an encryption key name' do
        it 'raises an exception' do
          manifest = {
            'credhub' => {
              'encryption' => {
                'keys' => [
                  {
                    'provider_name' => 'some-kms-plugin-provider',
                    'key_properties' => {}
                  }
                ],
                'providers' => [
                  {
                    'name' => 'some-kms-plugin-provider',
                    'type' => 'kms-plugin'
                  }
                ]
              }
            }
          }

          expect { template.render(manifest) }.to raise_error('`kms-plugin` providers require `encryption_key_name`')
        end
      end

      context 'when a kms-plugin provider is configured without required connection_properties' do
        it 'raises an exception' do
          manifest = {
            'credhub' => {
              'encryption' => {
                'keys' => [
                  {
                    'provider_name' => 'some-kms-plugin-provider',
                    'key_properties' => {
                      'encryption_key_name' => 'some-encryption-key-name'
                    }
                  }
                ],
                'providers' => [
                  {
                    'name' => 'some-kms-plugin-provider',
                    'type' => 'kms-plugin',
                    'connection_properties' => {}
                  }
                ]
              }
            }
          }

          expect { template.render(manifest) }.to raise_error('`kms-plugin` providers require `endpoint`')
        end
      end
    end

    context 'hsm provider' do
      context 'when an hsm provider is configured without an encryption key name' do
        it 'raises an exception' do
          manifest = {
            'credhub' => {
              'encryption' => {
                'keys' => [
                  {
                    'provider_name' => 'some-hsm-provider',
                    'key_properties' => {}
                  }
                ],
                'providers' => [
                  {
                    'name' => 'some-hsm-provider',
                    'type' => 'hsm'
                  }
                ]
              }
            }
          }

          expect { template.render(manifest) }.to raise_error('`hsm` providers require `encryption_key_name`')
        end
      end

      context 'when an hsm provider is configured without required connection_properties' do
        base_manifest = {
          'credhub' => {
            'encryption' => {
              'keys' => [
                {
                  'provider_name' => 'some-hsm-provider',
                  'key_properties' => {
                    'encryption_key_name' => 'some-encryption-key-name'
                  }
                }
              ],
              'providers' => [
                {
                  'name' => 'some-hsm-provider',
                  'type' => 'hsm',
                  'connection_properties' => {
                    'partition' => 'some-partition',
                    'partition_password' => 'some-partition-password',
                    'client_certificate' => 'some-client-certificate',
                    'client_key' => 'some-client-key'
                  }
                }
              ]
            }
          }
        }

        it 'raises an exception for partition' do
          manifest = Marshal.load(Marshal.dump(base_manifest))
          manifest['credhub']['encryption']['providers'][0]['connection_properties'].delete('partition')

          expect { template.render(manifest) }.to raise_error('`hsm` providers require `connection_properties.partition`')
        end
        it 'raises an exception for partition_password' do
          manifest = Marshal.load(Marshal.dump(base_manifest))
          manifest['credhub']['encryption']['providers'][0]['connection_properties'].delete('partition_password')

          expect { template.render(manifest) }.to raise_error('`hsm` providers require `connection_properties.partition_password`')
        end
        it 'raises an exception for client_certificate' do
          manifest = Marshal.load(Marshal.dump(base_manifest))
          manifest['credhub']['encryption']['providers'][0]['connection_properties'].delete('client_certificate')

          expect { template.render(manifest) }.to raise_error('`hsm` providers require `connection_properties.client_certificate`')
        end
        it 'raises an exception for client_key' do
          manifest = Marshal.load(Marshal.dump(base_manifest))
          manifest['credhub']['encryption']['providers'][0]['connection_properties'].delete('client_key')

          expect { template.render(manifest) }.to raise_error('`hsm` providers require `connection_properties.client_key`')
        end
      end

      context 'when configuring an hsm provider' do
        it 'populates hsm connection property `partition`' do
          manifest = {
            'credhub' => {
              'encryption' => {
                'keys' => [
                  {
                    'provider_name' => 'some-hsm-provider',
                    'key_properties' => {
                      'encryption_key_name' => 'some-hsm-encryption-key-name'
                    }
                  }
                ],
                'providers' => [
                  {
                    'name' => 'some-hsm-provider',
                    'type' => 'hsm',
                    'connection_properties' => {
                      'partition' => 'some-partition',
                      'partition_password' => 'some-partition-password',
                      'client_certificate' => 'some-client-certificate',
                      'client_key' => 'some-client-key'
                    }
                  }
                ]
              }
            }
          }
          rendered_template = YAML.safe_load(template.render(manifest))

          expect(rendered_template['encryption']['providers']).to eq([
                                                                       {
                                                                         'provider_name' => 'some-hsm-provider',
                                                                         'provider_type' => 'hsm',
                                                                         'keys' => [
                                                                           {
                                                                             'encryption_key_name' => 'some-hsm-encryption-key-name'
                                                                           }
                                                                         ],
                                                                         'configuration' => {
                                                                           'partition' => 'some-partition',
                                                                           'partition_password' => 'some-partition-password',
                                                                           'client_certificate' => 'some-client-certificate',
                                                                           'client_key' => 'some-client-key'
                                                                         }
                                                                       }
                                                                     ])
        end
      end
    end

    context 'when on the bootstrap instance' do
      it 'enables key creation' do
        manifest = {
          'credhub' => {
            'encryption' => {
              'keys' => [],
              'providers' => []
            }
          }
        }
        instance = Bosh::Template::Test::InstanceSpec.new(bootstrap: true)
        rendered_template = YAML.safe_load(template.render(manifest, spec: instance))

        expect(rendered_template['encryption']['key_creation_enabled']).to eq(true)
      end
    end

    context 'when not on the bootstrap instance' do
      it 'disables key creation' do
        manifest = {
          'credhub' => {
            'encryption' => {
              'keys' => [],
              'providers' => []
            }
          }
        }
        instance = Bosh::Template::Test::InstanceSpec.new(bootstrap: false)
        rendered_template = YAML.safe_load(template.render(manifest, spec: instance))

        expect(rendered_template['encryption']['key_creation_enabled']).to eq(false)
      end
    end
  end
end
