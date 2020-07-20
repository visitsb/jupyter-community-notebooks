# All Jupyter community notebooks for haskell, c-sharp, java etc together.
# https://jupyter-docker-stacks.readthedocs.io/en/latest/using/selecting.html#community-stacks
# See ##### cooment sections for individual notebooks included in this image
# https://jupyter-docker-stacks.readthedocs.io/en/latest/index.html
ARG BASE_CONTAINER=jupyter/datascience-notebook
FROM $BASE_CONTAINER

LABEL maintainer="Shanti Naik <visitsb@gmail.com>"

##### JBINDINGA/JAVA-NOTEBOOK #####
# https://raw.githubusercontent.com/jbindinga/java-notebook/master/Dockerfile
USER root

# Install dependencies
RUN apt-get update && apt-get install -y \
  software-properties-common \
  curl

# Install Zulu OpenJdk 11 (LTS)
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0xB1998361219BD9C9 \
  && apt-add-repository 'deb http://repos.azulsystems.com/ubuntu stable main' \
  && apt install -y zulu-11

# Unpack and install the kernel
RUN curl -L https://github.com/SpencerPark/IJava/releases/download/v1.3.0/ijava-1.3.0.zip > ijava-kernel.zip
RUN unzip ijava-kernel.zip -d ijava-kernel \
  && cd ijava-kernel \
  && python3 install.py --sys-prefix

# Install jupyter RISE extension.
RUN pip install jupyter_contrib-nbextensions RISE \
  && jupyter-nbextension install rise --py --system \
  && jupyter-nbextension enable rise --py --system \
  && jupyter contrib nbextension install --system \
  && jupyter nbextension enable hide_input/main

# Cleanup
RUN rm ijava-kernel.zip

# Add README.md
# ADD "README.md" $HOME

# Set user back to priviledged user.
USER $NB_USER

#####  UMSI-MADS/EDUCATION-NOTEBOOK #####
# https://raw.githubusercontent.com/umsi-mads/education-notebook/master/Dockerfile
USER root

# First install some missing dependencies
# Note: there is no need to install the "jupyter" metapackage because all the needed
# pieces for nbgrader funtionality are already installed by the bootstraped image.
RUN conda install fuzzywuzzy --yes

# Then install nbgrader with --no-deps because all the neeeded deps are already present.
# Additionally, latest nbgrader release is pinging an old ipython version breaking stuff.
# Note: Eventually, when things get fixed upstream we can remove the previous installation
# of "fuzzywuzzy" and remove the --no-deps flag.
RUN conda install nbgrader --no-deps --yes

# Add RISE 5.4.1 to the mix as well so user can show live slideshows from their notebooks
# More info at https://rise.readthedocs.io
# Note: Installing RISE with --no-deps because all the neeeded deps are already present.
RUN conda install rise --no-deps --yes

##### TLINNET/CSHARP-NOTEBOOK #####
# https://hub.docker.com/r/tlinnet/csharp-notebook/dockerfile
# Also see https://github.com/tlinnet/csharp-notebook/blob/master/Dockerfile for C# Notebooks
# Install Mono to Ubuntu 18.04
USER root
RUN apt-get update && apt-get install -yq --no-install-recommends \
    gnupg \
    && apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF && \
    echo "deb https://download.mono-project.com/repo/ubuntu stable-bionic main" | sudo tee /etc/apt/sources.list.d/mono-official-stable.list && \
    apt-get update && apt-get install -yq --no-install-recommends \
    mono-complete \
    mono-dbg \
    mono-runtime-dbg \
    ca-certificates-mono \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

