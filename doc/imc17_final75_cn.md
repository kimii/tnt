# [Through the Wormhole: Tracking Invisible MPLS Tunnels](https://orbi.ulg.ac.be/bitstream/2268/214681/1/paper.pdf)
------

## 摘要
- Internet 拓扑研究通过主动测量实施，如 caida 利用 traceroute 获取的 IP 层 trace 结果之上来构建路由器级拓扑。结果图包含非常多的高节点度的节点，通常超过了路由器接口的实际数量。尽管这可能由于准确的别名解析，但本文认为由不可见隧道组成的不透明的 MPLS 云是主要原因。
- 通过使用 2 层技术如 MPLS，可以配置路由器隐藏 traceroute 中的内部 IP 跳数。结果，MPLS 网络的入节点都以出节点的邻居出现，整个 3 层网络变成了一个高节点度的稠密网格（dense mesh）
- 解决 3 个问题
	- MPLS 隧道隐藏的 IP 跳数
	- MPLS 部署的低估（丢失内部 IP 链接）
	- 高节点度节点的高估
- 开发了新的测量技术来揭示不可见 MPLS 隧道的存在和内容，通过仿真和交叉验证来评估，针对目标可疑网络执行大规模测量并对结果统计分析，最后基于数据集，观察了被不可见隧道影响的基本图属性 

## 引言
- 节点度分布
	- 奠基性文章指出了幂率（pow-low）分布，但可能观测到很多高度节点
	- 大量高度节点原因
		1. traceroute 测量从受限的测量点实施，可能导致生成的是子图，该子图中推断的节点度分布的确遵循幂率，但不是实际分布。Clauset 等表明这可能是 Erdos-Renyi 随机图的特例。
		2. 高度节点可能从 2 层云产生（如 Ethernet switches）。2 层设备与大量 3 层 路由器相互连接，2 层设备本身有多个 2 层连接
	- 本文研究 Internet 图 HDN 产生的另一个原因:不透明的 MPLS 云对 traceroute 探测隐藏内容
- 识别不可见 MPLS 隧道原因或目的
	- traceroute 测量结果不完整，导致 Internet 图存在潜在歧义
	- 更好的捕获网络时延异常现象

## 发现不可见 MPLS 隧道
- 4 种方法
	- 隐藏跳数
		- FRPLA(Forward/Return Path Length Analysis):往返路径长度分析
		- RTLA(Return Tunnel Length Analysis):返回隧道长度分析
	- 恢复跳
		- DPR(Direct Path Revelation):直接路径恢复
		- BRPR(Backward Recursive Path Revelation):后向递归恢复
- 效果
	- 利用 4 种技术能捕获大多数 MPLS 使用情况
		- Juniper 和 Cisco 的标准行为和典型的 MPLS/IGP/BGP 网络配置


 
	
