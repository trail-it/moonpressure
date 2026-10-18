# 相邻项目源码补核

读取日期：2026-10-18；对象为官方 Mooncakes registry 当时返回的最新发布版本。本次修复 10 月 15 日报告中 sysinfo/subproc 的源码证据缺口，未复制其实现代码或把第三方包加入项目依赖。

## 获取与审阅范围

GitHub 源码 URL 的既往失败不能证明项目不存在。本次通过 registry manifest 与文档中的 Download zip 链接实际下载确切发布源码：

|项目|注册表版本与日期|直接来源|实际阅读|
|---|---|---|---|
|Milky2018/sysinfo|0.1.6；created_at=2026-10-13T04:10:51.019142+00:00；Apache-2.0|[manifest](https://mooncakes.io/api-new/v0/manifest/Milky2018/sysinfo)、[发布源码](https://download.mooncakes.io/user/Milky2018/sysinfo/0.1.6.zip)|25 个归档条目；README、公开 mbti、types.mbt、system_impl.mbt 的 cgroup 分支、system_test.mbt 与 backend_native_wbtest.mbt|
|chensuiyi/subproc|0.3.0；created_at=2026-10-06T15:31:14.462077+00:00；MIT|[manifest](https://mooncakes.io/api-new/v0/manifest/chensuiyi/subproc)、[发布源码](https://download.mooncakes.io/user/chensuiyi/subproc/0.3.0.zip)|13 个归档条目；README、src/procfs.mbt、src/ffi.mbt、src/subproc_test.mbt|

两者 manifest 均标记未撤回、文档构建 success。读取时累计下载字段分别为 754、36，仅代表该接口返回值，不推断实际采用人数。GitHub 最近提交、Stars、Issues/roadmap 仍未取得可靠结果，不能据此判断是否停维。本次没有编译或运行第三方测试。

对两份归档的 MoonBit/C/Markdown/mbti 文本进行了 cgroup、PSI、pressure、cpu.max、memory.current、throttle 定向检查，再阅读命中的实现；不是宣称逐行审阅全部源码。原始下载、网页和扫描记录保存在忽略目录 research/2026-10-18，不随本项目分发。

## 已有能力与新增贡献

|能力|sysinfo 0.1.6|subproc 0.3.0|MoonPressure 0.1.0|
|---|---|---|---|
|cgroup 内存与交换额度|有：CGroupLimits；System::cgroup_limits|本次所读接口未见|只做内存 max/high/current，不提供 swap 预算|
|可见祖先共享用量归约|所读 cgroup 实现固定读取挂载根部路径，未遍历祖先|未见|显式根和相对路径，逐层按各层 current 计算最小余量|
|CPU quota 与节流|所读 cgroup 分支未见 cpu.max/cpu.stat 处理|每进程 CPU ticks，不是 cgroup quota|祖先 quota 上界、节流周期增量与独立时长字段|
|PSI total 差分|归档定向检查及公开接口未见|归档定向检查及公开接口未见|CPU/内存/IO，some/full，缺省与重置显式处理|
|有状态准入建议|未见|进程拉起、回收、信号，非准入状态机|进入/退出连续次数、滞回、OOM 快路径、未知 PSI 阻止恢复|
|系统及进程管理|全面系统/进程指标|spawn/pidfd/wait/kill/procfs|不提供这些功能，可由调用方组合|

sysinfo 的 `CGroupLimits` 在 types.mbt:183 定义内存/剩余内存/剩余 swap；公开 mbti:662 提供 `System::cgroup_limits`。system_impl.mbt:774 的 `read_cgroup_limits_linux` 读取 `/sys/fs/cgroup/` 下的 memory.max/current 与 swap 文件，再计算单层余量。容器内挂载根可以就是该容器 cgroup，因此不能声称它“不能获取容器限额”。已核实的差异是多层归约、PSI/节流差分和决策状态，而不是泛称“首次 cgroup 查询”。[该版本源文件页面](https://assets.mooncakes.io/assets/Milky2018/sysinfo@0.1.6/system_impl.mbt.html)

subproc 的 src/procfs.mbt:3、:16、:29 分别暴露 RSS、CPU ticks、时钟频率；ffi.mbt 接到进程/系统调用桥。测试包含真实子进程环境/日志/退出码和失败路径。它解决生命周期管理，MoonPressure 解决派发前资源压力建议，二者不是同一操作。[该版本源文件页面](https://assets.mooncakes.io/assets/chensuiyi/subproc@0.3.0/procfs.mbt.html)

## 生态范围更新与结论

2026-10-18 重新取得模块索引 **3088** 条、按完整名称去重后 **3088** 条。对名称/描述/关键词的 cgroup、独立 PSI 单词、pressure stall、resource pressure、资源压力检索未命中专用条目；sysinfo 实际含 cgroup API，证明元数据检索不能替代源码核查。初选的 3019 条统计保留为 10 月 15 日历史，不冒充今天的数量。

两个此前未核实的具体候选现在已有发布源码证据。在本次版本与审阅范围内，未发现与本项目“祖先共享预算＋PSI/节流区间差分＋滞回准入”完整重合的实现；一般 cgroup 内存查询已有实现。本项目继续作为独立诊断/准入组件，不扩展为通用系统指标或进程库。该结论不覆盖未发布代码，也不是官方的选题认可。
