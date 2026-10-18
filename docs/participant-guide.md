# 参赛者理解与演示导读

更新：2026-10-18。先运行演示，再尝试不看答案解释下面的计算。本文提供核对依据，不把“文档已写好”视为你本人已经理解。

## 先把程序跑起来

项目根目录运行 `moon run examples/replay --target wasm-gc`。Windows 当前工作副本可先执行 `. ./scripts/windows-env.ps1`。输出五行 JSON；观察 `budget`、`interval`、`advice` 三部分。输入标记 synthetic，不能把演示值当成真实主机测量。

然后运行 `moon test --target wasm-gc --filter '*recovery*'`，验证恢复窗口被打断的情况；用 `moon test --target wasm-gc --filter '*OOM*'` 查看 OOM 和未知数据的处理。完整测试命令见 README。

## 七个必须能解释的问题

|问题|可手算答案|代码或测试入口|
|---|---|---|
|父组 memory.max=1000、current=900，叶节点 current=100、max=max，还能多用多少？|在其他用量不变时，父组只剩 100 字节共享余量；不能用 1000−叶节点100 得出900。它也不是已预留的100字节|budget.mbt；budget_test.mbt 的 parent shared usage 用例|
|叶节点 CPU quota 为 150000/100000，祖先为 25000/100000，容量是多少？|可见 quota 上界为 min(1.5,0.25)=0.25 核；不等于允许启动0个任务，也不代表必然可得0.25核|budget.mbt；budget_test.mbt|
|PSI total 一秒增加250000微秒，avg10却是0，应看哪个？|该采样区间 some=25%；avg10是另一时间尺度的内核平滑值，不能替代同区间差分|delta.mbt；delta_test.mbt|
|10个CPU调度周期里5个被节流意味着什么？|50%的周期发生节流；不能据此说50%的墙钟时间被节流。throttled_usec单独报告|parse.mbt、delta.mbt|
|为什么压力消失一秒后仍是shed？|默认进入要连续两次≥20%，退出要连续三次≤5%；介于两阈值的区间打断恢复连续性，减少状态抖动|policy.mbt；policy_test.mbt 的 intermediate pressure 用例|
|OOM触发后，连续读不到PSI能否恢复？|不能把未知当0。状态保持shed且low_streak=0；第一段有out_of_memory，后续无新增OOM但仍有missing_pressure/recovering|policy_test.mbt 的 missing PSI keeps 用例|
|计数器变小、cgroup换了或重复投递区间怎么办？|拒绝比较或更新，不跨世代相减；调查来源后重新取基线，必要时显式reset。reset会清除降载状态，不能随意用它消除告警|delta.mbt、policy.mbt 与相关错误路径测试|

## 用一个反例讲清滞回

用默认阈值，三类 PSI some 同步依次为30%、30%、0%、10%、0%、0%、0%，各区间一秒，无节流信息和新内存事件、预算无限：

|区间|压力|low_streak|建议|
|---|---:|---:|---|
|1|30%|0|ready|
|2|30%|0|shed|
|3|0%|1|shed|
|4|10%|0|shed|
|5|0%|1|shed|
|6|0%|2|shed|
|7|0%|3|ready|

这组手算由 `intermediate pressure breaks the recovery streak` 测试逐步断言。OOM是另一条优先路径，不需要等两次高压。

## 为什么还需要MoonPressure

`Milky2018/sysinfo@0.1.6` 已提供 `CGroupLimits` 和 cgroup内存查询，不应声称生态没有这项能力。它的已核实实现读取挂载根部的内存/交换额度；本项目新增可见祖先归约、PSI total差分、节流事件与连续准入状态。`chensuiyi/subproc@0.3.0` 管理进程生命周期和每进程procfs采样，本项目不负责spawn/kill。两者可与本项目互补。证据见 ecosystem-supplement-2026-10-18.md。

## 三分钟讲解顺序

先说明“容器节流和父组共享预算”这一问题；运行replay并解释三个JSON部分；手算100字节余量和25%等待；指出阈值滞回与OOM快路径；最后在Linux运行capture/watch并说明真实值与合成值的区别。完整口述节奏见 demo.md。

## 人工复核记录

由参赛者本人完成并留下真实日期：独立运行演示；解释以上七题；复现一个错误路径；阅读来源/许可证；确认公开身份和申报信息。当前状态为**待本人复核**。线上公开开发与审核记录也必须来自实际发生的操作，不能用这份导读代填。
