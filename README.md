# AWAvenue-Custom Ads Rule（秋风定制增强版去广告规则）

基于开源 [秋风广告规则 AWAvenue-Ads-Rule](https://github.com/TG-Twilight/AWAvenue-Ads-Rule)（Quantumult X 版），
在其 902 条基础上，通过作者日常**抓包持续追加广告域名**，形成个人定制的去广告列表。

- **格式**：Quantumult X 规则格式（`DOMAIN` / `DOMAIN-SUFFIX` / `DOMAIN-KEYWORD` + `reject`）
- **原理**：网络层拦截广告 SDK 与服务器的通信，阻止广告加载（摇一摇广告、开屏广告、订阅号广告流等）
- **更新方式**：GitHub 托管，Quantumult X 订阅后自动/手动更新

## 订阅地址

主地址（GitHub Raw，国内需代理）：

```
https://raw.githubusercontent.com/OnCreat98/AWAvenue-Custom-Ads-Rule/main/AWAvenue-Custom-Ads-Rule.list
```

备用地址（jsDelivr CDN，国内可直连，更新有缓存延迟）：

```
https://cdn.jsdelivr.net/gh/OnCreat98/AWAvenue-Custom-Ads-Rule@main/AWAvenue-Custom-Ads-Rule.list
```

> 仓库：https://github.com/OnCreat98/AWAvenue-Custom-Ads-Rule

## 复写配置（拦截融合在业务域名上的广告 API）

部分 App（如网易云音乐）把广告 API 融合在核心业务域名（`interface3.music.163.com`）上，
域名级拦截会误伤正常功能，需要**复写（Rewrite）**按 URL 路径精确拦截。

**复写订阅地址**：
```
https://raw.githubusercontent.com/OnCreat98/AWAvenue-Custom-Ads-Rule/main/AWAvenue-Custom-Rewrite.conf
```

> ⚠️ **复写生效的前提：必须开启 MITM**
>
> Quantumult X → **设置 → MitM** → 打开 MitM 开关 →「生成证书」→「安装证书」，
> 再到 iOS「设置 → 通用 → VPN与设备管理」安装描述文件，最后在
> 「设置 → 通用 → 关于本机 → 证书信任设置」中**信任该证书**。
>
> 未开启 MITM 时复写规则不会生效，而且**规则列表不会报任何错**，
> 很容易误判成"规则没用"。

**Quantumult X 添加复写**：
1. 打开 Quantumult X → 右下角 **引用（资源）** → **+**
2. 类型选 **复写（Rewrite）**，填入上面的复写订阅地址
3. 保存后点 **下载/更新** 拉取

> ⚠️ 若之前添加过旧版复写并报 `Invalid Line [rewrite_local]`：先**删除该资源**，再重新
> 添加上面的地址并更新（旧版已被解析缓存，需重建）。远程复写文件不含段头，
> 仅规则行 + `#` 注释。

已内置拦截：

- 网易云音乐开屏广告的竞价/获取/配置/曝光上报 4 个 API 路径
- 花生日记自营广告/运营活动接口（仅拦广告路径，不影响核心业务）
- **哔哩哔哩**：开屏广告（`/x/v2/splash/*`）、弹幕广告（`/x/v2/dm/ad`）、首页右上角活动入口、漫画开屏（`manga` twirp）
- **红果短剧 / 番茄小说（字节系）**：融合广告 API（`snssdk.com/api/ad/*`）、广告安装包分发（`gurd.snssdk.com`）、广告素材图片（`pglstatp-toutiao` / `pstatp` 的 `obj|img/ad*` 路径）

### ⚠️ 复写生效还需：把主机加入 MitM 名单

复写只在 MitM 解密范围内生效，请在 QX 主配置的 `[mitm]` 的 `hostname` 中**追加**（不要覆盖已有的）：

```
app.bilibili.com, api.bilibili.com, api.vc.bilibili.com, manga.bilibili.com,
gurd.snssdk.com, *.pglstatp-toutiao.com, *.pstatp.com, *.pangolin-sdk-toutiao.com
```

- `app.bilibili.com` 走 **HTTP/2**，必须在 QX 中打开 **「MitM over HTTP/2」**，否则 B 站复写不生效且不报错。
- **故意没有把 `i.snssdk.com` / `mcs.snssdk.com` 放进 MitM**：抖音/头条系对自有域名有证书固定（pinning），解密失败会让这些 App 的网络整段异常。对应的 `/api/ad/` 复写规则仍然保留（对未做 pinning 的场景生效），但不建议为它开 MitM。
- 如需按域名拦截而非复写，规则列表已包含字节系广告域；列表与复写互不冲突。

> 复写正则均以 `(\?|$)` 结尾锚定，只匹配目标路径本身（可带 query 参数），
> 避免把 `/ad/getXXX` 这类同前缀的正常接口一起拦掉。

### 为什么哔哩哔哩只能靠复写（实测结论）

对 B站 APK 8.91.1 做静态分析（`unzip` 取 dex → `strings`）得到：

- **App 内没有任何三方广告 SDK**：穿山甲 `com.bytedance.sdk.openadsdk`、优量汇 `com.qq.e.ads`、
  快手 `com.kwad.sdk`、百度 `com.baidu.mobads` 命中均为 **0 次**；而自家 `com.bilibili.ad.*` 命中 **520 次**。
- 广告与业务**同域名**：App 内置主机 `app.bilibili.com`(140 处)、`api.bilibili.com`(157 处)。
- 广告字段：`card_type` / `ad_info` / `is_ad` / `ad_web_s` / `cm_v2` 均存在于 dex 中。

→ 结论：**给 B站加广告域名白忙**（没有独立的广告域名可拦），只有两条路有效：
① 复写按路径拦（本仓库已做，覆盖开屏/弹幕/活动入口/漫画）；
② 首页信息流用响应体脚本按 `card_type=="cm_v2"` / `ad_info` 过滤（本仓库以注释形式给出，默认关闭）。
唯一有效的域名级条目是商业化域 `cm.bilibili.com`（App 内引用 27 处），列表里已有。

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
   只想预览、不写文件不提交：
   ```bash
   bash update_rules.sh --dry-run <新域名.txt>
   ```
3. 脚本自动：提取主域名 → 去重（已有则跳过）→ 追加规则 → 更新版本号/时间/总条数 → 提交并推送至 GitHub

> **跨平台**：macOS（BSD 工具链）与 Linux（GNU 工具链）均可运行。
>
> **推送代理**：默认自动探测本地 `127.0.0.1:7897`；也可显式指定
> `GIT_PROXY=http://127.0.0.1:7897 bash update_rules.sh <新域名.txt>`。
>
> **失败安全**：脚本采用「临时文件生成 → 校验 → 原子替换」流程。任何一步失败
> （例如头部版本号写不进去）都不会改动原规则文件，不会留下"规则已追加、
> 版本号却没更新"的半成品状态。

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

## 已知误杀风险域名

以下域名来自上游规则，**默认保留**。若遇到对应功能异常，优先从这里排查或移除：

| 域名 | 说明 | 风险 |
|------|------|------|
| `data.hicloud.com`（DOMAIN-SUFFIX） | 华为设备数据通道 | 后缀级拦截范围偏大，可能影响华为设备功能 |
| `grs.hicloud.com` | 华为 GRS 服务 | 可能影响华为设备联网/升级 |
| `api.installer.xiaomi.com` | 小米应用安装器 | 可能影响应用商店安装校验 |
| `o2o.api.xiaomi.com` | 小米生活服务 | 可能影响小米生活服务相关功能 |
| `metrics.icloud.com`、`securemetrics.apple.com` | Apple 诊断上报 | 一般无感，异常时排查 |
| `a.market.xiaomi.com`（SUFFIX）、`t1/t2/t3.a.market.xiaomi.com` | 小米应用商店统计 | 一般无感 |

### 2026-09-22 新增条目（红果短剧/番茄系逆向补充）

| 域名 | 说明 | 风险 |
|------|------|------|
| `activity-ag.awemeughun.com` | 字节激励/活动聚合（红果「金币任务/看剧赚钱」同类链路） | **中**：金币任务打不开先移除这条 |
| `sf3-ttcdn-tos.pstatp.com` | 广告素材 TOS 桶 | 低 |
| `p3/p6/p9-ad-sign.byteimg.com` | 广告素材签名专用 | 低（**注意别与 `p*-novel.byteimg.com` 混淆，后者是封面图床，已明确不拦**） |
| `msync-im1-vip6-std.easemob.com`、`api.iegadp.qq.com`、`adim.pinduoduo.com`、`shark-tracer.netease.com`、`mktm.jd.com`、`activity-zhendingtech.com` | 第三方广告 SDK 回调/上报 | 低：若某 App 登录/支付异常先查这几条 |

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
