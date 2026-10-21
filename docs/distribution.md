# 发布清单与身份

2026-10-18，用户授权将本项目以 trail-it 身份发布至 GitHub 和 Mooncakes。

|渠道|保留内容|排除内容|
|---|---|---|
|GitHub：trail-it/moonpressure|MoonBit 源码/公开接口、必要 C 桥、测试、示例、说明、来源/许可、脱敏验证摘要、CI 配置、一页申报 PDF|credentials.json/.env、OAuth/token、SSH 配置、原始主机采样、原始网页与 registry 镜像、第三方源码下载、本地工具链/构建产物/消费者、发布辅助脚本和私有台账|
|Mooncakes：trail-it/moonpressure|实际运行/编译所需源码、C 桥、manifest、接口、测试/示例及轻量文档和许可|上述全部私有内容，另排除 .git/.github、output/ 下 PDF 和大附件、本地环境切换脚本|

Git 的上传范围按真实跟踪清单及可达历史检查；Mooncakes 按 `.moonignore` 和实际 zip 内容检查，两者不以另一份 ignore 代替。归档检查保留 native/bridge.c 与 native/pkg.generated.mbti，防止包能安装却无法原生使用。

仓库 owner、此次 GitHub 上传账号、发布准备提交的 author/committer 均为 trail-it；GitHub API 确认数值 ID 328298658，提交使用其官方格式 noreply 地址。此前 Local Development 的本地阶段历史保留原样，不改造日期或把 10 月15日称为公开开发时间。首次公开时间以实际推送/仓库记录为准。

Mooncakes 已核实 CLI 登录身份为 trail-it；浏览器、GitHub CLI、Mooncakes CLI 分别确认。发布结果、默认分支 SHA、CI、注册表版本与独立消费证据见 GitHub 最新 release.md。报名/人工理解确认不由上传自动完成。

0.3.0增加dispatch源码/公开接口、examples/dispatcher/stdio.c、验证脚本和脱敏执行/模型/性能摘要；这些均属公开交付。原始服务器采样、实际cgroup路径、SSH主机别名和发布辅助脚本仍仅留忽略目录。只发布指定摘要，不整体上传demo-output。
