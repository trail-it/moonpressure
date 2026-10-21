# 批次准入 API

导入 `trail-it/moonpressure/admission`，核心为纯 MoonBit，支持 wasm、wasm-gc、js、native。

```mbt
let capacity = @admission.Resources::new(memory_bytes=10L, cpu_millis=10L)
let ledger = @admission.Ledger::new([
  @admission.Scope::new("root", capacity),
])
let jobs = [
  @admission.Job::new("a", value=9L, [
    @admission.Allocation::new("root", capacity),
  ]),
  @admission.Job::new("b", value=6L, [
    @admission.Allocation::new("root",
      @admission.Resources::new(memory_bytes=6L, cpu_millis=4L)),
  ]),
  @admission.Job::new("c", value=6L, [
    @admission.Allocation::new("root",
      @admission.Resources::new(memory_bytes=4L, cpu_millis=6L)),
  ]),
]
let plan = ledger.plan(jobs) // selected() = ["b", "c"], value() = 12
let stale = ledger.plan(jobs)
ignore(plan.commit())       // 一次性预留两项作业的资源
// stale.commit() 会抛出 StalePlan，不能再次花掉容量。
ledger.release("b")
ledger.release("c")
```

以上公开 API 由归档消费者测试编译运行；演示与独立 oracle 见 `examples/admission`、`scripts/verify_admission.py`。

- `Scope.parent` 是显式父关系，不靠字符串前缀猜层级；每条申请沿全部祖先收费，整组作业的所有申请一起进入或等待。
- `Scope::from_layer(layer, ceiling, gate=...)` 以有限调用方预算封顶；内存使用该层自己的 `current`，CPU 为 quota 的向下取整 millicore 上界。缺少必要控制器数据时报错，不能把缺项当无限。
- `Gate::from_advice` 将缺失 PSI 映射为 Unknown 门禁。关闭节点只阻挡经过该节点的申请；祖先门禁作用于全部后代。
- `Ledger.plan` 不改变账本，最多16作业/64节点，每作业最多16申请；目标依次为总价值最大、作业数最多、UTF-16 字典序最小的 ID 集合。价值为调用方策略，不能解释为已测吞吐或公平性保证。精确搜索最坏访问131071个状态，适用于有界窗口。
- `Plan.commit` 绑定创建它的账本，检查修订号并整批提交；不接受调用方改写后的选择列表。提交、释放、刷新推进修订号，所有旧方案失效。
- `Ledger.refresh` 仅允许原拓扑的预算/门禁刷新；缩额不丢弃已有预留，用 `balances().deficit` 报告欠额。观测的 `current` 与逻辑预留可能重复扣减，不自动推断任务完成。作业退出或启动失败后，由调用方明确释放；崩溃后的恢复不在当前内存账本承诺内。
- `Plan.deferred` 列出当前所选组合下，未选作业经过的资源/门禁阻塞。它是局部冲突解释，不声称给出唯一最小冲突集。
- JSON 中所有 Int64 资源量、价值及修订号为十进制字符串。空方案也可提交并推进版本；同一 job ID 在已预留期间不能重复准入。

真实 Linux 衔接演示：`moon run examples/admission-live --target native -- /sys/fs/cgroup RELATIVE`。只读取两次实际采样，派生有限策略预算并在内存中规划/提交/释放，不启动作业、不写 cgroup。宿主根无额度文件时使用明确标注的调用方策略上限；不将其称为根组实测空闲资源。
