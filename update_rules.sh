#!/usr/bin/env bash
# ============================================================
#  AWAvenue-Custom-Ads-Rule 规则更新脚本
#  跨平台: macOS (BSD 工具链) / Linux (GNU 工具链) 均可运行
#
#  用法:
#    bash update_rules.sh <domains.txt>
#        domains.txt 每行一个域名或完整 URL，脚本自动提取主域名
#    echo "ad.example.com" | bash update_rules.sh -
#    bash update_rules.sh --dry-run <domains.txt>    # 只预览，不写文件不提交
#
#  环境变量:
#    GIT_PROXY=http://127.0.0.1:7897   推送时使用的代理
#                                      (不设则自动探测本地 7897 端口)
#
#  功能:
#    1. 从输入中提取域名(兼容 URL/hosts 行/纯域名/带端口)
#    2. 与现有规则精确去重(已有则跳过)
#    3. 追加到规则文件, 更新头部 Version / Update time / Total lines
#    4. git add + commit + push 到 GitHub
#
#  失败安全: 先在临时文件里完成全部修改并校验，通过后才原子替换原文件。
#           任何一步失败都不会留下「规则已追加但版本号没更新」的半成品。
# ============================================================
set -euo pipefail

RULE_FILE="$(cd "$(dirname "$0")" && pwd)/AWAvenue-Custom-Ads-Rule.list"
TZ_CN="Asia/Shanghai"
DEFAULT_PROXY="http://127.0.0.1:7897"

# ---------- 0. 参数解析 ----------
DRY_RUN=0
ARGS=()
for a in "$@"; do
  case "$a" in
    --dry-run|-n) DRY_RUN=1 ;;
    *) ARGS+=("$a") ;;
  esac
done
INPUT="${ARGS[0]:--}"

[[ -f "$RULE_FILE" ]] || { echo "错误: 找不到规则文件 $RULE_FILE"; exit 1; }

if [[ "$INPUT" == "-" ]]; then
  INPUT_FILE="$(mktemp)"
  cat > "$INPUT_FILE"
else
  INPUT_FILE="$INPUT"
  [[ -f "$INPUT_FILE" ]] || { echo "错误: 找不到文件 $INPUT_FILE"; exit 1; }
fi

# ---------- 临时文件 & 清理 ----------
TMP_EXTRACT="$(mktemp)"
TMP_MERGED="$(mktemp)"
TMP_EXIST="$(mktemp)"
TMP_NEW="$(mktemp)"
cleanup() {
  # 变量兜底: 提前退出时某些变量可能尚未赋值(set -u 下用 :- 保护)
  rm -f "${TMP_EXTRACT:-}" "${TMP_MERGED:-}" "${TMP_EXIST:-}" "${TMP_NEW:-}"
}
trap cleanup EXIT

# ---------- 跨平台 sed 原地编辑 ----------
# macOS 的 BSD sed 需要 `sed -i ''`, GNU sed 用 `sed -i`
# (BSD sed 会把 `-i -e` 里的 -e 当成备份后缀, 生成 xxx-e 垃圾文件)
sed_i() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# ---------- 1. 提取域名 ----------
# 兼容格式: 纯域名 / http(s)://域名/路径 / "0.0.0.0 域名" / "127.0.0.1 域名" / [IPv6]
# 注意: 必须用管道 | 串联, 让每一步都作用上一步的输出
sed -E \
  -e 's/^[[:space:]]+//; s/[[:space:]]+$//' \
  -e 's/^(0\.0\.0\.0|127\.0\.0\.1|::1|::)[[:space:]]+//I' \
  -e 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##' \
  -e 's#^[^@/]+@##' \
  -e 's#[/?#].*$##' \
  -e 's/:[0-9]+$//' \
  -e 's/^\[([0-9a-fA-F:]+)\].*$/\1/' \
  "$INPUT_FILE" \
| tr 'A-Z' 'a-z' \
| sed -E 's/^[0-9a-fA-F:.]+$//' \
| grep -E '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$' \
| grep -vE '(^|\.)(localhost|local|invalid|test|example)$' \
| sort -u > "$TMP_EXTRACT" || true
# 末尾 || true: 全部输入都无效时 grep 返回 1, 不应让 set -e 直接中断

NEW_COUNT=$(grep -c . "$TMP_EXTRACT" || true)
if [[ "${NEW_COUNT:-0}" -eq 0 ]]; then
  echo "未提取到有效域名,已退出。"
  exit 0
fi
echo "提取到 $NEW_COUNT 个待检查域名:"
cat "$TMP_EXTRACT"

