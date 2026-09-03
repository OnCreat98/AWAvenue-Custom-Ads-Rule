# AWAvenue-Custom Ads Rule（秋风定制增强版去广告规则）

基于开源 [秋风广告规则 AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule)（Quantumult X 版），
在其 902 条基础上，通过作者日常**抓包持续追加广告域名**，形成个人定制的去广告列表。

- **格式**：Quantumult X 规则格式（`DOMAIN` / `DOMAIN-SUFFIX` / `DOMAIN-KEYWORD` + `reject`）
- **原理**：网络层拦截广告 SDK 与服务器的通信，阻止广告加载（摇一摇广告、开屏广告、订阅号广告流等）
- **更新方式**：Gitee 托管，Quantumult X 订阅后自动/手动更新

## 订阅地址

```
https://gitee.com/z17682156415/AWAvenue-Custom-Ads-Rule/raw/master/AWAvenue-Custom-Ads-Rule.list
```

> `z17682156415` 和 `AWAvenue-Custom-Ads-Rule` 是占位符，仓库创建后替换为真实值。

## Quantumult X 使用步骤

1. 打开 Quantumult X → 右下角 **引用（资源）** → 点击 **+**
2. 类型选 **规则**，填入上面的订阅地址
3. 将其分配到一个 `filter_local` / `filter_remote` 过滤策略，动作选 **reject**
4. 在引用页点 **下载/更新** 拉取最新规则
5. 或手动写入配置文件的 `[filter_remote]` 段：
   ```
   https://gitee.com/z17682156415/AWAvenue-Custom-Ads-Rule/raw/master/AWAvenue-Custom-Ads-Rule.list, tag=AWAvenue-Custom, enabled=true
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
3. 脚本自动：提取主域名 → 去重（已有则跳过）→ 追加规则 → 更新版本号/时间/总条数 → 提交并推送至 Gitee

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
| `update_rules.sh` | 更新脚本：追加域名 + 版本管理 + 推送 |
| `temp/` | 临时文件（下载的原始规则、测试数据） |

## 注意

- 若误拦正常业务域名（误杀），可将该域名从规则中移除或反馈。
- 规则基于抓包数据为个人定制，公开分享请自行评估。
