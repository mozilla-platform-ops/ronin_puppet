# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Example hash format:
# {
#   'Macmini7,1'     => [ 'MM71.0232.B00' ],
#   'MacBookPro13,3' => [ 'VirtualBox' ],
# }



class macos_utils::assert_firmware (
    Hash $acceptance_hash,
) {

    if $facts['os']['family'] == 'Darwin' {
        # Get the boot rom version and model identifier of THIS apple host
        $this_rom = $facts['system_profiler']['boot_rom_version']
        $this_model = $facts['system_profiler']['model_identifier']

        # Check if this model is defined in the acceptance hash and fail if it isn't
        if ! $this_model in keys($acceptance_hash) {
            fail("Apple hardware model ${this_model} is not specified in the provided acceptance list")
        }

        # Check if this hosts boot rom is in the acceptance list for this model and fail if it isn't
        if ! $this_rom in $acceptance_hash[$this_model] {
            fail("Boot ROM version ${this_rom} does not match an acceptable version for hardware model ${this_model}")
        }
    } else {
        fail("${module_name} does not support ${facts['os']['family']}")
    }
}
