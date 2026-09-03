#!/usr/bin/env bash
# ============================================================
#  AWAvenue-Custom-Ads-Rule 规则更新脚本
#  用法:
#    bash update_rules.sh <domains.txt>
#        domains.txt 每行一个域名或完整 URL，脚本自动提取主域名
#    或
#    echo "ad.example.com" | bash update_rules.sh -
#  功能:
#    1. 从输入中提取域名(兼容 URL/hosts 行/纯域名/带端口)
#    2. 与现有规则去重
#    3. 追加到规则文件, 更新头部 Version / Update time / Total lines
#    4. git add + commit + push 到 Gitee
# ============================================================
set -euo pipefail

RULE_FILE="$(dirname "$0")/AWAvenue-Custom-Ads-Rule.list"
INPUT="${1:--}"

if [[ "$INPUT" == "-" ]]; then
  INPUT_FILE="$(mktemp)"
  cat > "$INPUT_FILE"
else
  INPUT_FILE="$INPUT"
  [[ -f "$INPUT_FILE" ]] || { echo "错误: 找不到文件 $INPUT_FILE"; exit 1; }
fi

TMP_EXTRACT="$(mktemp)"
trap 'rm -f "$TMP_EXTRACT" "$TMP_MERGED"' EXIT

# ---------- 1. 提取域名 ----------
# 兼容格式: 纯域名 / http(s)://域名/路径 / "0.0.0.0 域名" / "127.0.0.1 域名"
sed -E \
  -e 's/^[[:space:]]+//; s/[[:space:]]+$//' \
  -e 's/^(0\.0\.0\.0|127\.0\.0\.1|::1|::)[[:space:]]+//I' \
  -e 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##' \
  -e 's#^[^@/]+@##' \
  -e 's#[/?#].*$##' \
  -e 's/:[0-9]+$//' `# 剥离末尾端口 :8080` \
  -e 's/^\[([0-9a-fA-F:]+)\].*$/\1/' \
  "$INPUT_FILE" \
| tr 'A-Z' 'a-z' \
| sed -E 's/^[0-9a-fA-F:.]+$//' `# 丢弃纯 IP(IPv4/IPv6)` \
| grep -E '^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$' \
| grep -vE '(^|\.)(localhost|local|invalid|test|example)$' \
| sort -u > "$TMP_EXTRACT"

NEW_COUNT=$(wc -l < "$TMP_EXTRACT")
[[ "$NEW_COUNT" -gt 0 ]] || { echo "未提取到有效域名，已退出。"; exit 0; }
echo "提取到 $NEW_COUNT 个待检查域名:"
cat "$TMP_EXTRACT"

# ---------- 2. 去重 ----------
TMP_MERGED="$(mktemp)"
ADDED=0
SKIPPED=0
while IFS= read -r d; do
  if grep -qiE "^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD),${d}(,|$)" "$RULE_FILE"; then
    SKIPPED=$((SKIPPED+1))
    echo "  [跳过-已存在] $d"
  else
    printf 'DOMAIN,%s,reject\n' "$d" >> "$TMP_MERGED"
    ADDED=$((ADDED+1))
    echo "  [新增] $d"
  fi
done < "$TMP_EXTRACT"

if [[ "$ADDED" -eq 0 ]]; then
  echo "没有需要新增的域名，规则未变化，不提交。"
  exit 0
fi

# ---------- 3. 追加规则 & 更新头部 ----------
sort -u "$TMP_MERGED" >> "$RULE_FILE"

TOTAL=$(grep -cE '^(DOMAIN|DOMAIN-SUFFIX|DOMAIN-KEYWORD),' "$RULE_FILE")
VER=$(( $(grep -oP '(?<=^#Version: )[0-9]+' "$RULE_FILE") + 1 ))
NOW=$(date '+%Y-%m-%d %H:%M:%S UTC+8')

sed -i \
  -e "s/^#Version: .*/#Version: $VER/" \
  -e "s/^#Update time: .*/#Update time: $NOW/" \
  -e "s/^#Total lines: .*/#Total lines: $TOTAL/" \
  "$RULE_FILE"

echo ""
echo "========== 更新完成 =========="
echo "新增: $ADDED 条 | 已存在跳过: $SKIPPED 条"
echo "新版本: v$VER | 更新时间: $NOW | 总规则数: $TOTAL"

# ---------- 4. 提交推送 ----------
if git -C "$(dirname "$RULE_FILE")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git -C "$(dirname "$RULE_FILE")" add AWAvenue-Custom-Ads-Rule.list
  git -C "$(dirname "$RULE_FILE")" commit -m "Update: add $ADDED ad domain(s), v$VER, total $TOTAL"
  git -C "$(dirname "$RULE_FILE")" push
  echo "已提交并推送至 Gitee。"
else
  echo "警告: 当前目录不是 git 仓库，跳过提交推送。请手动处理。"
fi
