# 验收准备复核

## 2026-10-21 初审驳回后的修订

已收到初审未通过通知，理由为原申报净核心偏轻。本轮新增 `admission` 包的层级多资源整组选择和预留事务；输入关系、输出差异及实现入口见[复审补充说明](review-response.md)。0.1.0技术发布记录不能当作初审通过依据。

Windows三后端各30项库/文档测试通过，其中新增准入包12项；每后端66个独立穷举选择案例和生命周期检查通过。实际0.2.0 zip消费者增加规划器与过期提交验证，各后端2项消费者测试。本轮Linux CI已通过四后端测试、独立oracle及真实采集到账本衔接，详见release.md。本轮尚未代提交修改表单，尚无复审结果。

以下为0.1.0历史技术复核；其中“报名未执行”等仅代表当时，不覆盖此次用户提供的初审结果。

更新日期：2026-10-18；10/15 验证保留为历史基线。项目 MoonPressure 0.1.0，正式模块 `trail-it/moonpressure`，分支 main。GitHub owner/上传身份和 Mooncakes 发布账号均已核实为 trail-it；发布提交使用该账号的官方 noreply 身份。报名所需个人资料及队员尚未提供；此前中性本地历史保留。

## 当期规则

官方页面 https://moonbitlang.github.io/Hackathon2026/ 依赖 JS；2026-10-15 初读、2026-10-18 再次读取官方仓库正文 https://github.com/moonbitlang/Hackathon2026/blob/main/src/App.tsx ，获取方式为 raw GitHub，原件留在忽略的 research/。十月报名和验收截止 2026-10-31、最多提交 3 次、每队至多 3 人、MoonBit 主体、公开连续开发、可复现测试/演示与开源合规。未自行解释申报次数的适用主体，未执行任何报名。

## 分项证据

|项目|证据与实际结果|状态|
|---|---|---|
|独立需求和生态去重|初选 3019 条；10/18 索引 3088 条。已读取 sysinfo@0.1.6/subproc@0.3.0 发布源码，核实 cgroup 内存重叠与新增边界；见 ecosystem-supplement-2026-10-18.md|本地完成|
|MoonBit 主体|根包解析、层级归约、差分、状态机、JSON；native MoonBit 遍历/组装；C 仅 I/O/stat/clock/sleep|完成|
|工具链|Windows/Linux 均 moon 0.1.20261012、moonc v0.10.15+943464bfa；具体脱敏输出见 test-evidence/*-core-2026-10-18.json|完成|
|格式/检查/构建|fmt --check、check（+73/deny-warn）、release build（deny-warn）；Windows wasm/wasm-gc/js，Linux 再含 native|通过|
|库与文档测试|每个承诺后端 18 项（10/15 基线为16）；新增中间压力打断恢复与缺失 PSI 保持 OOM 降载；不将同一套跨后端运行累计为新增测试|通过|
|演示|每后端 5 个 synthetic 区间，独立手算 oracle，状态 ready/shed/shed/shed/ready，跨后端一致|通过|
|真实 Linux 能力|10/15 实测 Linux 7.0.0-38-generic，实际 cgroup v2 三次观察/两个区间；Python 从同次读取文本独立解析、核对预算和差分|通过|
|真实验证边界|没有写 cgroup、没有制造真实 OOM/压力；降载/恢复情景由明确 synthetic trace 验证|如实披露|
|错误路径|计数溢出、PSI 重复/缺项、部分 throttle、身份/计数回退、时间/gap、重复区间；原生必需文件缺失/超大读取/路径越界等|通过|
|公开 API|根 pkg.generated.mbti 与 native/pkg.generated.mbti；后者来自显式 native 目标。独立消费者从包内调用|完成|
|归档消费|实际 moon package zip，隔离 moon.work 使用解包库；消费者新增 1 项测试，Linux 再从包编译 C 桥并实际调用 cgroup|通过，见 test-evidence/linux-consumer.json|
|许可证/来源/AI|MIT、THIRD_PARTY.md、AI_USAGE.md；original synthetic fixture，主机 raw 不分发|来源/AI说明完成；participant-guide.md 已提供手算与演示导读，本人复核仍待完成|
|申报与展示|submission-proposal.md、公开一页 PDF、docs/demo.md|草稿已公开；未提交报名|
|公开仓库、持续公开记录|[trail-it/moonpressure](https://github.com/trail-it/moonpressure) 已公开；2026-10-18 15:05:09 北京时间创建，保留原始本地阶段历史|已上传；此前公开持续开发要求不能由此次上传补造|
|正式包/registry 安装|trail-it/moonpressure@0.1.0 已发布，registry 构建成功；Windows 三后端/Linux 四后端各 1 项消费者测试，Linux 下载包编译 C 桥并实调 cgroup|通过；见 test-evidence/*registry-0.1.0.json 与 publication-0.1.0.json|
|远端 CI|[代码冻结提交 011ea05 的 CI](https://github.com/trail-it/moonpressure/actions/runs/39106369889) 成功；覆盖核心后端、Linux oracle、实际归档消费|该提交通过；最终材料提交另行核实|
|报名/入群/官方审核|未执行，未填写真实个人资料|未开始|

## 10/18 完善与剩余项

两个既有源码访问缺口已用 registry 的确切发布归档补齐；未取得 GitHub 最近提交/Issues 不能冒称已核实。一般 cgroup 内存查询已有实现，本项目新增贡献限定为多层预算、区间压力和准入状态。新增两项端到端状态回归及带答案的理解导读。

技术交付、GitHub 上传与 Mooncakes 确切版本消费已完成；参赛者独立讲解/复现与官方报名/审核仍须本人完成。一次性上传不会自动补成此前公开开发过程。CI/registry 消费是项目交付验证，不将其冒称官网逐项硬门槛。

## 新增贡献和限制

本次从空目录独立实现 cgroup v2 诊断库与 CLI，不移植既有算法库，不复制上一个 Netlink 项目。协议规范引用与 AI 辅助范围已披露。重点是父组共享余量、正确单位的差分和有状态可解释建议，不以解析包壳或测试数量代替工程价值。

输入是可见层级的时间切片：祖先共享用量随时变化，读取不是原子事务；不含 affinity/cpuset；命名空间外约束未知。设备/inode 可识别常见目录重建，但跨主机/重启/长期 inode 复用需要调用方 epoch。缺失 PSI 会阻止自动恢复，ready 仍可能附 missing_pressure。建议不执行资源预留或保证免 OOM。详见 README 与 docs/architecture.md。

总体状态：技术和材料就绪，trail-it 的 GitHub/Mooncakes 已发布并验证；具体提交和证据见 release.md。官方初审、最终验收、获奖均无结果，不能由本复核替代。
