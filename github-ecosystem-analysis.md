# GitHub 生态调研

日期：2026-10-15。检索包括 MoonBit / moonbitlang / moonbit-community / awesome-moonbit，以及 cgroup、PSI、pressure stall information、audio loudness、wasm inspector。搜索引擎索引有覆盖缺口，不能证明全网不存在。

|已有实现|实际审阅与结论|
|---|---|
|[moonloudness](https://github.com/hutingyu-nuist/moonloudness)|README、203 行公开接口与文件列表；支持 48kHz、门控、LRA、真峰值、归一化。与初选响度需求高度重合，淘汰该候选。最新发布 0.1.1；最近源码提交时间未从 API 成功取得。|
|[moonbit-wasm-inspect](https://github.com/clbbbb/moonbit-wasm-inspect)|README 及仓库目录；与 wasm5、starshine、moonhostabi 一起覆盖二进制审计基础，淘汰此候选；raw main API 404，不能声称审阅成功。|
|[moonpod](https://github.com/yadidyc/moonpod)|README 与公开 mbti；模型为工具、路径、网络权限、调用预算及人工审批，未见内核 cgroup/PSI 采集 API。issues 页面显示 0 open，不编造上游需求。|
|[sysinfo](https://github.com/moonbit-community/sysinfo)|registry 说明是系统指标/进程检查；源码及元数据 URL 本次 404/网络失败，未核验 API 和活跃度，保留竞争风险。|
|[subproc](https://github.com/chenbimo/moonbit)|registry 声明 spawn/waitpid/pidfd/procfs，URL 本次 404，不能推断停维或没有 cgroup 能力。|
|[posix](https://github.com/moonbit-community/posix)|README 声明基础 POSIX FFI WIP；与本项目的策略诊断层不同。|
|[psimon](https://github.com/holmanb/psimon)|README 是 C 语言 PSI 可视化工具，TODO 包含 cgroup；是相邻参考，未复制源码。|

官方 Community-Tasks API 实取 43 条 open issues，标题未发现 cgroup/PSI 专题。awesome-moonbit 的所试 raw URL 404。匿名 GitHub API 部分请求发生 TLS EOF 或 404，失败记录在 research/sources.json，未关闭 TLS 校验。没有取得最近提交/采用数据的项目均记为未核实，不用搜索摘要推断 API 成熟度。

本项目需求依据是 Linux 官方 [PSI 文档](https://docs.kernel.org/accounting/psi.html) 和 [cgroup v2 文档](https://docs.kernel.org/admin-guide/cgroup-v2.html)：宿主利用率不能替代工作负载等待时间，父级共享约束不能只读叶节点配置。它是可推导的工程需求，不冒称已有用户 issue 委托。

MoonPressure 不复用 MoonNetlink 代码：前者对资源压力做诊断和排队建议，后者处理 Netlink 网络状态和事件；无共同协议、FFI 桥、录制或测试证据。结论：在本次可核实范围未发现高度一致的专用 MoonBit 实现，仍存在未公开/检索不到实现的可能。
