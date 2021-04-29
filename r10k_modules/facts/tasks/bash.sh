#!/bin/bash

# This script may be called outside of a task, e.g. by puppet_agent
# so we have to just paste this code here.  *grumbles*
# Exit with an error message and error code, defaulting to 1
fail() {
  # Print a message: entry if there were anything printed to stderr
  if [[ -s $_tmp ]]; then
    # Hack to try and output valid json by replacing newlines with spaces.
    error_data="{ \"msg\": \"$(tr '\n' ' ' <"$_tmp")\", \"kind\": \"bash-error\", \"details\": {} }"
  else
    error_data="{ \"msg\": \"Task error\", \"kind\": \"bash-error\", \"details\": {} }"
  fi
  echo "{ \"status\": \"failure\", \"_error\": $error_data }"
  exit "${2:-1}"
}

validation_error() {
  error_data="{ \"msg\": \""$1"\", \"kind\": \"bash-error\", \"details\": {} }"
  echo "{ \"status\": \"failure\", \"_error\": $error_data }"
  exit 255
}

success() {
  echo "$1"
}

determine_command_for_facter_4() {
  puppet_version="$(puppet --version)"

  if (( ${puppet_version%%.*} == 6 )); then
    # puppet 6 with facter 4
    facts_command=(facter --json --show-legacy)
  else
    # puppet 7 with facter 4
    facts_command=(puppet facts show --show-legacy --render-as json)
  fi
}

maybe_delegate_to_facter() {
  [[ $PATH =~ \/opt\/puppetlabs\/bin ]] || export PATH="${PATH}:/opt/puppetlabs/bin"

  # Only use facter if we're running as the "facts" task, not the "facts::bash"
  # task. This also skips calling facter if we're running as a script, which is
  # used by the puppet_agent task.
  if [[ $PT__task == facts ]] && type facter &>/dev/null; then
    facter_version="$(facter -v)"

    if (( ${facter_version%%.*} <= 2 )); then
      facts_command=(facter -p --json)
    elif (( ${facter_version%%.*} == 3 )); then
      facts_command=(facter -p --json --show-legacy)
    else
      # facter 4
      determine_command_for_facter_4
    fi

    exec -- "${facts_command[@]}"
  fi
}

# Get info from one of /etc/os-release or /usr/lib/os-release
# This is the preferred method and is checked first
_systemd() {
  # These files may have unquoted spaces in the "pretty" fields even if the spec says otherwise
  # source cannot use process subsitution in some versions of bash, so redirect to stdin instead
  source /dev/stdin <<<"$(sed 's/ /_/g' "$1")"

  # According to `man os-release`, the first entry in ID_LIKE
  # should be the one the platform most closely resembles
  if [[ $ID = 'rhel' ]]; then
    family='RedHat'
  elif [[ $ID = 'debian' ]]; then
    family='Debian'
  elif [[ $ID_LIKE ]]; then
    family="${ID_LIKE%% *}"
  else
    family="${ID}"
  fi
}

# Get info from lsb_release
_lsb_release() {
  read -r ID < <(lsb_release -si)
  read -r VERSION_ID < <(lsb_release -sr)
  read -r VERSION_CODENAME < <(lsb_release -sc)
}

