# 作业派发与退出确认

导入 `"trail-it/moonpressure/dispatch" @driver`，以 `Dispatcher::new(scopes)` 建立单实例协调器；作业和预算类型来自 `admission`。协调器私有持有预留账本，执行器只接收动作并报告实际结果。

1. `submit(job)` 保存申请的独立副本，状态为 Queued。
2. `dispatch()` 在最早入队的16项中联合选择，先整批预留再产生 `Start(id, ticket)`，状态为 Starting。
3. 宿主启动进程后调用 `started(ticket)`；若启动失败且确认没有子进程，调用 `spawn_failed(ticket)`。
4. 宿主等待实际进程退出后调用 `exited(ticket, exit_code)`。零退出为 Succeeded，非零退出为 Failed；预留仅释放一次。
5. `cancel(id)` 对排队任务直接取消；对 Starting/Running 转入 Stopping 并返回 Stop。**请求停止时仍持有预留**；宿主确认未启动或已退出后才报告并释放。若取消与启动确认交错，`started` 会再次返回 Stop。
6. Failed/Cancelled 可 `retry(id)`，重新排队；下一次 Start 使用新 ticket。旧 ticket 的迟到回调报 StaleAttempt，不能释放新预留。同一已终结 attempt 的重复退出/失败确认返回 false。

`status`、`tasks`、`balances` 提供只读快照；`refresh` 更改同一层级的预算，保留已占用资源和缩额欠账。最多跟踪128项任务，终结项由 `forget` 清理。最早16项的选择窗口不保证全队列公平或无饥饿。

ticket 仅在**同一实例生存期**递增；不是身份认证，不提供重启恢复、跨进程一致性或持久任务队列。执行器须串行调用协调器，并诚实报告启动和退出结果；不能以“已发送终止信号”冒充退出。申请是调用方估算，预留不是内核硬限额。宿主拥有进程创建、等待和异常清理职责。

Linux 上完整的实际子进程演示：

```sh
moon build --target native --release --deny-warn
python3 scripts/verify_execution.py
python3 scripts/verify_dispatch.py
python3 scripts/verify_benchmark.py
```

`examples/dispatcher` 是 MoonBit JSON-lines 协调器；C 只提供有界标准输入与输出刷新。Python 宿主只执行固定的演示子进程、传递事件，不决定准入组合。工作负载最多同时2个进程，每个触碰1MiB缓冲区并有8秒截止；只终止自己创建的子进程，不写cgroup。环境预算不足或门禁关闭会明确失败，不把跳过伪装成通过。结果与限制见 [实测说明](../docs/execution-validation.md)。
