#!/usr/bin/gawk -f
function is_in_array(item, array) {
  is_present = 0
  for (i in array) {
    if (item == array[i]) { is_present = 1 }
  }
  return is_present
}

BEGIN {
  PROCINFO["sorted_in"] = "@ind_num_asc"

  concerned_hosts[1] = "*"
  hosts[1] = "*"
  count = 2
}

$1 == "Host" {
  $1 = ""
  split(substr($0,2), concerned_hosts)

  for (i in concerned_hosts) {
    host = concerned_hosts[i]

    # Do not duplicate host entries
    if (!is_in_array(host, hosts)) {
      hosts[count] = host
    }

    count++
  }
}

$1 == "PasswordAuthentication" ||
$1 == "ChallengeResponseAuthentication" ||
$1 == "HostKeyAlgorithms" ||
$1 == "KexAlgorithms" ||
$1 == "Ciphers" ||
$1 == "PubkeyAuthentication" ||
$1 == "MACs" ||
$1 == "UseRoaming" {
  # When we start a new file, raw parameters are affected to "Host *"
  if (NR != FNR && FNR == 1) { concerned_hosts[1] = "*" }

  for (i in concerned_hosts) {
    host = concerned_hosts[i]

    # Do not override a value that has aleardy been set
    if (hosts_params[host, $1] == "") {
      hosts_params[host, $1] = $2
    }
  }
}

END {
  for (i in hosts) {
    host = hosts[i]

    not_yet_reported = 1

    if (host == "*") {
      level="ERROR"
    } else {
      level="WARNING"
    }

    split("PasswordAuthentication ChallengeResponseAuthentication PubkeyAuthentication UseRoaming KexAlgorithms Ciphers HostKeyAlgorithms MACs", parameters)
    split("no no yes no \
curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256 \
chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr \
ssh-ed25519-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ssh-ed25519,ssh-rsa \
hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128@openssh.com", expected_values)

    for (i in parameters) {
      parameter_name = parameters[i]
      parameter_value = hosts_params[host, parameter_name]
      expected_value = expected_values[i]

      if (parameter_value == "" && host == "*") {
        if (not_yet_reported) { printf "\nERRORS On %s:\n", host
                                not_yet_reported = 0 }
        printf "  %s: %s is missing\n", level, parameter_name, host
      } else if (parameter_value != "" && parameter_value != expected_value) {
        if (not_yet_reported) { printf "\nWARNINGS On %s:\n", host
                                not_yet_reported = 0 }
        printf "  %s: %s should be set to '%s'\n", level, parameter_name, expected_value, host
      }
    }
  }
}
