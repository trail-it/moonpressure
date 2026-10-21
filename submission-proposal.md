# MoonPressure 项目申报书（初审后修订）

**1、项目名称**：MoonPressure——Linux cgroup 多资源整组准入与作业生命周期协调库，0.3.0，2026-10-21。

**2、项目简介**：面向多个作业争用共享父组预算的场景，联合选择可运行组合、原子预留容量，并将启动、失败、取消、退出与重试衔接为可核对的状态机。压力观测是输入能力；实质核心为资源关系建模、整组优化、预留事务和异步执行确认。

**3、方向与通用性**：系统基础库与开发者工具，供容器、systemd服务中的编译、AI工具和批处理执行器嵌入。纯MoonBit核心支持wasm、wasm-gc、js、native，Linux提供只读采集与实际子进程演示；宿主执行器负责创建、等待及清理进程。

**4、完整使用场景及关系案例**：

- **共享编译预算**：两个子组各申请60内存。共享预算100的父组时只准入一个；改为两个独立预算100的父组时同时准入。执行器按动作启动，退出确认后归还全部祖先预留，避免逐叶判断超分配。
- **AI工具互补组合**：内存/CPU各10；A申请(10,10)、价值9，B申请(6,4)、C申请(4,6)、价值各6，选B+C得12；仅把C内存改为7则选A。真实Linux演示按选择启动互补子进程，等待后释放。
- **协同批处理与重试**：一个作业同时申请两个分支，一支关闭时整组等待、独立小作业可运行。开放后整组准入；取消先进入Stopping并保留容量，确认未启动或实际退出后才释放。失败重试产生新ticket，旧回调不能释放新预留。

**5、核心功能与验证**：层级验证、祖先累计收费、至多16任务/64节点的精确批次优化、整组申请、冲突解释、方案版本检查和缩额欠账；新增7状态协调器、退出幂等与attempt隔离。Windows三后端、Linux四后端各35项库/文档测试；每后端66个选择案例独立穷举对照；动态模型2,000次事件逐步核对通过。指定Linux服务器实际启动并回收5个子进程。20组合成对照对FIFO/价值贪心分别17/13组价值更高，其余持平；密集边界规划约40毫秒，不宣称吞吐提升或内核资源保证。

**6、原创性**：原创MoonBit实现，MIT许可；采用已有优化方法，不声称算法首创。C仅承担宿主I/O等基础能力；Python负责演示进程执行和独立验证，不承担准入决策。AI辅助及本人理解要求见AI_USAGE.md。

**7、移植与参考**：非移植项目，无移植上游。资源语义参考[Linux cgroup v2规范](https://docs.kernel.org/admin-guide/cgroup-v2.html)，无第三方实现源码移植；moonpool、moontask相邻能力与差异见复审说明，不声称通用任务队列首创。

**8、仓库与证据**：[trail-it/moonpressure](https://github.com/trail-it/moonpressure)，保留真实有效[提交历史](https://github.com/trail-it/moonpressure/commits/main/)；[复审补充说明](https://github.com/trail-it/moonpressure/blob/main/docs/review-response.md)、[实测及复现](https://github.com/trail-it/moonpressure/blob/main/docs/execution-validation.md)、[版本交付记录](https://github.com/trail-it/moonpressure/blob/main/docs/release.md)。本轮为初审驳回后的实质修改，尚未代提交修改表单，尚无复审结论。
