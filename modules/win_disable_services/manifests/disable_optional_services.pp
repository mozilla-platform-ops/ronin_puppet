# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

## "- DON'T Disable." = has adverse effects if disabled

class win_disable_services::disable_optional_services {

  $services = [

    # --- Bluetooth ---
    'BTAGService',          # Bluetooth Audio Gateway Service
    'bthserv',              # Bluetooth Support Service
    'BthAvctpSvc',          # AVCTP Service (Bluetooth audio)

    # --- Telemetry / diagnostics ---
    'DiagTrack',            # Connected User Experiences and Telemetry
    'DPS',                  # Diagnostic Policy Service - Disabled in MaintainSytems script too
    'DusmSvc',              # Data Usage
    'WdiServiceHost',       # Diagnostic System Host

    # --- Network discovery & publishing ---
    'FDResPub',             # Function Discovery Resource Publication
    'FDResHost',            # Function Discovery Provider Host

    # --- Print / themes / prefetch (optional) ---
    'Spooler',              # Print Spooler (disable only if you never print)
    'Themes',               # Themes (visual styles)
    'SysMain',              # SysMain (SuperFetch / prefetcher)

    # --- Wi-Fi / MS account / notifications / web accounts ---
    'WlanSvc',              # WLAN AutoConfig (Wi-Fi)
    'wlidsvc',              # Microsoft Account Sign-in Assistant
    'WpnService',           # Windows Push Notifications System Service - Disabled in MaintainSytems script too
    'TokenBroker',          # Web Account Manager

    # --- UWP / Microsoft Store ecosystem ---
    'AppReadiness',         # App readiness
    'AppXSvc',              # AppX Deployment Service
#   'CDPSvc',               # Connected Devices Platform Service - DON'T Disable.
#   'ClipSVC',              # Client License Service (Store licensing) - DON'T Disable.
#   'CoreMessagingRegistrar', # CoreMessaging - won't disable
#   'StateRepository',      # State Repository Service - DON'T Disable.
#   'SystemEventsBroker',   # System Events Broker - DON'T Disable.
#   'TextInputManagementSvc', # Text Input Management - DON'T Disable.
#   'TimeBrokerSvc',        # Time Broker (background tasks) - DON'T Disable.

    # --- Indexing / contacts ---
    'TrkWks',               # Distributed Link Tracking Client - Disabled in MaintainSytems script too

    # --- Third-party / vendor helpers (excluding nxlog) ---
    'igccservice',          # Intel Graphics Command Center Service
    'IntelAudioService',    # Intel Audio Service
    'jhi_service',          # Intel Dynamic Application Loader Host
    'RtkAudioUniversalService', # Realtek Audio Universal Service
#   'webthreatdefsvc',      # Web Threat Defense service - DON'T Disable.

    # --- Others ---
#   'RmSvc',                # Radio Management Service (airplane mode / radios) - DON'T Disable.
    'NgcCtnrSvc',           # Microsoft Passport Container (Windows Hello / PIN)
    'lfsvc',                # Geolocation Service
    'PcaSvc',               # Program Compatibility Assistant Service
    'SSDPSRV',              # SSDP Discovery/UPnP Discovery
  ]

  $services_disable_only = [
    'webthreatdefsvc',
    'RmSvc',
  ]

  service { $services:
    enable => false,
  }

  service { $services_disable_only:
    enable => false,
  }
}
