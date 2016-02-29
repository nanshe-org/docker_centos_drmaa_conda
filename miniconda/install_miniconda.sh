#!/bin/bash

# Update yum.
yum update -y -q

# Install curl to download the miniconda setup script.
yum install -y curl

# Install VCS.
yum install -y git hg svn

# Install bzip2.
yum install -y bzip2 tar

# Install dependencies of conda's Qt4.
yum install -y libSM libXext libXrender

# Clean out yum.
yum clean all

# Download and configure conda.
cd /usr/share/miniconda
curl http://repo.continuum.io/miniconda/Miniconda2-latest-Linux-x86_64.sh > miniconda2.sh
bash miniconda2.sh -b -p /opt/conda2
rm miniconda2.sh
curl http://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh > miniconda3.sh
bash miniconda3.sh -b -p /opt/conda3
rm miniconda3.sh
ln -s /opt/conda2 /opt/conda
export PATH="/opt/conda/bin:${PATH}"
source activate root
conda config --set show_channel_urls True

# Install basic conda dependencies.
conda update -y --all
conda install -y pycrypto
conda install -y conda-build
conda install -y anaconda-client
conda install -y jinja2

# Install python bindings to DRMAA.
conda install -y drmaa

# Clean out all unneeded intermediates.
conda clean -yitps
