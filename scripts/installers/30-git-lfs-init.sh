DESCRIPTION="git-lfs hooks"
REQUIRED_COMMANDS="git-lfs"
check() { git lfs version &>/dev/null && git config --global --get filter.lfs.required &>/dev/null; }
install() { git lfs install; }
