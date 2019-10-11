# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

class packages::python3 (
    Pattern[/^\d+\.\d+\.\d+_?\d*$/] $version = '3.7.4',
) {

    # https://www.python.org/ftp/python/3.7.4/python-3.7.4-macosx10.9.pkg
    # 9c7771bc539c619e47aed34074d07d67abb80013610754a561bbc40d70eefe5b

    packages::macos_package_from_s3 { "python-${version}-macosx10.9.pkg":
        private             => false,
        os_version_specific => false,
        type                => 'pkg',
    }
}
