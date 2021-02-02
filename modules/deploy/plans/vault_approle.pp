# This plan seeds a target with an approle id and secret for Vault Agent consumption
# @param targets A list of targets to seed with vault approle
# @param approle_id The approle id
# @param approle_secret The approle secret
# @param noop An optional noop flag for dry run
plan deploy::vault_approle(
    TargetSpec $targets,
    String     $approle_id,
    Sensitive  $approle_secret,
    Boolean    $noop = false,
) {

    $targets.apply_prep
    apply($targets, _catch_errors => false, _noop => $noop, _run_as => root) {
        file {
            # Create approle id and secret file for vault agent to consume
            '/etc/vault_approle_id':
                ensure  => file,
                mode    => '0600',
                content => "${approle_id}\n";
            '/etc/vault_approle_secret':
                ensure  => file,
                mode    => '0600',
                content => "${approle_secret.unwrap}\n";
        }
    }
}
