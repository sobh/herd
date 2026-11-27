# herd: provision my machines with plain shell

An automated configuration script for Unix-like operating systems.

## Objectives

1. KISS. Be as simple as it could be.
2. Portability. Target multiple Unix-like systems, namely Arch, Void, and
   OpenBSD. Additionally, it should be trivial to add support for other unices.
3. Idempotence. Why use Ansible, when you can use a simple shell script?
4. Autonomy. The script should run with minimal user interaction.

## Documentation

See [docs](docs/index.md) for running the bootstrap, the package table,
provisioning scripts, and how herd compares to Ansible.
