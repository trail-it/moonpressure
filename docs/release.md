# 本地交付记录

项目：MoonPressure 0.1.0。更新日期：2026-10-18。状态：本地就绪，未公开发布。临时模块名 `local/moonpressure`；GitHub owner/repo、Git 真实 author/committer、Mooncakes 登录/namespace、正式链接待指定。本地提交的中性身份只用于保留真实开发阶段。

## 已交付

纯 MoonBit cgroup v2/PSI 解析、父级共享内存余量与 CPU quota 上界、快照身份及计数器差分检查、带滞回的准入建议、版本化 JSON、Linux native 只读采集、synthetic replay、测试和申报草稿。C 桥仅提供读取/stat/时钟/sleep。

## 本地证据

|范围|结果|记录|
|---|---|---|
|Windows wasm / wasm-gc / js|各 18 项库/文档测试；check/build deny-warn；格式通过|test-evidence/windows-core-2026-10-18.json|
|Linux wasm / wasm-gc / js / native|各 18 项库/文档测试；check/build deny-warn；格式通过|test-evidence/linux-core-2026-10-18.json|
|synthetic replay|每后端 5 个区间，独立手算 oracle 与跨后端比较一致|scripts/verify_replay.py|
|10/15 Linux 真实采集|三次观察/两个区间，独立 raw-text oracle 对预算/指标/差分核对通过|test-evidence/linux.json|
|实际本地归档消费者|独立 workspace 增加 1 项 API 测试；Linux 从解包源码编译 C 并读真实 cgroup|test-evidence/linux-consumer.json|

本轮消费者工具输出 19 tests，即依赖库/文档 18 + 消费者 1；不能将其宣称为 19 项新增库测试。10/15 的16项基线记录保留，未倒改旧测试结果。源码功能检查与归档消费是不同证据，均不等于公开 registry 安装。

实测工具链：moon 0.1.20261012 (748b63c 2026-10-12)、moonc v0.10.15+943464bfa、moonrun 0.1.20261012。Windows 使用项目忽略目录中的匹配工具链，Linux 使用已准备好的同版工具链。工具链与缓存不分发。CI 使用官方安装器的滚动版本并记录实际版本；尚未在远端执行，不把本地验证称为 CI 成功。

本地真实内核为 Linux 7.0.0-38-generic，不把 synthetic 情景冒充实际资源压力。没有写内核控制文件、制造真实 OOM 或对服务施加压力。读取/cgroup 身份与内存预算的局限见 README。

## 归档与分发

`moon package` 生成 `_build/publish/local-moonpressure-0.1.0.zip`；`scripts/verify_package.py` 检查实际 zip 文件清单、必要 C 桥和接口，并解包到隔离 workspace 消费。私有目录 research/release-local/demo-output、工具链、构建目录、Git 元数据与 PDF 不入库归档。实际文件数及消费者结果保留在 test-evidence/package.json；它记录本地档案，不是上传记录。

GitHub 的拟分发内容额外包含 CI 配置与本地申报 PDF。已检查跟踪清单、暂存差异与本地历史：无原始主机采样、凭据文件、SSH 配置、本机工具链或其他项目文件。针对实际文本扫描私钥/token 模式，范围与限制保留在脱敏交付记录；这不等于保证检出所有秘密。

## 后续发布阶段

后续由用户指定逐项目发布目标和真实身份后，再修改临时 module 名、核对 author/committer 与 namespace、创建/推送仓库、运行在线 CI、发布唯一版本、从 registry 安装确切版本并实调 C 桥。当前未创建远程仓库、推送、发包、OAuth 或填写报名。公开开发历史不能追溯伪造；人工理解和正式报名信息也仍待本人确认。

## 2026-10-18 完善

补读 sysinfo@0.1.6 和 subproc@0.3.0 发布源码，明确已有 cgroup 内存能力；更新能力矩阵和独立贡献说明。添加 docs/participant-guide.md、两项准入恢复回归，并同步申报正文/PDF。软件功能及0.1.0 API保持不变，未发布的新版本不为增加提交数扩展功能。真实公开开发与参赛者理解仍由实际记录确认。
