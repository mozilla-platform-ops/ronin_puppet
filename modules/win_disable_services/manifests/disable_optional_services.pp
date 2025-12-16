# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class win_disable_services::disable_optional_services {

  $services = [

    # --- Bluetooth ---
    'BTAGService',          # Bluetooth Audio Gateway Service
    'bthserv',              # Bluetooth Support Service
    'BthAvctpSvc',          # AVCTP Service (Bluetooth audio)

    # --- Telemetry / diagnostics ---
    'DiagTrack',            # Connected User Experiences and Telemetry
    'DPS',                  # Diagnostic Policy Service
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
    'WpnService',           # Windows Push Notifications System Service
    'TokenBroker',          # Web Account Manager

    # --- UWP / Microsoft Store ecosystem ---
    'AppReadiness',         # App readiness
#    'AppXSvc',              # AppX Deployment Service
    'CDPSvc',               # Connected Devices Platform Service
#    'ClipSVC',              # Client License Service (Store licensing)
    'CoreMessagingRegistrar', # CoreMessaging
#    'StateRepository',      # State Repository Service
    'SystemEventsBroker',   # System Events Broker
    'TextInputManagementSvc', # Text Input Management
    'TimeBrokerSvc',        # Time Broker (background tasks)

    # --- Indexing / contacts ---
    'TrkWks',               # Distributed Link Tracking Client

    # --- Third-party / vendor helpers (excluding nxlog) ---
    'igccservice',          # Intel Graphics Command Center Service
    'IntelAudioService',    # Intel Audio Service
    'jhi_service',          # Intel Dynamic Application Loader Host
    'RtkAudioUniversalService', # Realtek Audio Universal Service
    'webthreatdefsvc',      # Web Threat Defense service

    # --- Others ---
    'RmSvc',                # Radio Management Service (airplane mode / radios)
    'NgcCtnrSvc',           # Microsoft Passport Container (Windows Hello / PIN)
  ]

  $services_disable_only = [
    'SystemEventsBroker',
    'webthreatdefsvc',
    'RmSvc',
  ]

  service { $services:
    ensure => 'stopped',
    enable => false,
  }

  service { $services_disable_only:
    enable => false,
  }
}
