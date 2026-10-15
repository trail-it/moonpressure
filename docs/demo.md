# 三分钟演示

0:00–0:30 展示“宿主空闲但容器被节流；叶节点 max 仍受父组共享额度限制”的需求，说明只读、不自动调整内核。

0:30–1:00 运行 `moon run examples/replay --target wasm-gc`，输出标记 synthetic。父组配额 0.5 核、共享内存余量 100 MiB。

1:00–1:40 第一、二秒 PSI some=30%、节流周期=50%，状态 ready → shed；接着三次 0% 区间依次恢复至 ready。展示 reasons 和 high/low streak，而不是只看一个布尔状态。

1:40–2:20 在 Linux 运行 README 的 capture/watch。解释实时值与合成场景的区别；不制造 OOM、不更改服务限额。使用 `python3 scripts/verify_linux.py` 展示原始文本 oracle 的脱敏汇总。

2:20–3:00 展示包消费结果及限制：没有自动执行降载，没有 cpuset/affinity 保证，不可见祖先未知，读取并非原子快照。用错误输入说明重复区间和缺失必需统计不会静默得到健康结论。

没有录制视频；以上是已经具备命令和结果的演示脚本。原始主机采样不随库归档分发。
