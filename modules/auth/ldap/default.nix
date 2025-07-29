# { config, lib, pkgs, ... }:

# with lib;

# let
#   cfg = config.dov.auth.ldap;
#   domainToDC = domain: "dc=" + (replaceStrings ["."] [",dc="] domain);
#   baseDN = domainToDC cfg.domain;
#   rootPasswordFile = config.sops.secrets."ldap/root".path;
# in
# {
#   # --- Module Options ---
#   options.dov.auth.ldap = {
#     enable = mkEnableOption "Enable OpenLDAP service";
#     domain = mkOption {
#       type = types.str;
#       default = "susano-nixos.duckdns.org";
#       description = "The base domain for the LDAP directory.";
#     };
#   };

#   # --- Module Configuration ---
#   config = mkIf cfg.enable {

#     sops.secrets = {
#       "ldap/root" = {
#         owner = config.services.openldap.user;
#         group = config.services.openldap.group;
#         mode = "0400";
#       };
#       "ldap/authelia" = mkIf config.dov.auth.authelia.enable {
#         owner = config.services.openldap.user;
#         group = config.services.openldap.group;
#         mode = "0400";
#       };
#     };

#     # --- Allow LDAP to use Traefik's SSL Certificates ---
#     # Since Traefik is already getting valid certs for your domain, we reuse them for LDAPS.
#     users.groups.acme.members = [ "openldap" ];
#     security.acme = {
#       acceptTerms = true;
#       certs."${cfg.domain}" = {
#         # This assumes your Traefik is getting certs for the root domain.
#         # If not, you might need a separate cert definition here.
#       };
#     };

#     # --- OpenLDAP Service Configuration ---
#     services.openldap = {
#       enable = true;
#       # This provides the hashed password for the Root DN.
#       passwordFile = cfg.rootPasswordFile;
#       # --- Declarative Directory Information Tree (DIT) ---
#       # This LDIF file defines the entire structure and initial data of your directory.
#       ldifFile = pkgs.writeText "ldif-declarative" ''
#         # The Base DN of your directory
#         dn: ${baseDN}
#         objectClass: top
#         objectClass: dcObject
#         objectClass: organization
#         o: ${cfg.domain} organization
#         dc: ${head (splitString "." cfg.domain)}

#         # The Admin user for daily management
#         # Note: This is different from the ultimate Root DN (cn=admin,${baseDN})
#         dn: cn=admin,${baseDN}
#         objectClass: simpleSecurityObject
#         objectClass: organizationalRole
#         cn: admin
#         description: LDAP administrator

#         # --- Standard Organizational Units (OUs) ---
#         dn: ou=people,${baseDN}
#         objectClass: organizationalUnit
#         ou: people

#         dn: ou=groups,${baseDN}
#         objectClass: organizationalUnit
#         ou: groups

#         dn: ou=services,${baseDN}
#         objectClass: organizationalUnit
#         ou: services

#         # --- Service Account for Authelia (read-only) ---
#         dn: cn=authelia,ou=services,${baseDN}
#         objectClass: inetOrgPerson
#         objectClass: organizationalPerson
#         objectClass: person
#         objectClass: top
#         cn: authelia
#         sn: Service Account
#         mail: authelia@${cfg.domain}
#         # Special syntax to read the raw password from a file at runtime.
#         userPassword:: file://${config.sops.secrets."ldap/authelia".path}

#         # --- Initial Users and Groups ---
#         # An example user 'jdoe'
#         # dn: uid=jdoe,ou=people,${baseDN}
#         # objectClass: inetOrgPerson
#         # objectClass: organizationalPerson
#         # objectClass: person
#         # objectClass: top
#         # uid: jdoe
#         # cn: John Doe
#         # sn: Doe
#         # displayName: John Doe
#         # mail: jdoe@${cfg.domain}
#         # # Provide a hashed password for this user
#         # userPassword: {SSHA}your-ssha-hash-for-jdoe

#         # Example 'admins' group
#         dn: cn=admins,ou=groups,${baseDN}
#         objectClass: groupOfNames
#         objectClass: top
#         cn: admins
#         # Add 'jdoe' to the admins group
#         member: uid=jdoe,ou=people,${baseDN}

#         # Example 'dev' group
#         dn: cn=dev,ou=groups,${baseDN}
#         objectClass: groupOfNames
#         objectClass: top
#         cn: dev
#       '';

#       # --- Security and Access Control ---
#       # Enable LDAPS (LDAP over SSL) on port 636
#       settings = {
#         "olcTLSCertificateFile" = config.security.acme.certs."${cfg.domain}".cert;
#         "olcTLSCertificateKeyFile" = config.security.acme.certs."${cfg.domain}".key;
#         # Fine-grained Access Control Lists (ACLs)
#         # Order matters: from most specific to most general.
#         "olcAccess" = [
#           # The admin user and root user have full control.
#           "{0}to * by dn.base=\"cn=admin,${baseDN}\" write by dn.base=\"${config.services.openldap.rootDN}\" write by * break"
#           # The authelia service account can read entries.
#           "{1}to * by dn.base=\"cn=authelia,ou=services,${baseDN}\" read"
#           # Users can change their own password.
#           "{2}to attrs=userPassword by self write by anonymous auth by * none"
#           # Users can read their own entry.
#           "{3}to * by self read by * none"
#         ];
#       };
#     };

#     # --- Firewall ---
#     # Open the LDAPS port. We do not open the unencrypted port 389.
#     networking.firewall.allowedTCPPorts = [ 636 ];
#   };
# }
{
}
