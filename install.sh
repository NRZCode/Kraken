#!/usr/bin/env bash
dirname=${BASH_SOURCE%/*}
bindir="/usr/local/bin"
mkdir -p "$dir"
if [[ "$dir" != @(${PATH//:/|}) ]] && ! grep ".local/bin" $HOME/.profile; then
  cat <<EOF >> $HOME/.profile

# set PATH so it includes user's private bin if it exists
if [ -d "\$HOME/.local/bin" ] ; then
    PATH="\$HOME/.local/bin:\$PATH"
fi
EOF
fi
ln -sf "$dirname/ghostrecon.sh" "$bindir/ghostrecon"

cat <<EOT
Execute o seguinte comando para instalar todas as ferramentas através do arno script
  wget -qO- https://github.com/NRZCode/arno/raw/main/install.sh | sudo bash
EOT
