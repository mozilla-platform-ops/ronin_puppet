# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Source: https://support.microsoft.com/en-gb/topic/kb5022083-change-in-how-wpf-based-applications-render-xps-documents-a4ae4fa4-bc58-4c37-acdd-5eebc4e34556
class roles_profiles::profiles::disable_dec22patch {
  include win_disable_dec22patch::disable
}
