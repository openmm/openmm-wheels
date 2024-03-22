openmm-wheels
=============

Repository to build wheels for openmm.

We are using github actions to build wheels. Wheels are found in the
github actions artifacts section and when a release is made in this
github repo, wheels are uploaded to the release as well.

Use ./rerender.sh to rerender this feedstock

There are two wheels for each platform. Eg: for linux

- OpenMM-8.1.1-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
- openmm_cuda-8.1.1.12-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl

The first wheel contains all files except the CUDA plugins and the
second wheel contains all the CUDA plugins.

When uploaded to PyPI, these wheels can be installed with

    pip install openmm[cuda12]

or

    pip install openmm[cuda112]

To install without the CUDA plugins,

    pip install openmm
