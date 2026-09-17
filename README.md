# AWAvenue-Custom Ads Rule（秋风定制增强版去广告规则）

基于开源 [秋风广告规则 AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule)（Quantumult X 版），
在其 902 条基础上，通过作者日常**抓包持续追加广告域名**，形成个人定制的去广告列表。

- **格式**：Quantumult X 规则格式（`DOMAIN` / `DOMAIN-SUFFIX` / `DOMAIN-KEYWORD` + `reject`）
- **原理**：网络层拦截广告 SDK 与服务器的通信，阻止广告加载（摇一摇广告、开屏广告、订阅号广告流等）
- **更新方式**：GitHub 托管，Quantumult X 订阅后自动/手动更新

## 订阅地址

```
https://raw.githubusercontent.com/OnCreat98/AWAvenue-Custom-Ads-Rule/main/AWAvenue-Custom-Ads-Rule.list
```

> 仓库：https://github.com/OnCreat98/AWAvenue-Custom-Ads-Rule

## 复写配置（拦截融合在业务域名上的广告 API）

部分 App（如网易云音乐）把广告 API 融合在核心业务域名（`interface3.music.163.com`）上，
域名级拦截会误伤正常功能，需要**复写（Rewrite）**按 URL 路径精确拦截。

**复写订阅地址**：
```
https://raw.githubusercontent.com/OnCreat98/AWAvenue-Custom-Ads-Rule/main/AWAvenue-Custom-Rewrite.conf
```

**Quantumult X 添加复写**：
1. 打开 Quantumult X → 右下角 **引用（资源）** → **+**
2. 类型选 **复写（Rewrite）**，填入上面的复写订阅地址
3. 保存后点 **下载/更新** 拉取

> ⚠️ 若之前添加过旧版复写并报 `Invalid Line [rewrite_local]`：先**删除该资源**，再重新
> 添加上面的地址并更新（旧版已被解析缓存，需重建）。远程复写文件不含段头，
> 仅规则行 + `#` 注释。

已内置拦截：网易云音乐开屏广告的竞价/获取/配置/曝光上报 4 个 API 路径。

## Quantumult X 使用步骤

1. 打开 Quantumult X → 右下角 **引用（资源）** → 点击 **+**
2. 类型选 **规则**，填入上面的订阅地址
3. 将其分配到一个 `filter_local` / `filter_remote` 过滤策略，动作选 **reject**
4. 在引用页点 **下载/更新** 拉取最新规则
5. 或手动写入配置文件的 `[filter_remote]` 段：
   ```
   https://raw.githubusercontent.com/OnCreat98/AWAvenue-Custom-Ads-Rule/main/AWAvenue-Custom-Ads-Rule.list, tag=AWAvenue-Custom, enabled=true
   ```

## 更新流程（维护者用）

每次抓包发现新广告域名后：

1. 准备一个纯文本文件，每行一个**域名或 URL**（兼容格式见下）
2. 执行更新脚本：
   ```bash
   bash update_rules.sh <新域名.txt>
   ```
   或管道输入：
   ```bash
   echo "ad.example.com" | bash update_rules.sh -
   ```
3. 脚本自动：提取主域名 → 去重（已有则跳过）→ 追加规则 → 更新版本号/时间/总条数 → 提交并推送至 GitHub

### 抓包输入兼容格式

```
# 纯域名
ad.example.com
# 完整 URL
https://ad.sdk.com/path?foo=bar
# 带端口
tracker.evil.cn:8080
# hosts 行
0.0.0.0 ads.spammy.net
127.0.0.1 tracker.xxx.com
```

无效项（纯 IP、localhost、local、example 等）会被自动过滤。

## 文件说明

| 文件 | 说明 |
|------|------|
| `AWAvenue-Custom-Ads-Rule.list` | 主规则文件，Quantumult X 订阅此文件 |
| `AWAvenue-Custom-Rewrite.conf` | 复写配置，拦截融合在业务域名上的广告 API（如网易云开屏） |
| `update_rules.sh` | 更新脚本：追加域名 + 版本管理 + 推送 |
| `temp/` | 临时文件（下载的原始规则、测试数据） |

## 注意

- 若误拦正常业务域名（误杀），可将该域名从规则中移除或反馈。
- 规则基于抓包数据为个人定制，公开分享请自行评估。