# Get info from rhel /etc/*-release files
_rhel() {
  family='RedHat'
  # slurp the file
  ver_info=$(<"$1")
  # ID is the first word in the string
  ID="${ver_info%% *}"
  # Codename is hopefully the word(s) in parenthesis
  if echo "$ver_info" | grep -q '('; then
    VERSION_CODENAME="${ver_info##*\(}"
    VERSION_CODENAME=""${VERSION_CODENAME//[()]/}""
  fi

  # Get a string like 'release 1.2.3' and grab everything after the space
  release=$(echo "$ver_info" | grep -Eo 'release[[:space:]]*[0-9.]+')
  VERSION_ID="${release#* }"
}

# Last resort
_uname() {
  [[ $ID ]] || ID="$(uname)"
  [[ $VERSION_ID ]] || VERSION_ID="$(uname -r)"
}

# Taken from https://github.com/puppetlabs/facter/blob/master/lib/inc/facter/facts/os.hpp
# If not in this list, we just uppercase the first character and lowercase the rest
munge_name() {
  case "$1" in
    redhat|rhel|red) echo "RedHat" ;;
    ol|oracle) echo "OracleLinux" ;;
    ubuntu) echo "Ubuntu" ;;
    debian) echo "Debian" ;;
    centos) echo "CentOS" ;;
    cloud) echo "CloudLinux" ;;
    virtuozzo) echo "VirtuozzoLinux" ;;
    psbm) echo "PSBM" ;;
    xenserver) echo "XenServer" ;;
    linuxmint) echo "LinuxMint" ;;
    sles) echo "SLES" ;;
    suse) echo "SuSE" ;;
    opensuse) echo "OpenSuSE" ;;
    sunos) echo "SunOS" ;;
    omni) echo "OmniOS" ;;
    openindiana) echo "OpenIndiana" ;;
    manjaro) echo "ManjaroLinux" ;;
    smart) echo "SmartOS" ;;
    openwrt) echo "OpenWrt" ;;
    meego) echo "MeeGo" ;;
    coreos) echo "CoreOS" ;;
    zen) echo "XCP" ;;
    kfreebsd) echo "GNU/kFreeBSD" ;;
    arista) echo "AristaEOS" ;;
    huawei) echo "HuaweiOS" ;;
    photon) echo "PhotonOS" ;;
    *) echo "$(tr '[:lower:]' '[:upper:]' <<<"${ID:0:1}")""$(tr '[:upper:]' '[:lower:'] <<<"${ID:1}")"
  esac
}

_tmp="$(mktemp)"
exec 2>>"$_tmp"

shopt -s nocasematch

# Use indirection to munge PT_ environment variables
# e.g. "$PT_version" becomes "$version"
for v in ${!PT_*}; do
  declare "${v#*PT_}"="${!v}"
done

# Delegate to facter executable if it exists. This function will `exec` and not
# return if facter exists. Otherwise, we'll continue on.
maybe_delegate_to_facter "$@"

if [[ -e /etc/os-release ]]; then
  _systemd /etc/os-release
elif [[ -e /usr/lib/os-release ]]; then
  _systemd /usr/lib/os-release
fi

# If either systemd is not installed or we didn't get a minor version or codename from os-release
if ! [[ $VERSION_ID ]] || (( ${VERSION_ID%%.*} == ${VERSION_ID#*.} )) || ! [[ $VERSION_CODENAME ]]; then
  if [[ -e /etc/fedora-release ]]; then
    _rhel /etc/fedora-release
  elif [[ -e /etc/centos-release ]]; then
    _rhel /etc/centos-release
  elif [[ -e /etc/oracle-release ]]; then
    _rhel /etc/oracle-release
  elif [[ -e /etc/redhat-release ]]; then
    _rhel /etc/redhat-release
  elif type lsb_release &>/dev/null; then
    _lsb_release
  else
    _uname
  fi
fi

full="${VERSION_ID}"
major="${VERSION_ID%%.*}"
# Minor is considered the second part of the version string
IFS='.' read -ra minor <<<"$full"
minor="${minor[1]}"

ID="$(munge_name "$ID")"
family="$(munge_name "$family")"

# We should change puppet_agent to not work this way
if [[ $@ =~ 'platform' ]]; then
  success "$ID"
  exit 0
elif [[ $@ =~ 'release' ]]; then
  success "$full"
  exit 0
fi

success "$(cat <<EOF
{
  "os": {
    "name": "$ID",
    "distro": {
      "codename": "$VERSION_CODENAME"
    },
    "release": {
      "full": "$full",
      "major": "$major",
      "minor": "$minor"
    },
    "family": "$family"
  }
}
EOF
)"
