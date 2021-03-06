# [TNT: Technical Report](http://www.montefiore.ulg.ac.be/~bdonnet/mpls/Papers/mpls-techrep.pdf)
------

## 摘要
- 背景：traceroute 有多种限制，特别是2层云（layer-2 clouds）如 MPLS 可能对 traceroute 探测隐藏内容，因而得到的 Internet 拓扑数据和模型是不完整和不准确的
- 工作介绍：
	- TNT(Trace the Naughty Tunnels)，作为对 paris traceroute 的拓展来揭示天一条路径中的大多数 MPLS 隧道
	- TNT 工作分为两个基本阶段：
		1. 随着 traceroute 探测，寻找隐藏隧道潜在存在的证据（在 traceroute 输出中令人意外的模式，如突然的和明显的 TTL 变化）
		2. 如果由于这些证据存在而触发警报，TNT 发起额外的专用探测，可能会揭示隐藏隧道的内容
	- 通过 GNS3 模拟验证 TNT，并通过专门的测量活动调整其参数；在 Archipelago 平台上大规模部署 TNT，并提供了对隧道的量化，更新了 MPLS 隧道的最新视角
## 引言
- MPLS 介绍：
	- MPLS 被设计来减少做转发决策需要的时间，借助于在 IP 头部插入标签（LSE）。
	- 实际在一个 MPLS 网络中，数据包对 LSE 中的 20-bit 值使用精确的匹配检查。在 MPLS 每一跳，入口包的标签被在 MPLS 交换表中找到的相关出口包标签替代。
	- MPLS 转发引擎比 IP 转发引擎更轻，因为找到一个标签的确切匹配比 IP 地址的最长前缀匹配更简单
	- **一些 MPLS 网络能被 traceroute 发现**，因为当 MPLS TTL 过期时，MPLS 路由器能够生成 ICMP 超时消息并且 ICMP 消息中嵌入了 LSE
	- 然而，MPLS 架构支持 optional mechanisms（可选机制），使得通过修改数据包处理 TTL 的方式使得 MPLS 隧道不可见
