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
- 介绍
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
		- 当 trace 通过多个不可见隧道，现有技术**只揭示一个**（对比 TNT）
		- 技术对某些 AS 无效，可能是因为它们部署 MPLS 只用 UHP，或**只为了 VPN**，或流量工程 
- 推断隧道长度
	- 基于事实，当 TTL 在 Egress LER 处超时，产生的 ICMP 超时包在返回时依然经过该 MPLS 隧道，在离开隧道时，只要 LSE-TTL 比 IP-TTL 小，会 LSE-TTL 会作为 IP-TTL（cisco 实现）
	- 公式，在 VP 处接收到 TTL 与返回出 Egress LER 的 IP-TTL 取值及距离 VP 跳数关系 
		- $$TTL\_{IP}(VP)=\min(TTL\_{IP}(E),TTL\_{LSE}(E))-h(E,VP)$$ 
  	- 事实上，LSE-TTL 和 IP-TTL 非常可能被生成 ICMP 回复的（前向路径的 Egress 路由器）路由器初始化为同一个值（大多数情况下255），由于 LSE-TTL 沿着返回 LSP 递减，在 Egress 处总比 IP-TTL 小
  	- 实际上，min 方案允许 Egress 路由器行为一致，无论 ttl-propogate 选项是否在 Ingress 路由器处使用，因而避免路由环路的发生是以一种无需信号协商的无状态方式执行。这种标准行为，使得隧道长度被包含在返回路径长度中，然而，返回路径的 Egress 不一定就是前向的 Ingress，前/后向路径路由一般不同，特别地在 BGP 中，可能引入路径不对称
  	- 对于 FRPLA, 在 AS 粒度上，比较往返路径的长度分布，然后是否统计分析是否观察到一个明显的不同（称 shift），即返回路径被期望比前向更长。隧道跳数，在前向路径中不计，但算在返回路径中。观测到 shift 可能表明 AS 使用 no-ttl-propogate 选项，这种不同可能提供 AS 隧道平均长度
  	- FRPLA 是最一般的方法，至少对所有 Cisco LSR（使用 PHP 作为默认配置）有效。相反，RTLA 只对在边缘部署 Juniper LER 的网络有效，比 FRPLA 更准确（由于 Juniper TTL 签名提供更多信息），而 FRPLA 只提供到 VP 返回路径长度，对路由不对称敏感（由于特定 BGP），RTLA 提供更精准的返回隧道长度（至少 ECMP 路由存在区分跳数），利用两种探测包的 TTL 的 差别。推荐使用 RTLA
  	- 对于 Juniper Egress LER 或者 其它指纹为 <255,64> 的路由器，当最小行为在返回 LSP 上使用时，计算公式（ICMP 超时回复包 TTL 初始为 255，ICMP echo-reply 包初始化为 64），由于后一种回复包，IP-TTL 总比 LSE-TTL 小（因为 LSE-TTL 总被设为 255，隧道足够短），导致回复包中 IP-TTL 为 64（前向 Egress LER 产生），称为 gap
  		-  $$h(I,E)=(255-TTL\_{IP}(VP))-(64-TTL\_{IP}(VP))$$
-  恢复隐藏跳
	- 这些方法的基本想法是在 MPLS 网络中，不是所有包都通过 LSP 转发。因为 LSP 可能只针对一个内部前缀的子网构造（如 Juniper 路由器的环回地址（Lookback address），然而，Cisco 路由器为所有内部前缀创建 LSP）或者只有目的地为 BGP 下一跳的包可能通过 MPLS 作交换（也是 Juniper 路由器的一个默认行为）。如果能 traceroute 路由器其中一个内部 IGP IP 地址（属于于内部流量相关的前缀），如 Egress LER（在 PHP 中）的入接口，可以看见明显的不带标签的 IGP 路由，所以可推断出隐藏 LDP 隧道。
	- 此外，Cisco 路由器也可以这样配置，当网络根据 IGP/BGP 结构划分为核心和边界路由器时（如避免外部路由重新分配给 IGP-only LSR）。可以很容易地配置 LDP 前缀过滤器来限制外部 BGP 传输流量(transit traffic)的 LDP 信号（signalling）。在两种情况（Juniper 默认或基本 Cisco 配置）和在 LER 上使用 BGP 下一跳特点时，所有外部 BGP 传输流量通过 MPLS 隧道，然而以内部 IP 前缀为目标的流量通过 IGP 显示路由。图4c，表明使在 Cisco 路由器上模仿 Juniper 行为，使用命令 mpls ldp label allocate global host-routes：如果以 Egress PE2.left 的入接口(该接口与最后一跳 P3 共享一个前缀)为目标，一次探测揭示明显的 IGP 路由。这是**直接路径恢复**的原则（Direct Path Revelation，DPR）。
	- **后向递归恢复**(Backward Recursive Path Revelation，BRPR)基于 PHP 特点，当网络完全使用 LDP 时(Cisco LSR 的标准和默认行为)。由于 traceroute 自然地揭示了每个 Egress LER 的入 IP 接口，可以用递归的 traceroute 方法，以最后一个内部前缀为目标，从 Egress LER 到 Ingress LER 以后向的方式来恢复每一个中间跳，当 BGP 路由对所有目标 AS 的内部前缀保持相似，这种方法很有效，如它们通过同样的 Ingress LER 进入，遵循一致的最短 IGP 路径（默认 LDP 行为）。值得一提的是，每个 Egress LSR 入 IP 接口出现多亏了 PHP 和这个事实--IP 前缀属于最后一跳和 Egress LSR。在图 4b 例子中需要有 4 步来停止递归和后向恢复所有内部 LSR
- 讨论
	- 技术涵盖所有基本的 MPLS 配置，除了完全不可见的 UHP（主要为了流量工程，让 RSVP-TE 隧道不可见，但部署 RSVP-TE 一般也会部署 LDP）
		- Cisco 的主要配置（PHP 和 允许所有前缀）可以用 FRPLA 和 BRPR
		- 基本的 Juniper 配置可以用 DPR，也可以用 FRPLA 看出一个可见的 shift
		- 特别地，Juniper LER 和 Cisco LSR 的混合可以用 RTLA 

	
