#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
if zsh ./scripts/install.sh; then
  print "Installation finished. / 安装完成。"
else
  print -u2 "Installation failed. Check the error above. / 安装失败，请检查上方错误。"
fi
read "reply?Press Return to close / 按回车关闭："