#RUN mozroots --import --machine --sync
RUN cert-sync /etc/ssl/certs/ca-certificates.crt && \
    git clone --recursive https://github.com/zabirauf/icsharp.git /icsharp && \
    cd /icsharp/Engine && \
    mono ./.nuget/NuGet.exe restore ./ScriptCs.sln && \
    cd /icsharp && \
    mono ./.nuget/NuGet.exe restore ./iCSharp.sln && \
    xbuild ./iCSharp.sln /property:Configuration=Release /nologo /verbosity:normal && \
    mkdir -p build/Release/bin && \
    for line in $(find ./*/bin/Release/*); do cp $line ./build/Release/bin; done

# Install kernel
RUN mkdir -p $HOME/.local && \
    mkdir -p $HOME/.mono && \
    mkdir -p $HOME/.nuget
    
RUN chown -R $NB_USER:users $HOME/.local && \
    chown -R $NB_USER:users $HOME/.mono && \
    chown -R $NB_USER:users $HOME/.nuget && \
    echo '{' > /icsharp/kernel-spec/kernel.json && \
    echo '    "argv": ["mono", "/icsharp/build/Release/bin/iCSharp.Kernel.exe", "{connection_file}"],' >> /icsharp/kernel-spec/kernel.json && \
    echo '    "display_name": "C#",' >> /icsharp/kernel-spec/kernel.json && \
    echo '    "language": "csharp"' >> /icsharp/kernel-spec/kernel.json && \
    echo '}' >> /icsharp/kernel-spec/kernel.json

# Switch back to jovyan to avoid accidental container runs as root
USER $NB_USER
RUN cd /icsharp && \
    jupyter-kernelspec install --user kernel-spec

##### JAMESDBROCK/IHASKELL-NOTEBOOK #####
# https://raw.githubusercontent.com/jamesdbrock/ihaskell-notebook/master/Dockerfile
# Extra arguments to `stack build`. Used to build --fast, see Makefile.
ARG STACK_ARGS=

USER root

# The global snapshot package database will be here in the STACK_ROOT.
ENV STACK_ROOT=/opt/stack
RUN mkdir -p $STACK_ROOT
RUN fix-permissions $STACK_ROOT

# Install Haskell Stack and its dependencies
RUN apt-get update && apt-get install -yq --no-install-recommends \
        python3-pip \
        git \
        libtinfo-dev \
        libzmq3-dev \
        libcairo2-dev \
        libpango1.0-dev \
        libmagic-dev \
        libblas-dev \
        liblapack-dev \
        libffi-dev \
        libgmp-dev \
        gnupg \
        netbase \
# for ihaskell-graphviz
        graphviz \
# for Stack download
        curl \
# Stack Debian/Ubuntu manual install dependencies
# https://docs.haskellstack.org/en/stable/install_and_upgrade/#linux-generic
        g++ \
        gcc \
        libc6-dev \
        libffi-dev \
        libgmp-dev \
        make \
        xz-utils \
        zlib1g-dev \
        git \
        gnupg \
        netbase && \
# Clean up apt
    rm -rf /var/lib/apt/lists/*

# Stack Linux (generic) Manual download
# https://docs.haskellstack.org/en/stable/install_and_upgrade/#linux-generic
#
# So that we can control Stack version, we do manual install instead of
# automatic install:
#
#    curl -sSL https://get.haskellstack.org/ | sh
#
ARG STACK_VERSION="2.3.1"
ARG STACK_BINDIST="stack-${STACK_VERSION}-linux-x86_64"
RUN    cd /tmp \
    && curl -sSL --output ${STACK_BINDIST}.tar.gz https://github.com/commercialhaskell/stack/releases/download/v${STACK_VERSION}/${STACK_BINDIST}.tar.gz \
    && tar zxf ${STACK_BINDIST}.tar.gz \
    && cp ${STACK_BINDIST}/stack /usr/bin/stack \
    && rm -rf ${STACK_BINDIST}.tar.gz ${STACK_BINDIST} \
    && stack --version

# Stack global non-project-specific config stack.config.yaml
# https://docs.haskellstack.org/en/stable/yaml_configuration/#non-project-specific-config
RUN mkdir -p /etc/stack
# COPY stack.config.yaml /etc/stack/config.yaml
ADD https://raw.githubusercontent.com/jamesdbrock/ihaskell-notebook/master/stack.config.yaml /etc/stack/config.yaml
RUN fix-permissions /etc/stack

# Stack global project stack.yaml
# https://docs.haskellstack.org/en/stable/yaml_configuration/#yaml-configuration
RUN mkdir -p $STACK_ROOT/global-project
# COPY global-project.stack.yaml $STACK_ROOT/global-project/stack.yaml
ADD https://raw.githubusercontent.com/jamesdbrock/ihaskell-notebook/master/global-project.stack.yaml $STACK_ROOT/global-project/stack.yaml
RUN    chown --recursive $NB_UID:users $STACK_ROOT/global-project \
    && fix-permissions $STACK_ROOT/global-project

# fix-permissions for /usr/local/share/jupyter so that we can install
# the IHaskell kernel there. Seems like the best place to install it, see
#      jupyter --paths
#      jupyter kernelspec list
RUN    mkdir -p /usr/local/share/jupyter \
    && fix-permissions /usr/local/share/jupyter \
    && mkdir -p /usr/local/share/jupyter/kernels \
    && fix-permissions /usr/local/share/jupyter/kernels

# Now make a bin directory for installing the ihaskell executable on
# the PATH. This /opt/bin is referenced by the stack non-project-specific
# config.
RUN    mkdir -p /opt/bin \
    && fix-permissions /opt/bin
ENV PATH ${PATH}:/opt/bin

# Specify a git branch for IHaskell (can be branch or tag).
# The resolver for all stack builds will be chosen from
# the IHaskell/stack.yaml in this commit.
# https://github.com/gibiansky/IHaskell/commits/master
# IHaskell 2020-05-28
ARG IHASKELL_COMMIT=a992ad83702e55b774de234d77ffd2682d842682
# Specify a git branch for hvega
# https://github.com/DougBurke/hvega/commits/master
# hvega 2020-06-11
ARG HVEGA_COMMIT=58a6861a3ebecdfe2ade149c1bff3064341fee33

# Clone IHaskell and install ghc from the IHaskell resolver
RUN    cd /opt \
    && curl -L "https://github.com/gibiansky/IHaskell/tarball/$IHASKELL_COMMIT" | tar xzf - \
    && mv *IHaskell* IHaskell \
    && curl -L "https://github.com/DougBurke/hvega/tarball/$HVEGA_COMMIT" | tar xzf - \
    && mv *hvega* hvega \
# Copy the Stack global project resolver from the IHaskell resolver.
    && grep 'resolver:' /opt/IHaskell/stack.yaml >> $STACK_ROOT/global-project/stack.yaml \
    && fix-permissions /opt/IHaskell \
    && fix-permissions $STACK_ROOT \
    && fix-permissions /opt/hvega \
    && stack setup \
    && fix-permissions $STACK_ROOT \
# Clean 176MB
    && rm -f /opt/stack/programs/x86_64-linux/ghc-8.6.5.tar.xz

# ghc-parser and ipython-kernel are dependencies of ihaskell.
# Build them first in separate RUN commands so we don't exceed Dockerhub
# resource limits and fail with no build log.
# https://success.docker.com/article/docker-hub-automated-build-fails-and-the-logs-are-missing-empty
# Build ghc-parser
RUN    stack build $STACK_ARGS ghc-parser \
    && fix-permissions /opt/IHaskell \
    && fix-permissions $STACK_ROOT
# Build ipython-kernel
RUN    stack build $STACK_ARGS ipython-kernel \
    && fix-permissions /opt/IHaskell \
    && fix-permissions $STACK_ROOT
# Build IHaskell
RUN    stack build $STACK_ARGS ihaskell \
# Note that we are NOT in the /opt/IHaskell directory here, we are
# installing ihaskell via the paths given in /opt/stack/global-project/stack.yaml
    && fix-permissions /opt/IHaskell \
    && fix-permissions $STACK_ROOT

# Install IHaskell.Display libraries
# https://github.com/gibiansky/IHaskell/tree/master/ihaskell-display
RUN    stack build $STACK_ARGS ihaskell-aeson \
    && stack build $STACK_ARGS ihaskell-blaze \
    && stack build $STACK_ARGS ihaskell-charts \
    && stack build $STACK_ARGS ihaskell-diagrams \
    && stack build $STACK_ARGS ihaskell-gnuplot \
    && stack build $STACK_ARGS ihaskell-graphviz \
    && stack build $STACK_ARGS ihaskell-hatex \
    && stack build $STACK_ARGS ihaskell-juicypixels \
#   && stack build $STACK_ARGS ihaskell-magic \
#   && stack build $STACK_ARGS ihaskell-plot \
#   && stack build $STACK_ARGS ihaskell-rlangqq \
#   && stack build $STACK_ARGS ihaskell-static-canvas \
# Skip install of ihaskell-widgets, they don't work.
# See https://github.com/gibiansky/IHaskell/issues/870
#   && stack build $STACK_ARGS ihaskell-widgets \
    && stack build $STACK_ARGS hvega \
    && stack build $STACK_ARGS ihaskell-hvega \
    && fix-permissions $STACK_ROOT \
# Fix for https://github.com/jamesdbrock/ihaskell-notebook/issues/14#issuecomment-636334824
    && fix-permissions /opt/IHaskell \
    && fix-permissions /opt/hvega

# Cleanup
# Don't clean IHaskell/.stack-work, 7GB, this causes issue #5
#   && rm -rf $(find /opt/IHaskell -type d -name .stack-work) \
# Don't clean /opt/hvega
# We can't actually figure out anything to cleanup.

# Bug workaround for https://github.com/jamesdbrock/ihaskell-notebook/issues/9
RUN mkdir -p /home/jovyan/.local/share/jupyter/runtime \
    && fix-permissions /home/jovyan/.local \
    && fix-permissions /home/jovyan/.local/share \
    && fix-permissions /home/jovyan/.local/share/jupyter \
    && fix-permissions /home/jovyan/.local/share/jupyter/runtime

# Install system-level ghc using the ghc which was installed by stack
# using the IHaskell resolver.
RUN mkdir -p /opt/ghc && ln -s `stack path --compiler-bin` /opt/ghc/bin \
    && fix-permissions /opt/ghc
ENV PATH ${PATH}:/opt/ghc/bin

# Switch back to jovyan user
USER $NB_UID

RUN \
# Install the IHaskell kernel at /usr/local/share/jupyter/kernels, which is
# in `jupyter --paths` data:
       stack exec ihaskell -- install --stack --prefix=/usr/local \
# Install the ihaskell_labextension for JupyterLab syntax highlighting
    && npm install -g typescript \
    && cd /opt/IHaskell/ihaskell_labextension \
    && npm install \
    && npm run build \
    && jupyter labextension install . \
# Cleanup
    && npm cache clean --force \
    && rm -rf /home/$NB_USER/.cache/yarn \
# Clean ihaskell_labextensions/node_nodemodules, 86MB
    && rm -rf /opt/IHaskell/ihaskell_labextension/node_modules

# Example IHaskell notebooks will be collected in this directory.
ARG EXAMPLES_PATH=/home/$NB_USER/ihaskell_examples

# Collect all the IHaskell example notebooks in EXAMPLES_PATH.
RUN    mkdir -p $EXAMPLES_PATH \
    && cd $EXAMPLES_PATH \
    && mkdir -p ihaskell \
    && cp --recursive /opt/IHaskell/notebooks/* ihaskell/ \
    && mkdir -p ihaskell-juicypixels \
    && cp /opt/IHaskell/ihaskell-display/ihaskell-juicypixels/*.ipynb ihaskell-juicypixels/ \
    && mkdir -p ihaskell-charts \
    && cp /opt/IHaskell/ihaskell-display/ihaskell-charts/*.ipynb ihaskell-charts/ \
    && mkdir -p ihaskell-diagrams \
    && cp /opt/IHaskell/ihaskell-display/ihaskell-diagrams/*.ipynb ihaskell-diagrams/ \
# Don't install these examples for these non-working libraries.
#   && mkdir -p ihaskell-widgets \
#   && cp --recursive /opt/IHaskell/ihaskell-display/ihaskell-widgets/Examples/* ihaskell-widgets/ \
    && mkdir -p ihaskell-hvega \
    && cp /opt/hvega/notebooks/*.ipynb ihaskell-hvega/ \
    && cp /opt/hvega/notebooks/*.tsv ihaskell-hvega/ \
    && fix-permissions $EXAMPLES_PATH

##### SHARPTRICK/SAGE-NOTEBOOK #####
# https://raw.githubusercontent.com/sharpTrick/sage-notebook/master/Dockerfile
ARG SAGE_VERSION=9.0
ARG SAGE_PYTHON_VERSION=3.7

USER root

# Sage pre-requisites and jq for manipulating json
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    dvipng \
    ffmpeg \
    imagemagick \
    texlive \
    tk tk-dev \
    jq && \
    rm -rf /var/lib/apt/lists/*


USER $NB_UID

# Initialize conda for shell interaction
RUN conda init bash

# Install Sage conda environment
RUN conda install --quiet --yes -n base -c conda-forge widgetsnbextension && \
    conda create --quiet --yes -n sage -c conda-forge sage=$SAGE_VERSION python=$SAGE_PYTHON_VERSION && \
    conda clean --all -f -y && \
    npm cache clean --force && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install sagemath kernel and extensions using conda run:
#   Create jupyter directories if they are missing
#   Add environmental variables to sage kernal using jq
RUN echo ' \
        from sage.repl.ipython_kernel.install import SageKernelSpec; \
        SageKernelSpec.update(prefix=os.environ["CONDA_DIR"]); \
    ' | conda run -n sage sage && \
    echo ' \
        cat $SAGE_ROOT/etc/conda/activate.d/sage-activate.sh | \
            grep -Po '"'"'(?<=^export )[A-Z_]+(?=)'"'"' | \
            jq --raw-input '"'"'.'"'"' | jq -s '"'"'.'"'"' | \
            jq --argfile kernel $SAGE_LOCAL/share/jupyter/kernels/sagemath/kernel.json \
            '"'"'. | map(. as $k | env | .[$k] as $v | {($k):$v}) | add as $vars | $kernel | .env= $vars'"'"' > \
            $CONDA_DIR/share/jupyter/kernels/sagemath/kernel.json \
    ' | conda run -n sage sh && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

# Install sage's python kernel
RUN echo ' \
        ls /opt/conda/envs/sage/share/jupyter/kernels/ | \
            grep -Po '"'"'python\d'"'"' | \
            xargs -I % sh -c '"'"' \
                cd $SAGE_LOCAL/share/jupyter/kernels/% && \
                cat kernel.json | \
                    jq '"'"'"'"'"'"'"'"' . | .display_name = .display_name + " (sage)" '"'"'"'"'"'"'"'"' > \
                    kernel.json.modified && \
                mv -f kernel.json.modified kernel.json && \
                ln  -s $SAGE_LOCAL/share/jupyter/kernels/% $CONDA_DIR/share/jupyter/kernels/%_sage \
            '"'"' \
    ' | conda run -n sage sh && \
    fix-permissions $CONDA_DIR && \
    fix-permissions /home/$NB_USER

##### SCIO-SYSTEMS/CGSPATIAL-NOTEBOOK #####
# https://raw.githubusercontent.com/SCiO-systems/cgspatial-notebook/master/Dockerfile
USER root

RUN pip install shapely  && \
    pip install geopandas  && \
    pip install rasterio  && \
    pip install pcse

RUN apt-get update && apt-get install software-properties-common -y
# Workaround since `ppa:ubuntugis/ppa` gives FAIL errors causing `bash pipefail` to abort; hence `|| exit 0` to let it proceed
RUN (add-apt-repository ppa:ubuntugis/ppa && apt-get update) || exit 0
RUN apt-get install gdal-bin -y && apt-get install libgdal-dev -y
RUN export CPLUS_INCLUDE_PATH=/usr/include/gdal && export C_INCLUDE_PATH=/usr/include/gdal

RUN pip install GDAL==$(gdal-config --version | awk -F'[.]' '{print $1"."$2}') && \
    pip install jupyterhub==1.0.0

RUN apt-get install unrar -y && \
    apt-get install lftp -y && \
    apt-get install libproj-dev -y && \
    apt-get install libgdal-dev -y && \
        apt-get install gdal-bin -y && \
        apt-get install proj-bin -y

RUN conda install -c conda-forge r-velox && \
    conda install -c conda-forge r-rjava

RUN apt-get remove pkg-config -y

ENV PROJ_LIB="/opt/conda/share/proj"

RUN  conda install openjdk=8.0.192=h14c3975_1003 && \
     conda install --quiet --yes 'r-rgdal' && \
     conda install --quiet --yes 'r-rgeos' && \
     conda install --quiet --yes 'r-geojsonio' && \
     conda install --quiet --yes 'r-spdep' && \
     conda install --quiet --yes 'r-rcolorbrewer' && \
     conda install --quiet --yes 'r-ncdf4'

ADD https://raw.githubusercontent.com/SCiO-systems/cgspatial-notebook/master/libraries.R libraries.R
RUN Rscript libraries.R

ADD https://github.com/SCiO-systems/cgspatial-notebook/blob/master/extra/maxent.jar?raw=true /opt/conda/lib/R/library/dismo/java/maxent.jar