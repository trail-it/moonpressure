# 交付与发布记录

## 0.2.0 初审后修订（2026-10-21）

新增 `admission` 包：显式层级约束、CPU/内存联合选择、跨分支整组作业、有界精确优化、具体阻塞解释、方案版本检查、整批逻辑预留/释放/预算缩减欠额。原0.1.0诊断API保持兼容。输入关系的成对案例和本期净新增职责见review-response.md。

Windows wasm/wasm-gc/js各30项库/文档测试；格式、deny-warn check/build通过；旧回放与新准入演示均通过独立oracle。每后端66个选择案例及提交/过期/缩额/释放生命周期检查。实际0.2.0归档在独立消费者中通过三后端各2项API测试，工具总计32=依赖库/文档30+消费者2。证据见test-evidence/*2026-10-21.json。

核心冻结提交 `1250a8b24be5c876d6db95af37f01279633c31bc` 的[Linux CI](https://github.com/trail-it/moonpressure/actions/runs/39564913391)已通过四后端测试/选择oracle、真实采集到账本衔接和实际归档消费者。直接Linux测试机本轮连接超时后采用此次CI实测，没有沿用旧版记录。

[Mooncakes 0.2.0](https://mooncakes.io/docs/trail-it/moonpressure@0.2.0) 已由trail-it于2026-10-21 07:56:50 UTC（北京时间15:56:50）发布，registry构建成功。实际上传81文件，SHA-256与官方checksum一致，必要C桥、admission源码及接口均保留。Windows三后端各2项公开API消费者测试通过；解析出的下载模块确认为0.2.0，祖先目录无moon.work覆盖。证据见publication-0.2.0.json和windows-registry-0.2.0.json。

Linux确切版本registry消费由新增CI步骤核实，并只保存消费者/准入摘要等脱敏artifact，不上传原始主机采样。最终结果在完成后补录；后续提交仅修改验证脚本、CI和材料，运行时代码仍对应上述冻结提交。包内说明为发布时快照，最终材料以GitHub main为准。原0.1.0数据保留原样。


## 0.1.0 历史发布

项目：MoonPressure 0.1.0。更新日期：2026-10-18。公开仓库 [trail-it/moonpressure](https://github.com/trail-it/moonpressure)，默认分支 main；[Mooncakes 0.1.0](https://mooncakes.io/docs/trail-it/moonpressure@0.1.0) 已由核实为 trail-it 的 CLI 账号发布，并完成确切版本独立消费。当前提交使用已核实 GitHub 账号的 noreply 身份；此前中性本地阶段历史保留原样。

## 公开发布证据

- 仓库创建时间：2026-10-18 07:05:09 UTC（北京时间 15:05:09）；首次公开在此次授权之后，不把 10/15 的本地阶段说成公开开发。
- 代码冻结提交：`011ea05e2e0b3831419f2d69730744395d2025fe`。
- 该提交的 [GitHub Actions CI](https://github.com/trail-it/moonpressure/actions/runs/39106369889) 已成功，包含核心后端、Linux 原生采集与独立 oracle、实际归档消费者。
- Mooncakes 0.1.0 发布时间：2026-10-18 07:19:49 UTC（北京时间 15:19:49）；registry 构建状态 success。元数据的许可证、仓库、版本均核对一致。
- Windows 的 wasm/wasm-gc/js、Linux 的 wasm/wasm-gc/js/native 分别通过独立消费模块的 1 项 API 测试；下载依赖的 moon.mod 确认为 0.1.0，所有祖先目录无 moon.work 覆盖。Linux 从下载包编译 C 桥并实读 cgroup。
- 实际上传 zip 共 54 文件，SHA-256 与 registry checksum 一致；见 test-evidence/publication-0.1.0.json。上传包内文档保留发布前快照，最终发布记录以 GitHub main 为准。
- 版本入口：[v0.1.0 release](https://github.com/trail-it/moonpressure/releases/tag/v0.1.0)。最终材料提交仅更新说明、PDF 与脱敏发布证据，包代码仍对应上述冻结提交；最终 main 的检查见 [Actions](https://github.com/trail-it/moonpressure/actions/workflows/ci.yml?query=branch%3Amain)。

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
|公开 registry 确切版本消费|Windows 三后端、Linux 四后端各 1 项消费者测试；Linux 从下载包编译 C 并读真实 cgroup|test-evidence/windows-registry-0.1.0.json、linux-registry-0.1.0.json|

本地归档消费者工具输出 19 tests，即依赖库/文档 18 + 消费者 1；不能将其宣称为 19 项新增库测试。registry 消费者每后端输出 1 项测试。10/15 的16项基线记录保留，未倒改旧测试结果。源码检查、本地归档与公开 registry 安装分别记录。

实测工具链：moon 0.1.20261012 (748b63c 2026-10-12)、moonc v0.10.15+943464bfa、moonrun 0.1.20261012。Windows 使用项目忽略目录中的匹配工具链，Linux 使用已准备好的同版工具链。工具链与缓存不分发。CI 使用官方安装器的滚动版本并记录实际版本；远端结果对应上面列出的提交，后续材料提交须另行核对其最终 CI。

本地真实内核为 Linux 7.0.0-38-generic，不把 synthetic 情景冒充实际资源压力。没有写内核控制文件、制造真实 OOM 或对服务施加压力。读取/cgroup 身份与内存预算的局限见 README。

## 归档与分发

`moon package` 生成 `_build/publish/trail-it-moonpressure-0.1.0.zip`；`scripts/verify_package.py` 检查实际 zip 文件清单、必要 C 桥和接口，并解包到隔离 workspace 消费。私有目录 research/release-local/demo-output、工具链、构建目录、Git 元数据与 PDF 不入库归档。实际文件数及消费者结果保留在 test-evidence/package.json；它记录本地档案，不是上传记录。

GitHub 已分发内容额外包含 CI 配置与申报 PDF。上传前检查了 60 个跟踪文件、77 个可达历史 blob 和 54 文件的实际包归档；无原始主机采样、凭据文件、SSH 配置、本机工具链或其他项目文件。针对实际文本扫描私钥/token 模式未发现匹配；这不等于保证检出所有秘密。54 是发布准备归档的文件数，不是 Mooncakes 上传记录，旧 test-evidence/package.json 保留其原始本地归档证据。

## 本次发布授权与阶段

用户已指定 trail-it 身份并授权 GitHub/Mooncakes 发布。此次核对上传账号、当前 author/committer、Mooncakes 登录与 namespace，分别检验实际仓库、CI、确切包版本和注册表独立消费。正式报名和人工理解仍未代办；既有本地历史不改造为此前公开开发。分发边界见 distribution.md。

## 2026-10-18 完善

补读 sysinfo@0.1.6 和 subproc@0.3.0 发布源码，明确已有 cgroup 内存能力；更新能力矩阵和独立贡献说明。添加 docs/participant-guide.md、两项准入恢复回归，并同步申报正文/PDF。软件功能及0.1.0 API保持不变，未发布的新版本不为增加提交数扩展功能。真实公开开发与参赛者理解仍由实际记录确认。