## 背景知识
- 网络指纹
	- [Vanaubel等人](https://www.researchgate.net/publication/262317377_Network_fingerprinting_TTL-based_router_signatures)提出了基于硬件和 OS 来区分网络设备的路由器指纹技术，该方法通过伪造不同数据包来推断路由器使用的初始 TTL，然后构造路由器的指纹如 n 个初始 TTL 的 n 元组
	- 一个基本的 对签名（pair-signature）简单的使用两个不同消息的初始 TTL 
		1. ICMP 超时消息(time-exceeded) ,由 traceroute 探测引起
		2. ICMP echo-reply 消息由一个 echo-request 探测获取(参考 ping)
	- 这种特性能够区分 MPLS 行为和签名，考虑到部署最多的路由器品牌，Cisco 和 Juniper
		- 路由签名 | 路由器品牌和 OS
			- 1. <255, 255> | cisco(IOS,IOS XR)
			- 2. <255, 64>  | Juniper(Junos)
- MPLS 基础和控制层
	- LSE(label stack entry) 4 字节构成，插入到 IP 包(网络层)和 帧头(数据层)之间
		- Label:	20 bit，用于转发
		- TC:		3  bit，Traffic Class 
		- S:		1  bit，当前 LSE 是否栈中最后一个
		- **LSE-TTL**:  8  bit，同 IP-TTL 作用，避免路由环路
	- LDP(Label Distribution Protocol,标签分发协议)，分配标签
		- 每个 LSR 告诉它的邻居它的路由表中的一个前缀和对于一个给定 FEC(标签等价类，默认是目标前缀)的联系，填充到每个 LSR 的 LFIB(Label Forwarding Information Table，标签转发信息表)中；对于一个给定 FEC，一个给定路由器把同样的标签告诉所有它的邻居
		- 使用 LDP 主要理由包括可拓展性的原因（如限制边界路由器的 BGP-IGP 交互），和传输流量的异常现象如 iBGP deflection issues
		- 实际上，LDP 部署隧道用的是和 IGP 相同的路由计算，正如 LFIB 建立在 IGP FIB 的基础上
		- 另外，标签也可以通过 RSVP-TE 分发，当 MPLS 用于 TE（Traffic Engineering） 目的，实际上，大多数管理员部署 RSVP-TE 隧道使用 LDP 作为默认的标签协议
	- 基于 LDP，MPLS 有两种绑定标签到目标前缀的方法
		1. 通过 ordered LSP control，Juniper 路由器默认配置，只绑定标签到这样的前缀--前缀是本地的（local），或接收到 IGP 下一条的标签绑定提议，
		2. 通过 independent LSP control，Cisco 路由器默认配置，为它的 RIB 中的每个前缀创建一个标签绑定
	- **移除标签模式**
		- Egree LER(Egress Label Edge Router):一个 FEC 中的最后一个 LSR
		- 根据配置，有两种不同的标签模式
			1. PHP(Penultimate Hop Popping，倒数第二条移除)：默认模式，是出口(Egress)广告一个隐式空标签(implicit null label,标签值为 3)，前一个 LSR(PH,倒数第二条LSR)负责移除 LSE，来减少出口(Egress)的负载
			2. UPH(Ultimate Hop Popping，最后跳移除)：Egress LER 广告一个显示空标签(explicit null label,标签值为 0)，PH 将使用这个显示空标签，Egress LER 将负责它的移除
		- 被非 Egress LER 的 LSR 划分的标签不同于隐式或显示空标签
		- EH(Ending Hop LSR，最终跳 LSR)负责移除标签，它可能是 PHP 中的 PH，UHP 中的 Egress LER，或者 independent LSP control 中其它可能的 LSR
- MPLS 数据层和 TTL 处理
	- 基于在 LSP 中的不同位置，LSR 以下操作之一
		1. PUSH: 第一个 MPLS 路由器，如隧道入口点在 IP 包中压入一或多个 LSE，转化为 MPLS 包;Ingress LER（Ingress Label Edge Router）关联数据包的 FEC 到它的 LSP
			- 具体行为：查找 LFIB，压入 LSE，**初始化 LSE-TTL，分为两种方式**，
				1. Ingress LER 重置 LSE-TTL 到任意的值（255，或 no-ttl-propagate），这种情况下 LSP 称为 pipe LSP
				2. 复制当前 IP-TTL 到 LSE-TTL，这种情况下 LSP 称为 uniform LSP(一致的 LSP)
				3. 注：一般情况下，在被封装到 MPLS 的头部之前 IP-TTL 会减少 1，除了特定的 Juniper OS 如 Olive
		2. SWAP: 在 LSP 内，每个 LSR 在 LFIB 中做标签查询，以关联出口标签交换入口标签，接着沿着 LSP 发送 MPLS 包
			- 具体行为：一旦 MPLS 包到达，LSR 减小 LSE-TTL，根据 LSE-TTL 是否超时
				1. 不超时：正常进行 SWAP 操作
				2. 超时：  伪造返回给数据包产生者的 ICMP time-exceeded 消息；值得注意的是，若 LSR 实现了 RFC 
				3. （所有当前 OS 都应该如此），LSR 会在 ICMP 超时消息中引用整个 MPLS LSE 栈
			- MPLS 隧道中 **ICMP 处理**，根据 ICMP 消息类型不同而不同
				- ICMP Information 消息（如 echo-reply）会直接返回给目标（如 echo-request 产生者）
				- 相反，ICMP 错误消息（如 time-exceeded）一般转发给 Egress LER(负责通过 IP 层转发包)
		3. POP:  EH 删除 LSE，把 MPLS 包转化为 IP 包 
			- 具体行为：MPLS 包到达，EH 减小 LSE-TTL,若 LSE-TTL 未超时，EH 在决定新的 IP-TTL 后移除 LSE 栈
			- PHP 和 UHP 方式对比
				- PHP 减少了 Egress LER 的负载，特别是当它是大的 LSP-tree 的根时
				- UHP 一般用在 ISP 实现更复杂的流量工程操作时或希望使隧道内容和语义对客户更加透明
			- 离开隧道时，**IP 头部 TTL 的选择** 
				- **IP-TTL 或者 LSE-TTL**
					1. 扇入 LER 激活 no-ttl-propagate 选项，EH 应该选择入口包的 IP-TTL
					2. 扇入 LER 激活 ttl-propagate 选项，选择 LSE-TTL
				- 为了同步这两种**隧道的两端**而不用交换任何信息，在 EH 处选择 IP-TTL 的两种协商方式
					1. 取 **min(IP-TTL, LSE-TTL)**
						- **可以用来检测隐藏 MPLS 隧道**：当返回的 Ingress(前向 EH)重复使用 MPLS 云返回时，这是由于依据 min 取法，前向 PH 选用 IP-TTL，返回时 PH 选择 LSE-TTL(考虑到在前向隧道的 Egress 处会初始化 IP-TTL 为最大值，如 Cisco 为 255)
						- 但 MPLS 行为非常依赖于实现和配置，比如有些路由器并没有应用 min 操作
					2. 假设 Ingress 的配置（ttl-propagate 或相反）与本地（local）配置一致**?**
				
- MPLS 隧道分类
	- Explict: traceroute 结果带有 LSP，包含 MPLS 信息
		- 含义：LSR 实现了 RFC4950(意味着 ICMP 超时包会带上整个 MPLS LSE 栈信息) 并且激活 ttl-propagate 选项(默认配置);对 traceroute 完全可见，包括沿着 LSP 的标签
	- Implict：traceroute 结果带有 LSP，不包含 MPLS 信息
		- 含义：LSR 没实现 RFC4950 但激活 ttl-propagate 选项；没有错过 IP 信息 但 LSR 被当作正常 IP 路由器(不带 MPLS 标签)，导致 traceroute 输出“语义”上的缺失
		- 发现技术
			1. LSR 处理 ICMP 消息的方式：参考 SWAP 操作部分，称为 UTURN  
			2. 超时消息中 IP-TTL 的引用，称为 qTTL：具体地，qTTL 会在 LSP 中的每个后续的 LSR 加一由于 ttl-propagate 选项（ICMP 超时消息基于 LSE-TTL 产生，而 IP-TTL 在 LSP 中未改变）
	- Opaque(不透明的): traceroute 结果不带有 LSP，包含 MPLS 信息
		- 含义：LSR 实现了 RFC4950 但未激活 ttl-propagate 选项, EH 没有收到明确的（explict）或不明确的（implict）空标签（null lable）；只有EH 被发现，其他隧道被隐藏
		- 发现技术:只在 Cisco LSP 中产生，根源是 LDP 分发标签的结果（参考 LSP 部分），不透明的隧道及其长度可以通过 LSE-TTL 确认
	- Invisible: traceroute 结果不带有 LSP，不包含 MPLS 信息
		- 含义：激活了 no-ttl-propagate 选项，RFC4950 实现与否都有可能
		- 分类
			1. PHP 模式下
				1. 发现技术：
					- RTLA(Return Tunnel Length Analysis)：返回隧道长度分析 ，即分析超时包和 echo-reply 返回路径长度的不同
					- FRPLA((Forward/Return Path Length Analysis)：往返隧道长度分析，即分析往返路径长度的不同，从 traceroute 探测和 reply 消息中获取
			2. UHP 模式下
				1. 发现技术：两个连续跳出现重复 IP，具体的，对于 IP-TTL 为 1 的包，Egress LER 不会减小该 TTL，而是转发包给下一跳，因此 Egress 不会出现在 trace 路径中，但下一跳会出现两次
## TNT
- TNT 能够恢复一条路径的**所有** MPLS 隧道，基于 Paris Traceroute 来避免负载均衡带来的问题
- TNT 工作模式
	- 检查隧道存在性：
		- indicators（指示器）：不需要额外探测提供可靠 MPLS 隧道存在的指示
			- 关心在哪能从原始 traceroute 直接恢复隧道
			- 一般用于 EXP 隧道（通过直接引用于 ICMP 超时消息的 **LSE** 显示出来）
			- 对于 OPA 隧道，引用的 **LSE-TTL** 需要满足 T(LSE_TTL)<=LSE-TTL<255, T(LSE-TTL)为固定的最小门限值，注意 OPA 隧道使用了 indicator 和 trigger，TNT 被动理解了隧道是不完整的，尝试用新的主动测量恢复内容
			- IMP 隧道通过 **qTTL 或 UTURN** 指示
				- 如果在 ICMP 超时消息中的 IP-TTL(qTTL)大于 1，这可能揭示了在 LSP 的 Ingress LER 处的 ttl-porpogate 选项（此后 LSP 中 LSE-TTL 递减，IP-TTL 不变）。对于 LSP 中后续的探测，qTTL 会按加 1 递增，形成增长的序列
				- UTURN 指示器
					- UTURN 依赖于这样的事实，默认，LSR 将 ICMP 超时消息发送给 Egress LER （其将一次将包转发给探测源），然而 LSR 在针对其它类型探测包（如 echo-request 包）可行的话，将使用它们自己的 IP 转发表直接回复。总而言之，超时包的返回路径比 echo-request 包更长，因而，UTURN 作为关联这些不同长度的指纹。 UTURN 计算公式
						- $$UTURN(Pi)=L^{TE}\_R-L^{ER}\_R=2*(LL-i+1)$$
					- 由于 iBGP 的路径差异性（path heterogeneity，特别的 IGP tie-break 规则），ICMP echo-reply 消息的 BGP 返回路径与超时回复消息的 BGP 返回路径不同，总之，UTURN 可能在每个中间跳不同，所以不必要完全准寻上述公式，实践中小的变化可能出现，特别的，UTURN 为 0 也可能隐藏一个真实的 IMP 跳
					- 对 Juniper 路由器来说，情况大不相同，默认（如没有激活 icmp-tunneling 特性，参见附录 IX-A.2），这些路由器将超时回复消息直接发送给源，而非转发给 Egress LER，此时 UTURN 无效。更多的，对于有着与 JunOS 同样指纹的路由器，UTURN 指示器和 RTLA 触发器的计算方法一致。所以，避免混淆，TNT 对这样的 OS 指纹引入了一个特例。此外，当 icmp-tunneling 激活，超时回复消息 TTL 从 254 开始，意味着与 echo-request 回复的巨大不同，在 图2中可以看出，UTURN(P1)=7 而非运行 Cisco OS 的 6
			- 指示器是 MPLS 的被动证据，并防止 TNT 发起新的探测（除了 LSE-TTL 也作为 OPA 隧道的触发器）。相反，触发器作为主动特征，可以使用而外的探测
		- triggers（触发器）：只要是无符号值揭示不可见隧道的存在的潜在可能,通过在路径长度不对称中的大的 shfit
			- 潜在的 INV UHP 隧道：会出现在使用 IOS 15.2 的 Cisco 路由器上，当接收到 TTL 为 1 的包时，Egress LER 不会减少 TTL，相反将其转发给下一跳。结果 Egress LER 不会出现在 trace 中，相反其下一跳出现两次。
			- RTLA 和 FPRLA 都基于这样的想法:发送给 VP 的回复也可能穿过 MPLS 云，这意味在 EH 处
			- 将采用 MIN(IP-TTL，LSE-TTL)操作。它们分别推断准确的（RTLA）和近似的（FPRLA）返回路径长度
				- 实际上，与 RTLA 不同(TE，ER 包返回路径长度相等)，FPRLA 受 BGP 路径不对称影响（可能产生错误警报，但只从 ECMP（负载均衡）产生）
				- RTLA 只对 JunOS 路由器有效，FRPLA 更一般
			- RTLA 和 FRPLA 影子（离开 LSP 后，依然触发）是 TNT 在 trace 中不寻找连续的不可见隧道
			- 在 UHP 中无法看到 min shift
			- 长度差异判定依据门限值（排除 BGP 和 ECMP 噪声），优化门限值设定可带来 80/20% 的正误比
			- 一跳同时匹配多个触发器，归属到最高优先级，如 RTLA > FRPLA 
	- 隐藏隧道恢复
		- DPR
		- BRPR
		- 在 Cisco IOS 15.2 上的默认配置，而外测试成为 buddy，需要检索 Egress LER 出口 IP 接口，强制把恢复从入 IP 接口。buddy 函数假设 Egress LER 和下一跳的点对点连接，考虑 /30 或 /31 前缀
		- UHP(BRPR) 在 IOS 12.4（如 没有 buddy 函数），对 PHP 同样原因:前缀是局部的，shift 在隧道终点前一跳；相反 TNT 需要在每一步使用 buddy 函数，对 IOS 15.2 激活 UHP，因为 EH 无声地在前一跳转发包



## TNT 使用
1. 相关参数（门限值设定）	
	1. T(RTLA),T(FRPLA)
