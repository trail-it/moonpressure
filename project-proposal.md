# MoonPressure 项目方案

一个为 MoonBit 生态提供 Linux cgroup v2 资源压力诊断和队列准入建议能力的开源项目。

## 用户和独立贡献

面向在容器或 systemd 服务里跑编译、AI 工具调用、后台任务的 MoonBit 开发者：机器 CPU 空闲不代表容器没有被节流，叶节点 memory.max=max 也可能受父组共享限额限制。读取 Linux 原生统计，计算可解释的压力信号；调用方决定是否暂停派发任务。相近实现与差异见两份生态报告，不复制上游实现。

## 架构与边界

数据流：Linux 文件 / 调用方文本 → 严格类型化解析 → 层级资源归约 → 相邻快照差分 → 滞回状态机 → 结构化报告 / CLI。

根包拥有公共类型和纯 MoonBit 解析、约束归约、差分与决策 API；native 包仅负责有界文件读取、单调时钟、稳定 cgroup inode 身份。CLI 支持 replay 演示与显式 cgroup 目录采集。无需 root，不写 cgroup 文件、不杀进程、不执行自动资源调整。

MVP：PSI some/full；cpu.max、cpu.stat、memory.current/max/high/events；逐层有限上界及共享剩余量；计数器回退/身份变化/采样间隔检查；节流周期占比（不能误称时间占比）；内存 OOM 事件增量；带进入/退出持续次数和低水位的降载建议。PSI 缺失明确未知，不当作 0。核心跨 wasm-gc/js 验证；Linux native 真实采集。CPU 上界仅为 quota 上界，不声称包含 affinity/cpuset 或保证可得算力。

所有输入有界；计数器采用 Int64，拒绝负数及溢出。内核文件读取不是原子快照，跨时读取/祖先共享预算会变化，建议是启发式而非 OOM 保证。namespace 外不可见祖先不作推断。cgroup 删除重建通过设备/inode 身份识别；不自动解析 mountinfo 和自发现挂载。未来再考虑 PSI poll 和可插拔调度器，不属当前承诺。

## 验证与维护

严格解析/错误边界；独立手算 fixture；Python 从同一采集文本独立解析并对照数值；Linux 实际只读调用与错误路径；实际打包后在隔离消费模块编译运行公共 API。固定工具链版本记录，公共 API 按版本变更，新增失败用例回归。

## 三分钟演示

0-30 秒：容器限额和宿主资源观察的差异。30-90 秒：replay 中父组只有 100 MiB 共享剩余量，CPU 50% 周期被节流。90-140 秒：持续压力进入 Shed，连续低压力恢复，展示明确原因。140-180 秒：Linux live 采集与 oracle 对照、读取失败/不支持边界。

## 规则和本地状态

2026-10-15 读取官方 [十月赛网站源码](https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx)，网页依赖 JS，正文通过 raw GitHub 读取，原件 research/rules.txt。报名/验收截止 2026-10-31、十月最多提交 3 次、每队至多 3 人、MoonBit 主体、公开持续开发、可复现测试/演示、开源合规。报名次数的主体及修改计算未自行推断。

本次仅本地完成。GitHub owner/repo、Git 真实提交身份、Mooncakes 登录账号/namespace、参赛者信息均待指定。local/moonpressure 是本地临时模块名。中性本地 Git 身份仅保留真实阶段历史，不代表用户公开贡献身份；发布前必须确认归属。尚未公开、报名、入群或通过审核。

## 2026-10-18 完善

已从 registry 读取 sysinfo@0.1.6/subproc@0.3.0 发布源码，核实 cgroup 内存查询重叠与新增边界，详见 docs/ecosystem-supplement-2026-10-18.md。增加参赛者导读及“中间压力打断恢复/缺失 PSI 不恢复 OOM 降载”的两项端到端状态回归。本轮没有扩展产品功能或执行发布。

## 发布身份（2026-10-18）

用户已明确授权以 trail-it 上传 GitHub 并发布 Mooncakes；目标为 trail-it/moonpressure。前文的待指定/仅本地状态为最初范围记录，当前以 docs/release.md 和 docs/distribution.md 为准。保留真实本地开发历史，不倒填公开日期或虚构报名结果。
