openmm-wheels
=============

Repository to build wheels for openmm.

We are using github actions to build wheels. Wheels are found in the
github actions artifacts section and when a release is made in this
github repo, wheels are uploaded to the release as well.

Use `./rerender.sh` to rerender this feedstock

There are two wheels for each platform. Eg: for linux

- OpenMM-8.1.1-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl
- openmm_cuda-8.1.1.12-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl

The first wheel contains all files except the CUDA plugins and the
second wheel contains all the CUDA plugins.

When uploaded to PyPI, these wheels can be installed with

    pip install openmm[cuda12]

or

    pip install openmm[cuda11.2]

or

    pip install openmm[cuda11.8]

To install without the CUDA plugins,

    pip install openmm

### Release process

1. Change `version` and `git_rev` in `recipe/meta.yaml`.
2. Run `./rerender.sh`.
3. Make a PR and merge once CI passes.
4. Make a release in this github repo and wait for CI to upload wheels.
5. Download the wheels using `./download_wheels.sh <name-of-tag>`.
6. Optionally test the wheels.
7. Upload the wheels using `twine upload dist`.

#### Building for new python versions and cuda versions

1. Copy the migration file for python/cuda from [conda-forge/openmm-feedstock](https://github.com/conda-forge/openmm-feedstock)
   For eg: [python 3.12 migration](https://github.com/conda-forge/openmm-feedstock/blob/ce7e3376d2dfb1033460093daf8e324f8169d486/.ci_support/migrations/python312.yaml)
2. Run `./rerender.sh`.
