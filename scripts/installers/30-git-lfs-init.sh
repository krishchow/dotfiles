DESCRIPTION="git-lfs hooks"
check() { git lfs version &>/dev/null && git config --global --get filter.lfs.required &>/dev/null; }
install() { git lfs install; }
