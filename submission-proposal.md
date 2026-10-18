# MoonPressure 0.1.0：Linux cgroup 资源压力诊断

2026 MoonBit 黑客松十月赛，本地申报草稿，2026-10-18。用户指定 GitHub 身份 trail-it；仓库 https://github.com/trail-it/moonpressure，模块 trail-it/moonpressure@0.1.0；本次发布结果见 docs/release.md，队员/正式报名资料待本人确认。

## 解决什么问题
为容器内编译、AI 工具调用和后台任务队列提供可解释的降载建议：宿主空闲不代表容器未节流，叶节点 memory.max=max 也可能受父组共享限额约束。

## 生态新增
初选检索3019条元数据；10/18复查3088条并补读sysinfo@0.1.6、subproc@0.3.0发布源码。sysinfo已有挂载根cgroup内存/swap查询，subproc提供进程管理与采样；本项目独立新增可见祖先共享预算、PSI/节流差分和滞回准入。精确版本与能力矩阵见补核报告。

## 已完成能力
核心为纯 MoonBit：类型化解析、父组共享内存余量、CPU quota 上界、身份/计数器重置检查、OOM 增量与连续高低压状态机、JSON。Linux C 桥仅负责只读 I/O、stat、时钟和 sleep；不自动修改内核或终止任务。

## 可复现验证
2026-10-12 工具链；Windows 三后端、Linux 四后端各 18 项库/文档测试与 check/build/格式通过。synthetic 演示五区间跨后端一致。10/15 真实 Linux cgroup 三次观察/两个差分区间通过独立 Python 原始文本 oracle；实际 zip 在独立消费者中通过 API 测试，并从归档编译 C 桥实调 cgroup。

## 来源、AI 与责任
MIT，引用 Linux 官方 cgroup/PSI 规范，无第三方实现源码移植；synthetic 输入为原创。Codex 辅助调研、实现、测试与材料，提供手算、代码/测试入口和演示导读，参赛者须本人复核架构、单位、状态机及限制；人工理解尚待本人确认。

## 演示、维护与限制
三分钟命令脚本见 docs/demo.md：父组余量、连续压力降载、三次低压恢复、真实采集与独立对照。保留边界测试和版本化 API；后续可接入调度器。当前不含 cpuset/affinity、隐藏祖先和自动控制；非原子快照、共享余量不保证免 OOM。未制造真实 OOM/压力；GitHub/Mooncakes发布已获授权，线上结果以release.md记录为准；报名/官方审核未执行。
