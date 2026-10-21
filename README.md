# MoonPressure

MoonPressure 为 MoonBit 应用提供 Linux cgroup v2 资源压力诊断与批次准入规划。0.2.0 在原有观测和滞回基础上增加共享祖先、多资源、整组作业的联合选择，以及带版本检查的资源预留账本：回答“本轮该启动哪些作业”，并防止多次调度重复分配容量。

适用场景：在容器或 systemd 服务中运行编译队列、AI 工具任务和后台作业。宿主 CPU 利用率不能反映容器节流；叶节点 `memory.max=max` 仍可能受父级共享预算约束。

**MoonPressure 0.2.0 修订版，MIT。** 公开源码：[trail-it/moonpressure](https://github.com/trail-it/moonpressure)。初审意见对应的新增核心与可运行反例见 [复审补充说明](docs/review-response.md)，API 用法见 [admission](admission/README.md)。0.2.0 发布状态见 [交付记录](docs/release.md)；下列已发布的 0.1.0 仅含原有诊断 API，不含新增规划器。

```sh
moon add trail-it/moonpressure@0.1.0
```

## 修订版：关系不同，准入结果不同

在此修订版源码根目录运行：

```sh
moon run examples/admission --target wasm-gc
python scripts/verify_admission.py wasm wasm-gc js
```

演示明确标记 synthetic，包含共享/独立父组、互补资源组合、协同作业门禁及提交/过期/缩额/释放。Python 从 JSON 输入独立穷举全部子集并重建阻塞原因；每个后端验证 6 个解释案例与 60 个确定性生成案例。

|只改变的关系|结果|
|---|---|
|两个 60 内存请求，共享 100 预算 vs 分别拥有 100 的父组|`[a]` vs `[a,b]`|
|CPU/内存各 10：A=(10,10),价值9；B=(4,6),C=(6,4),价值各6|选择 B+C，价值12，优于先选 A 的9|
|将 C 的内存需求从4增加到7，其他输入不变|选择 A，价值9|
|协同作业跨两个分支，其中一支关闭 vs 全部开放|整组等待且独立作业运行 vs 整组准入|
|两份方案基于同一账本版本|第一份提交后，第二份报 `StalePlan`；重新规划才可提交|

规划窗口至多16作业、64节点，每作业至多16条资源申请；最大化调用方声明的价值，再比较作业数和 ID。预留是单协调器内的逻辑账本；不保证内核资源、不代替进程执行器。采样刷新保留未释放预留，可能保守重复扣减；详见 [设计与边界](docs/admission-design.md)。

## 三分钟体验

使用 MoonBit 官方工具链。本项目实测 `moon 0.1.20261012`、`moonc v0.10.15+943464bfa`（2026-10-12）。Node.js 用于 JavaScript 后端；Linux native 需要 C 编译器。核心不依赖任何第三方包。

```sh
moon run examples/replay --target wasm-gc
```

输出 5 行 JSON，输入明确标记 `synthetic`。父组 CPU 配额为 0.5 核、共享内存余量为 100 MiB。前两秒 PSI 等待占比 30%、节流周期占比 50%，触发降载；随后三秒低压恢复：

```text
ready → shed → shed → shed → ready
```

检查跨后端一致性：

```sh
python scripts/verify_replay.py wasm wasm-gc js
```

Windows 当前工作副本已在忽略目录准备匹配的工具链，PowerShell 可先运行 `. ./scripts/windows-env.ps1`。该脚本仅设置当前会话环境，不下载或修改全局安装。其他检出按官方安装说明准备兼容工具链即可。

## 嵌入应用

在 moon.pkg 中导入 `"trail-it/moonpressure" @pressure`。使用 `Layer::parse` 加载叶节点和可见祖先的 `cpu.max`、`memory.max`、`memory.high`、`memory.current` 文本，调用 `budget(layers)` 得到约束。父节点必须传入父节点自身的 `memory.current`，其中包含兄弟节点消耗。

用 `Snapshot::parse` 构造同一 cgroup 世代的快照；`interval(previous, current)` 计算差分。`Controller::new(Policy::new())` 接收连续区间，`update(interval, budget)` 返回建议。完整可编译示例见 `examples/replay/main.mbt`；公开 API 见 `pkg.generated.mbti`，更多契约见 `docs/architecture.md`；手算和演示导读见 [参赛者理解导读](docs/participant-guide.md)。

默认策略：PSI some 或 CPU 节流周期占比达到 20%，连续两区间进入 `shed`；所有可用压力指标不超过 5%，连续三区间恢复。内存余量不超过 64 MiB、`memory.high/max` 事件也参与判断；OOM 事件立即降载。参数均可调整，这些是启发式阈值。

## Linux 实际采集

显式指定 cgroup 挂载根和相对路径。下面的命令在当前 shell 所属 cgroup 上只读采样；不改限额、不创建 cgroup、不移动或终止进程。

```sh
group=$(awk -F: '$1=="0" {print substr($3,2)}' /proc/self/cgroup)
moon run cmd/moonpressure --target native -- capture /sys/fs/cgroup "$group"
moon run cmd/moonpressure --target native -- watch /sys/fs/cgroup "$group" 5 1000
```

`capture` 输出一次观察；`watch` 首行观察，随后输出观察、差分、建议。末尾添加 `raw` 可携带实际读取文本，供本地独立 oracle 核对。原始内容可能含主机路径和资源细节，应留在本地。默认无 raw。

`watch` 支持 2～120 次采样、1～59000 ms 间隔。缺少必要 CPU/内存控制器、挂载映射不适用或读取权限不足时失败；默认示例不支持只包含统计子集的根 cgroup。容器内挂载与 `/proc/self/cgroup` 不对应时，调用方需传入正确相对路径。

## 验证

```sh
moon fmt --check
moon check --target wasm-gc --deny-warn --warn-list +73
moon test --target wasm-gc --deny-warn
moon test --target js --deny-warn
moon test --target wasm --deny-warn
moon check --target native --deny-warn
moon test --target native --deny-warn
moon build --target native --release --deny-warn
python3 scripts/verify_linux.py        # Linux cgroup v2 环境
python3 scripts/verify_package.py      # 实际 zip 归档的隔离消费者
```

2026-10-18：18 项库/文档测试在 Windows wasm/wasm-gc/js 和 Linux wasm/wasm-gc/js/native 通过，包含中间压力打断恢复、缺失 PSI 保持 OOM 降载的回归。10/15 的 Linux 真实采样与独立 Python 原始文本 oracle 证据继续保留。完整状态与归档验证见 `docs/release.md`、`docs/acceptance-review.md`。CI 配置已准备，尚未有远端运行结果。

## 工程边界

- PSI 缺失为未知；CPU 系统级 full 可缺省。未知 PSI 阻止控制器自动恢复，不伪装成健康的零压力。`ready` 也可能伴随 `missing_pressure`，调用方应结合原因决定准入。
- 快照身份变化、计数器回退、字段可用性变化、非正或超过 60 秒的间隔报错。控制器拒绝重复和不连续区间；切换数据源后显式 `reset()`。
- CPU 配额仅是可见祖先 quota 上界，不含 cpuset/affinity、调度竞争或保证算力。节流周期百分比不是节流时间百分比。
- 祖先内存余量是读取时刻共享上界，不是可预留额度；namespace 外不可见约束无法推断。跨文件读取不是原子快照。
- cgroup 身份由设备号和 inode 识别，用于检测常见删除重建；inode 长期复用或跨系统重放需调用方提供更完整世代标识。
- 本版本不注册 PSI poll、不控制内核、不自动执行降载；没有进行人为 CPU/内存压力、真实 OOM 或掉电实验。
- 每个文本最多 64 KiB，层级最多 256，十进制计数器范围为非负 Int64。JSON schema 1 中 Int64 均为十进制字符串，缺省值为 `null`，保留超过 2^53 的精度。

相邻实现的已核实重叠与新增贡献见 [10/18 源码补核](docs/ecosystem-supplement-2026-10-18.md)。sysinfo 已有 cgroup 内存查询，本项目新增在祖先预算、PSI/节流差分和准入状态。

来源、许可与 AI 辅助范围见 `THIRD_PARTY.md`、`AI_USAGE.md`。申报正文为 `submission-proposal.md`；[一页申报 PDF](https://github.com/trail-it/moonpressure/blob/main/output/pdf/MoonPressure-proposal-0.1.0.pdf) 在 GitHub 提供，不进入库包归档。上传边界见 [分发清单](docs/distribution.md)。
