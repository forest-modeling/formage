# ---- Stage 1: Build ----
ARG PYTHON_VERSION=3.12
ARG OS_TAG=slim-bookworm

FROM python:$PYTHON_VERSION-$OS_TAG AS builder

ARG PYFVS_VERSION=main
ARG PYNVEL_VERSION=main
ARG PYSITEINDEX_VERSION=main
# FVS variant libraries to build, must be lowercase
ARG FVS_VARIANTS=pn,wc,ca,so,op,oc,ec,nc,bm,ie,ci,ak,ws
#,em,tt,cr,ut,ls,cs,sn,ne
# ARG FVS_VARIANTS=pn,wc,ca,so
# ARG PYFVS_VERSION=v0.3.2

ARG ROOT=/formage

RUN apt update && apt install -y \
    git \
    gcc \
    g++ \
    gfortran \
    wget \
  && rm -rf /var/lib/apt/lists/* \
  && apt clean

WORKDIR "$ROOT"

# Set environment variables for the virtual environment location
ENV VIRTUAL_ENV="$ROOT/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN python -m venv "$ROOT/venv" \
    && python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir \
      ninja meson meson-python setuptools_scm \
      numpy pandas cython toml matplotlib \
      click confuse typing-extensions

# Clone, build, install PyFVS
WORKDIR "$ROOT"
RUN git clone https://github.com/forest-modeling/PyFVS.git --recurse-submodules

WORKDIR "$ROOT/PyFVS"

RUN git checkout "${PYFVS_VERSION}"
RUN python -m pip install . \
  --verbose --no-build-isolation \
  --config-settings=setup-args="-Dfvsvariants=$FVS_VARIANTS"

# Clone, build, install PyNVEL
WORKDIR "$ROOT"
RUN git clone https://github.com/forest-modeling/pynvel.git --recurse-submodules

WORKDIR "$ROOT/pynvel"

RUN git checkout "${PYNVEL_VERSION}"
RUN python -m pip install . --verbose --no-build-isolation

# Clone and install PySiteIndex
WORKDIR "$ROOT"
RUN git clone https://github.com/forest-modeling/pysiteindex.git --recurse-submodules

WORKDIR "$ROOT/pysiteindex"

RUN git checkout "${PYSITEINDEX_VERSION}"
RUN python -m pip install . --verbose --no-build-isolation

# Cleanup build only packages from the venv
RUN python -m pip uninstall -y \
  ninja meson meson-python setuptools_scm cython

# ---- Stage 2: Production ----
FROM python:$PYTHON_VERSION-$OS_TAG

RUN apt update && apt install -y --no-install-recommends libgfortran5 \
  && rm -rf /var/lib/apt/lists/* \
  && apt clean

ARG ROOT=/formage
COPY --from=builder "$ROOT/venv" "$ROOT/venv"

# Set environment variables for the virtual environment location
ENV VIRTUAL_ENV="$ROOT/venv"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

WORKDIR "$ROOT"

CMD ["/bin/bash"]
