#!/bin/bash -ue
# Simple script to create RPM package that installs the HariSekhon Nagios plugins
# Christian Bryn 2017 <chr.bryn@gmail.com>

name="nagios-plugins-harisekhon"
package_format="rpm"
# dependencies are for yum/rpm
dependencies="perl-JSON perl-TermReadKey"
opts=""
# This project has no versioning scheme AFAIK, so setting a static version that can be overriden.
build_version="1.0.0"
include_old_plugins="false"


while getopts dhop: o
do
  case $o in
    d)
    dependencies="$OPTARG" ;;
    h)
    print_help ; exit 1 ;;
    o)
    include_old_plugins="true" ;;
    p)
    package_format="$OPTARG" ;;
    V)
    build_version="$OPTARG" ;;
  esac
done
shift $(($OPTIND-1))

[[ -f Makefile ]] || { echo "No Makefile found. This script must be run from the project root (run contrib/build-pkg.sh)"; exit 1; }
which fpm > /dev/null 2>&1 || { echo "fpm not installed, bailing..."; exit 1; }

for i in ${dependencies};
do
  opts+=" -d ${i}"
done


build_dir='build'
rm -rf ${build_dir}/* || true
os_install_path="opt/${name}"
mkdir -p ${build_dir}/${os_install_path}
# Set up PATH as well:
mkdir -p ${build_dir}/etc/profile.d

#build_version="'grep version somefile' or 'git tag' ... "
git_commit=$( git rev-parse HEAD )

make

cp -r lib pylib ${build_dir}/${os_install_path}/
cp *.py ${build_dir}/${os_install_path}/
cp *.pl ${build_dir}/${os_install_path}/
if [[ "${include_old_plugins}" == "true" ]]
then
  cp older/*.py ${build_dir}/${os_install_path}/
  cp older/*.pl ${build_dir}/${os_install_path}/
  cp older/*.sh ${build_dir}/${os_install_path}/
fi

echo -en "export PATH=\$PATH:/opt/${name}\n" > ${build_dir}/etc/profile.d/${name}.sh

fpm -s dir ${opts:-} -t "${package_format}" -n "${name}" -v ${build_version}_git~${git_commit} -C ${build_dir} opt etc

