# Ghost Recon
Shell script to easy install and use reconnaissance tools
Complete shell script tool for Bug bounty or Pentest ! It will save 90% of your time when setting up your machine to work.
It already configures all the tools for you to work, you won't need to configure it manually.

> Status: Developing ⚠️

### Tool updates every linux directory and all dependencies needed to work
   - tor, argparse, pyrit, requests, proxychains4, aptitude, Seclists, synaptic, brave, hashcat, docker.io, exploitdb-papers, exploitdb-bin-sploits etc...

### Script to install the most popular tools used when looking for vulnerabilities for a Bug bounty or Pentest bounty program. :shipit:

## Tools

Tools|T|T|T|T|T
-----|-----|-----|-----|-----|-----
Dirsearch|XSStrike|Knockpy|WAFNinja|Bluto|Anon-SMS
Rustscan|The-endorser|Whatweb|Phoneinfoga|Sqlmap-dev|Sayhello
Sublist3r|Twintproject|Wpscan|Zphisher|Parsero|Seeker
SocialFish|Osintgram|Massdns|Git-dumper|Asnlookup|Sherlok
Unfurl|Saycheese|Httprobe|Ngrok|Wfuzz|TheHarvester
Aquatone|ParamSpider|Gau|Assetfinder|Subfinder|Takeover
Httpx|Infoga|Gobuster|Anonsurf|Gittools|Droopescan
Joomscan|Sslyze|Sslscan

### Full installation
#### cURL, wget mode
```sh
curl -L https://github.com/NRZCode/ghostrecon/raw/master/install.sh | sudo bash

# Can install some tools
curl -L https://github.com/NRZCode/ghostrecon/raw/master/install.sh | sudo bash -s tool1 tool2 toolN
```
#### Git mode
```sh
git clone https://github.com/NRZCode/ghostrecon
sudo ghostrecon/install.sh

# Can install some tools
sudo ghostrecon/install.sh tool1 tool2 toolN
```
#### List available tools
```sh
ghostrecon/install.sh --list
```