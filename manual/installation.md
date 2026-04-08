---
title: Installation
layout: linear
parent: Manual
nav_order: 1
redirect_from:
  - /getting-started/
  - /getting-started.html
---

# Installation
{: .no_toc }

This page walks you through installing ProofFrog on your computer, verifying the installation, and obtaining the example files. No prior command-line experience is assumed.

- TOC
{:toc}

## Prerequisites

ProofFrog requires **Python 3.11 or newer**.

To check whether Python is already installed and which version you have, open a terminal and run:

```bash
python3 --version
```

You should see output like `Python 3.11.9` or `Python 3.12.3`. Any version 3.11 or higher is fine. If the command is not found, or the version is older than 3.11, install Python using the instructions for your operating system below.

### macOS

The recommended approach is to use [Homebrew](https://brew.sh/). If you have Homebrew installed, run:

```bash
brew install python3
# If you want to install a specific version of Python:
# brew install python@3.11
```

Alternatively, download the macOS installer from [python.org/downloads](https://www.python.org/downloads/) and follow the prompts. After installing, open a new terminal window and run `python3 --version` to confirm.

### Windows

Download the installer from [python.org/downloads](https://www.python.org/downloads/). Run it, and on the first screen of the installer, make sure to check the box labelled **"Add Python to PATH"** before clicking Install Now. This step is easy to miss and is the most common cause of `python3` not being recognized in a new terminal after installation.

After the installer finishes, open a new Command Prompt or PowerShell window and run `python3 --version` to confirm.

### Linux

Use your distribution's package manager:

- **Debian/Ubuntu:**
  ```bash
  sudo apt install python3 python3-venv python3-pip
  ```
- **Fedora:**
  ```bash
  sudo dnf install python3 python3-pip
  ```
- **Arch Linux:**
  ```bash
  sudo pacman -S python python-pip
  ```

After installing, run `python3 --version` to confirm.

## Install ProofFrog with pip

The recommended way to install ProofFrog is from [PyPI](https://pypi.org/project/proof-frog/) using `pip`. It is best practice to install it inside a **virtual environment**, which keeps ProofFrog and its dependencies isolated from other Python projects on your system.

**Step 1.** Create a virtual environment in a directory of your choice. The command below creates one called `.venv` in your current directory:

```bash
python3 -m venv .venv
```

**Step 2.** Activate the virtual environment. The command depends on your shell:

- bash or zsh (macOS/Linux default):
  ```bash
  source .venv/bin/activate
  ```
- fish:
  ```fish
  source .venv/bin/activate.fish
  ```
- Windows PowerShell:
  ```powershell
  .venv\Scripts\Activate.ps1
  ```

> On a fresh Windows install, PowerShell's default execution policy blocks running `.ps1` scripts. To allow it, run the following once in PowerShell — this only needs to be done once per user account and does not require administrator privileges:
>
> ~~~powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ~~~
{: .warning }

Once activated, your prompt will show the name of the environment (e.g., `(.venv)`).

{: .important }
**You must activate the virtual environment every time you open a new terminal before using ProofFrog.** If you see `command not found: proof_frog` later on, this is almost always the reason — just re-run the activation command above for your shell.

**Step 3.** Install ProofFrog:

```bash
pip install proof_frog
```

{: .note }
The virtual environment ensures that ProofFrog's dependencies do not conflict with other Python packages you have installed, and makes it straightforward to uninstall ProofFrog completely by simply deleting the `.venv` directory.

## Verify your ProofFrog installation

To confirm that ProofFrog installed correctly, run:

```bash
proof_frog version
```

You should see a version number printed to the terminal, such as `ProofFrog 0.4.0` or `ProofFrog 0.4.0.dev0` on development builds.

### Troubleshooting: "command not found"

If you see a `command not found` error (or similar), the most likely causes are:

- **The virtual environment is not activated.** Run the `source .venv/bin/activate` command (or the equivalent for your shell, as shown above) and try again.
- **`pip install` used a different Python.** If you have multiple Python installations, `pip` may have installed `proof_frog` into one that is not on your PATH. Make sure you created and activated the virtual environment using the same `python3` that meets the version requirement, then re-run `pip install proof_frog` inside the activated environment.
- **PATH is not configured correctly on Windows.** If you did not check "Add Python to PATH" during installation, Python's scripts directory will not be on your PATH. Re-running the installer and checking that box, or adding the scripts directory to your PATH manually, will resolve this.

{: .warning }
Do not use `sudo pip install` to work around a `command not found` error. Installing packages system-wide with `sudo` can interfere with your operating system's own Python packages. Use a virtual environment instead.

## Get the examples

ProofFrog has a companion repository of example proof files. To download it, run:

```bash
git clone https://github.com/ProofFrog/examples
```

This creates an `examples/` directory in your current location containing primitives, schemes, games, and proofs from introductory cryptography.

{: .note }
If you do not have git installed, you can download the examples as a ZIP file from GitHub: go to [github.com/ProofFrog/examples](https://github.com/ProofFrog/examples), click the green **Code** button, and choose **Download ZIP**.

## First run

You are ready for [Tutorial Part 1: Hello Frog]({% link manual/tutorial/hello-frog.md %}).

## For developers and advanced users: installing from source

If you want to contribute to ProofFrog or work with the latest development version, install from source:

```bash
git clone https://github.com/ProofFrog/ProofFrog
cd ProofFrog
git submodule update --init
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
```

The `-e` flag installs the package in editable mode, so changes to the source files take effect immediately without reinstalling. See the [GitHub README](https://github.com/ProofFrog/ProofFrog#readme) for the full development setup guide, including how to run the test suite.