# ---------- 2. 去重 ----------
# 用 awk 精确取出已有域名
# (旧版用 grep -E 拼域名, 域名里的 . 会被当正则通配符, 造成误判跳过)
awk -F, 'tolower($1) ~ /^(domain|domain-suffix|domain-keyword)$/ {print tolower($2)}' \
  "$RULE_FILE" | sort -u > "$TMP_EXIST"

ADDED=0
SKIPPED=0
while IFS= read -r d; do
  [[ -n "$d" ]] || continue
  if grep -Fxq "$d" "$TMP_EXIST"; then
    SKIPPED=$((SKIPPED+1))
    echo "  [跳过-已存在] $d"
  else
    printf 'DOMAIN,%s,reject\n' "$d" >> "$TMP_MERGED"
    printf '%s\n' "$d" >> "$TMP_EXIST"   # 同批次内也去重
    ADDED=$((ADDED+1))
    echo "  [新增] $d"
  fi
done < "$TMP_EXTRACT"

if [[ "$ADDED" -eq 0 ]]; then
  echo "没有需要新增的域名,规则未变化,不提交。"
  exit 0
fi

# ---------- 3. 在临时文件里生成新内容并校验 ----------
cp "$RULE_FILE" "$TMP_NEW"
sort -u "$TMP_MERGED" >> "$TMP_NEW"

TOTAL=$(grep -cE '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD),' "$TMP_NEW" || true)
OLD_VER=$(sed -n 's/^#Version: *\([0-9][0-9]*\).*/\1/p' "$RULE_FILE" | head -1)
VER=$(( ${OLD_VER:-0} + 1 ))
NOW=$(TZ="$TZ_CN" date '+%Y-%m-%d %H:%M:%S UTC+8')

sed_i \
  -e "s/^#Version: .*/#Version: $VER/" \
  -e "s/^#Update time: .*/#Update time: $NOW/" \
  -e "s/^#Total lines: .*/#Total lines: $TOTAL/" \
  "$TMP_NEW"

# 校验通过才替换, 否则原文件保持不变
grep -q "^#Version: $VER$" "$TMP_NEW"       || { echo "错误: 版本号写入失败,原文件未改动,已放弃。"; exit 1; }
grep -q "^#Total lines: $TOTAL$" "$TMP_NEW" || { echo "错误: 总条数写入失败,原文件未改动,已放弃。"; exit 1; }
CHECK_TOTAL=$(grep -cE '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD),' "$TMP_NEW" || true)
[[ "$CHECK_TOTAL" -eq "$TOTAL" ]] || { echo "错误: 规则条数校验不一致($CHECK_TOTAL != $TOTAL),已放弃。"; exit 1; }

echo ""
echo "========== 更新预览 =========="
echo "新增: $ADDED 条 | 已存在跳过: $SKIPPED 条"
echo "新版本: v$VER | 更新时间: $NOW | 总规则数: $TOTAL"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "(--dry-run) 未写入文件,未提交。"
  exit 0
fi

# 原子替换: mv 在同一文件系统内是原子操作
mv "$TMP_NEW" "$RULE_FILE"
echo "规则文件已更新。"

# ---------- 4. 提交推送 ----------
REPO_DIR="$(dirname "$RULE_FILE")"
if git -C "$REPO_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$REPO_DIR" add AWAvenue-Custom-Ads-Rule.list
  git -C "$REPO_DIR" commit -m "Update: add $ADDED ad domain(s), v$VER, total $TOTAL"

  # 代理: 优先 GIT_PROXY, 否则探测本地默认代理端口
  PROXY="${GIT_PROXY:-}"
  if [[ -z "$PROXY" ]] && nc -z 127.0.0.1 7897 >/dev/null 2>&1; then
    PROXY="$DEFAULT_PROXY"
  fi
  if [[ -n "$PROXY" ]]; then
    echo "推送走代理: $PROXY"
  else
    echo "推送直连(未检测到本地代理)。"
  fi

  # 注意: macOS 自带 bash 3.2 在 set -u 下展开空数组会报 unbound variable,
  # 因此不用数组参数, 直接分支调用
  if [[ -n "$PROXY" ]]; then
    PUSH_OK=0
    git -C "$REPO_DIR" -c "http.proxy=$PROXY" -c "https.proxy=$PROXY" push || PUSH_OK=$?
  else
    PUSH_OK=0
    git -C "$REPO_DIR" push || PUSH_OK=$?
  fi

  if [[ "$PUSH_OK" -eq 0 ]]; then
    echo "已提交并推送至 GitHub。"
  else
    echo "警告: 已本地提交,但推送失败。请检查网络/代理/凭证后手动执行:"
    echo "  GIT_PROXY=http://127.0.0.1:7897 git -C \"$REPO_DIR\" push"
    exit 1
  fi
else
  echo "警告: 当前目录不是 git 仓库,跳过提交推送。请手动处理。"
fi
