require 'spec_helper_acceptance'

describe 'Purge' do
  def acl_manifest(target, user_id1, user_id2)
    <<-MANIFEST
      file { "#{target_parent}":
        ensure => directory
      }

      file { "#{target}":
        ensure  => directory,
        require => File['#{target_parent}']
      }

      user { "#{user_id1}":
        ensure     => present,
        groups     => 'Users',
        managehome => true,
        password   => "L0v3Pupp3t!"
      }

      user { "#{user_id2}":
        ensure     => present,
        groups     => 'Users',
        managehome => true,
        password   => "L0v3Pupp3t!"
      }

      acl { "#{target}":
        permissions  => [
          { identity => '#{user_id1}', rights => ['full'] },
        ],
      }
    MANIFEST
  end

  def purge_acl_manifest(target, user_id2)
    <<-MANIFEST
      acl { "#{target}":
        purge        => 'true',
        permissions  => [
          { identity => '#{user_id2}', rights => ['full'] },
        ],
      }
    MANIFEST
  end

  context 'Only Purge Explicit Permissions from Directory with Inheritance' do
    target = 'c:/temp/purge_exp_inherit'
    user_id1 = 'bob'
    user_id2 = generate_random_username

    verify_acl_command = "icacls #{target}"
    acl_regex_user_id1 = %r{.*\\bob:\(OI\)\(CI\)\(F\)}
    acl_regex_user_id2 = %r{.*\\#{user_id2}:\(OI\)\(CI\)\(F\)}

    windows_agents.each do |agent|
      context "on #{agent}" do
        it 'Execute Apply Manifest' do
          execute_manifest_on(agent, acl_manifest(target, user_id1, user_id2), { :debug => true }) do |result|
            assert_no_match(%r{Error:}, result.stderr, 'Unexpected error was detected!')
          end
        end

        it 'Verify that ACL Rights are Correct' do
          on(agent, verify_acl_command) do |result|
            assert_match(acl_regex_user_id1, result.stdout, 'Expected ACL was not present!')
          end
        end

        it 'Execute Purge Manifest' do
          execute_manifest_on(agent, purge_acl_manifest(target, user_id2), { :debug => true }) do |result|
            assert_no_match(%r{Error:}, result.stderr, 'Unexpected error was detected!')
          end
        end

        it 'Verify that ACL Rights are Correct (Post-Purge)' do
          on(agent, verify_acl_command) do |result|
            assert_no_match(acl_regex_user_id1, result.stdout, 'Unexpected ACL was present!')
            assert_match(acl_regex_user_id2, result.stdout, 'Expected ACL was not present!')
          end
        end
      end
    end
  end
end
