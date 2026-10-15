# Mooncakes 生态调研

读取日期：2026-10-15；适用十月赛。

从 https://mooncakes.io/api-new/v0/modules 实际取得 3019 条模块元数据，响应是 JSON 数组，无分页字段。按完整名称去重后 3019 条。仅全量检查元数据，未声称逐个审阅源码。原始响应保存在忽略目录 research/。网页检索为补充，网络失败不视为无竞品。

## 关键词覆盖

|词|元数据命中数|
|---|---:|
|AI|420|
|agent|88|
|workflow|23|
|parser|257|
|compiler|42|
|database|45|
|web|168|
|image|36|
|crypto|38|
|testing|54|
|devtool|5|
|wasm|239|
|visualization|15|
|audio|24|
|loudness|1|
|cgroup|0|
|PSI|4|
|pressure|2|
|cpu.max|0|
|memory.events|0|

PSI 搜索含 substring 误报；pressure 命中气象等无关条目。cgroup、cpu.max、memory.events 元数据未检出专用实现。这只是已检索范围的结论。

## 相关实现

|模块|最近发布字段 created_at|功能与边界|源码|
|---|---|---|---|
|[0717lee/moonhostabi@0.6.0](https://mooncakes.io/docs/0717lee/moonhostabi@0.6.0)|2026-09-29T11:45:20.332206|Artifact-first MoonBit Wasm-GC Host ABI lock, adapter, and validation toolchain|https://github.com/0717lee/moonhostabi|
|[chensuiyi/subproc@0.3.0](https://mooncakes.io/docs/chensuiyi/subproc@0.3.0)|2026-10-06T15:31:14.462077|Synchronous process management for MoonBit: spawn with env/cwd/redirection, waitpid and pidfd waits, kill, procfs sampling and platform probes|https://github.com/chenbimo/moonbit|
|[clbbbb/moonbit-wasm-inspect@0.1.0](https://mooncakes.io/docs/clbbbb/moonbit-wasm-inspect@0.1.0)|2026-08-22T14:45:34.409007|A MoonBit-native WebAssembly binary inspection and analysis library.|https://github.com/clbbbb/moonbit-wasm-inspect|
|[hutingyu-nuist/moonloudness@0.1.1](https://mooncakes.io/docs/hutingyu-nuist/moonloudness@0.1.1)|2026-10-14T05:55:25.855543|纯 MoonBit 的交错 PCM 流式响度与峰值分析库|https://github.com/hutingyu-nuist/moonloudness|
|[matrix486/moonjail@0.1.1](https://mooncakes.io/docs/matrix486/moonjail@0.1.1)|2026-09-23T12:13:47.120592|Linux least-privilege sandbox planning and runtime for MoonBit|https://github.com/matrix486/moonjail|
|[Milky2018/sysinfo@0.1.6](https://mooncakes.io/docs/Milky2018/sysinfo@0.1.6)|2026-10-13T04:10:51.019142|System metrics and process inspection library.|https://github.com/moonbit-community/sysinfo.git|
|[moonbitlang/async@0.22.5](https://mooncakes.io/docs/moonbitlang/async@0.22.5)|2026-10-14T07:52:30.815742|Asynchronous programming library for MoonBit|https://github.com/moonbitlang/async|
|[moonbitlang/workflow@0.10.0](https://mooncakes.io/docs/moonbitlang/workflow@0.10.0)|2026-09-28T01:08:41.165755|Engine-agnostic multi-agent workflow orchestration with journaled replay/resume|https://github.com/moonbitlang/workflow|
|[Ridge-Lab/moonwavkit@0.1.3](https://mooncakes.io/docs/Ridge-Lab/moonwavkit@0.1.3)|2026-08-20T05:10:54.940166|MoonBit-native WAV parser, PCM decoder, waveform analysis, validation, and audio utility toolkit.|https://github.com/Ridge-Lab/MoonWavKit.git|
|[yadidyc/moonpod@0.2.0](https://mooncakes.io/docs/yadidyc/moonpod@0.2.0)|2026-09-30T17:25:25.683902|A transport-neutral resource policy and audit engine for MoonBit hosts|https://github.com/yadidyc/moonpod|

created_at 按 registry 原字段记录，不当成最近源码提交。Star/下载未取得统一可靠数据，不填造；GitHub 活跃度见另一份报告。MoonLoudness 的公开 API、README 已读，提供流式 K 加权、门控、LRA 和真峰值，淘汰响度候选。Wasm inspect 和 host ABI 项目覆盖候选的主要功能，淘汰 Wasm 候选。sysinfo/subproc 的声明覆盖系统与进程指标，但对应源码 URL 本次 404，未能验证其 cgroup 细节，保留此竞争风险。

MoonPressure 的新增是 cgroup v2 层级约束与可用内存余量、PSI 时间差分、CPU 节流诊断、带滞回的队列准入建议；不实现通用进程库、沙箱执行器或监控 UI。无第三方运行时包依赖。
