#!/bin/bash

export USER=$(whoami)
export CORES=$(grep -c '^processor' /proc/cpuinfo)
export SGE_CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export SGE_ROOT=$SGE_CONFIG_DIR
echo $SGE_CONFIG_DIR
sed -i -r "s/^(127.0.0.1\s)(localhost\.localdomain\slocalhost)/\1localhost localhost.localdomain ${HOSTNAME} /" /etc/hosts
cp /etc/resolv.conf /etc/resolv.conf.orig
echo "domain ${HOSTNAME}" >> /etc/resolv.conf
# Update everything.
yum -y update -q
yum -y install epel-release
yum -y install gridengine gridengine-devel gridengine-qmaster gridengine-execd libdrmaa.so.1.0
cp $SGE_CONFIG_DIR/util/arch $SGE_CONFIG_DIR/util/arch.orig
sed -i 's/osrelease="`$UNAME -r`"/osrelease="2.6.1"/g' $SGE_CONFIG_DIR/util/arch
(cd $SGE_CONFIG_DIR && ./inst_sge -x -m -auto ./docker_configuration.conf)
cp ${SGE_ROOT}/default/common/act_qmaster ${SGE_ROOT}/default/common/act_qmaster.orig
echo $HOSTNAME > ${SGE_ROOT}/default/common/act_qmaster
service sgemaster restart
service sge_execd restart
source $SGE_CONFIG_DIR/default/common/settings.sh
cp $SGE_CONFIG_DIR/user.conf.tmpl $SGE_CONFIG_DIR/user.conf
sed -i -r "s/template/${USER}/" $SGE_CONFIG_DIR/user.conf
qconf -suserl | xargs -r -I {} qconf -du {} arusers
qconf -suserl | xargs -r qconf -duser
qconf -Auser $SGE_CONFIG_DIR/user.conf
qconf -au $USER arusers
qconf -ss | xargs -r qconf -ds
qconf -sel | xargs -r qconf -de
qconf -as $HOSTNAME
cp $SGE_CONFIG_DIR/host.conf.tmpl $SGE_CONFIG_DIR/host.conf
sed -i -r "s/localhost/${HOSTNAME}/" $SGE_CONFIG_DIR/host.conf
export HOST_IN_SEL=$(qconf -sel | grep -c "${HOSTNAME}")
if [ $HOST_IN_SEL != "1" ]; then qconf -Ae $SGE_CONFIG_DIR/host.conf; else qconf -Me $SGE_CONFIG_DIR/host.conf; fi
cp $SGE_CONFIG_DIR/queue.conf.tmpl $SGE_CONFIG_DIR/queue.conf
sed -i -r "s/localhost/${HOSTNAME}/" $SGE_CONFIG_DIR/queue.conf
sed -i -r "s/UNDEFINED/${CORES}/" $SGE_CONFIG_DIR/queue.conf
cp $SGE_CONFIG_DIR/batch.conf.tmpl $SGE_CONFIG_DIR/batch.conf
qconf -sql | xargs -r qconf -dq
qconf -spl | grep -v "make" | xargs -r qconf -dp
qconf -Ap $SGE_CONFIG_DIR/batch.conf
qconf -Aq $SGE_CONFIG_DIR/queue.conf
service sgemaster restart
service sge_execd restart
echo "Printing queue info to verify that things are working correctly."
qstat -f -q all.q -explain a
echo "You should see sge_execd and sge_qmaster running below:"
ps aux | grep "sge"
# Add a job based test to make sure the system really works.
echo
echo "Submit a simple job to make sure the submission system really works."

mkdir /tmp/test_gridengine &>/dev/null
pushd /tmp/test_gridengine &>/dev/null
set -e

echo "-------------- test.sh --------------"
echo -e '#!/bin/bash\necho "stdout"\necho "stderr" 1>&2' | tee test.sh
echo "-------------------------------------"
echo
chmod +x test.sh

qsub -cwd -sync y test.sh
echo

echo "------------ test.sh.o1 -------------"
cat test.sh.o*
echo "-------------------------------------"
echo

echo "------------ test.sh.e1 -------------"
cat test.sh.e*
echo "-------------------------------------"
echo

grep stdout test.sh.o* &>/dev/null
grep stderr test.sh.e* &>/dev/null

rm test.sh*

set +e
popd &>/dev/null
rm -rf /tmp/test_gridengine &>/dev/null
# Put everything back the way it was.
service sge_execd stop
service sgemaster stop
cp /etc/resolv.conf.orig /etc/resolv.conf
cp ${SGE_ROOT}/default/common/act_qmaster.orig ${SGE_ROOT}/default/common/act_qmaster
# Make sure the `$CORES` variable is set in the profile.
echo -e '\nexport CORES=$(grep -c '"'"'^processor'"'"' /proc/cpuinfo)' >> /etc/bashrc
echo -e '\nsetenv CORES `grep -c '"'"'^processor'"'"' /proc/cpuinfo`' >> /etc/csh.cshrc
# Clean yum so we don't have a bunch of junk left over from our build.
yum clean all
