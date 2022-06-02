# Kraken
Shell script to easy install and use reconnaissance tools
Complete shell script tool for Bug bounty or Pentest ! It will save 90% of your time when setting up your machine to work.
It already configures all the tools for you to work, you won't need to configure it manually.


1. (Installation)[#installation]
  1. (Minimal installation)[#minimal-installation]
  2. (Full installation)[#full-installation]
2. (Usage)[#usage]
  1. (Simple usage)[simple-usage]
  2. (Parameters options)[#parameters-options]

## Installation
Run as root
### Minimal installation
through git
```sh
git clone https://github.com/NRZCode/kraken
sudo kraken/install.sh httpx anonsurf assetfinder findomain subfinder aquatone dirsearch feroxbuster
```
or through curl
```sh
curl -sL https://github.com/NRZCode/kraken/raw/master/install.sh | sudo bash -s httpx anonsurf assetfinder findomain subfinder aquatone dirsearch feroxbuster
```
### Full installation
through git
```sh
git clone https://github.com/NRZCode/kraken
sudo kraken/install.sh
```
or through curl
```sh
curl -sL https://github.com/NRZCode/kraken/raw/master/install.sh | sudo bash
```
## Usage
### Reconnaissance Tools
Simple and fast recon
```sh
kraken -f -d domain.com
```
### Parameters
