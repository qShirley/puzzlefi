# 开发流程

## 1. 什么是 Rooch

[Rooch](https://rooch.network) 是一个快速、模块化、安全、开发人员友好的基础架构解决方案，用于构建 Web3 原生应用程序。

Rooch 于 2023 年 06 月 28 日，发布了第一个版本，版本名为 **萌芽（Sprouting）**，版本号为 `v0.1`。

## 2. 安装 Rooch

### 2.1 下载

在 [Rooch 的 GitHub 发布页面](https://github.com/rooch-network/rooch/releases)可以找到预构建的二进制文件压缩包和相应版本的源码压缩包。如果想要体验 Git 版本，可以参考这个页面来[编译安装 Rooch](https://rooch.network/build/getting-started/installation#compile-and-install)，下面引导你安装 Rooch 的 Release 版本。

```shell
wget https://github.com/rooch-network/rooch/releases/latest/download/rooch-ubuntu-latest.zip
```

> 注意：请选择对应自己系统的版本，我这里使用 Linux 的版本来演示。

### 2.2 解压

```shell
unzip rooch-ubuntu-latest.zip
```

解压文件存放在 `rooch-artifacts` 目录里，`rooch` 是我们预编译好的二进制程序。

```shell
rooch-artifacts
├── README.md
└── rooch
```

### 2.3 运行

进入解压文件夹 `rooch-artifacts` 并测试程序是否正常。

```shell
cd rooch-artifacts
./rooch
```

如果你能看到下面的输出内容，说明程序一切正常。

```shell
[joe@mx rooch]$ rooch
Usage: rooch <COMMAND>

Commands:
  account      Tool for interacting with accounts
  init         Tool for init with rooch
  move         CLI frontend for the Move compiler and VM
  server       Start Rooch network
  state        Get states by accessPath
  object       Get object by object id
  resource     Get account resource by tag
  transaction  Tool for interacting with transaction
  event        Tool for interacting with event
  abi
  env          Interface for managing multiple environments
  session-key  Session key Commands
  rpc
  help         Print this message or the help of the given subcommand(s)

Options:
  -h, --help     Print help
  -V, --version  Print version
```

### 2.4 加入 PATH

为了方便后续使用，建议将 `rooch` 放入能被系统环境变量 `PATH` 检索的路径，或者将当前的解压目录通过 `export` 导出到 `PATH` 中。

- 方法一，复制 `rooch` 这个程序复制到 `/usr/local/bin` 目录中（**推荐**）

```shell
sudo cp rooch /usr/local/bin
```

- 方法二，导出路径（不推荐）

使用下面这段小脚本将 `rooch` 添加到 Bash shell 的 `PATH`。

```shell
echo "export PATH=\$PATH:$PWD" >> ~/.bashrc
source ~/.bashrc
```

## 3. 初始化 Rooch 配置

```shell
rooch init
```

运行初始化配置的命令后，会在用户的主目录（`$HOME`）创建一个 `.rooch` 目录，并生成 Rooch 账户的相关配置信息。

## 4. 创建新的 Rooch 项目

这部分将讲述Puzzlefi合约的开发过程

### 4.1 创建 Move 项目

使用 `rooch` 集成的 `move new` 命令来创建一个名为 `puzzlefi` 的合约。

```shell
rooch move new puzzlefi
```

生成的 Move 项目里包含一个配置文件 `Move.toml` 和一个用于存放 Move 源代码的 `sources` 目录。

```shell
puzzlefi
├── Move.toml
└── sources
```

我们可以简单看一下 `Move.toml` 文件包含了哪些内容。

```toml
[package]
name = "simple_blog"
version = "0.0.1"

[dependencies]
MoveStdlib = { git = "https://github.com/rooch-network/rooch.git", subdir = "frameworks/move-stdlib", rev = "main" }
MoveosStdlib = { git = "https://github.com/rooch-network/rooch.git", subdir = "frameworks/moveos-stdlib", rev = "main" }
RoochFramework = { git = "https://github.com/rooch-network/rooch.git", subdir = "frameworks/rooch-framework", rev = "main" }

[addresses]
simple_blog = "_"
std = "0x1"
moveos_std = "0x2"
rooch_framework = "0x3"
```

- 在 TOML 文件中包含三个表：`package`、`dependencies` 和 `addresses`，存放项目所需的一些元信息。
- `package` 表用来存放项目的一些描述信息，这里包含两个键值对 `name` 和 `version` 来描述项目名和项目的版本号。
- `dependencies` 表用来存放项目所需依赖的元数据。
- `addresses` 表用来存放项目地址以及项目所依赖模块的地址，第一个地址是初始化 Rooch 配置时，生成在 `$HOME/.rooch/rooch_config/rooch.yaml` 中的地址。

为了方便其他开发者部署，我们把 `puzzlefi` 的地址用 `_` 替代，然后部署的时候通过 `--named--addresses` 来指定。

### 4.2 快速体验

这小节里，将引导你编写一个石头剪刀布的游戏合约，并在 Rooch 中运行起来，体验`编写 -> 编译 -> 发布 -> 调用`合约这样一个基本流程。

我们在 `sources` 目录里新建一个 `puzzle_game.move` 文件，并开始编写我们的博客合约。

#### 4.2.1 定义游戏的全局配置

1. 我们需要定义一个```Global```的结构体来控制游戏的全局配置，定义一个```FingerGame```结构体来表示每一轮的结果，通过加上```<phantom CoinType: key+store>```的范型约束 来支持构建不同代币类型的游戏配置和池子。
2. 通过```Object<CoinStore<CoinType>>```类型来构造代币池来存储代币，用```Table```来存储每一轮的结果。

```move
    struct Global<phantom CoinType: key+store> has key {
        /// 当前游戏进行到第几轮
        current_round: u64,
        /// 储存池子中的代币
        coin_store: Object<CoinStore<CoinType>>,
        /// 游戏上次更新的时间，每次操作都会更新
        last_update_timestamp: u64,
        /// 一次最少在StakePool质押多少token
        minimum_stake_amount: u256,
        /// 一次最多在StakePool质押多少token
        maximum_stake_amount: u256,
        /// 每次下注最小金额是多少
        minimum_bet_amount: u256,
        /// 每次最大下注金额是多少
        maximum_bet_amount: u256,
        /// 记录每一轮游戏结果
        finger_game_record: Table<u64, FingerGame<CoinType>>,
        /// 协议收取的费用，100 代币 1%
        protocol_fee: u256,
        /// 协议收取的费用存放的地方
        protocol_fee_store: Object<CoinStore<CoinType>>,
        /// 是否临时关闭游戏，管理员才可以操作
        is_open: bool
    }
    struct FingerGame<phantom CoinType: key+store> has key, store {
        /// 游戏轮数
        round: u64,
        /// 这轮游戏是否结束
        is_fininsh: bool,
        /// 博弈双方的金额临时存放处
        coin: Object<CoinStore<CoinType>>,
        /// 这轮下注的金额
        amount: u256,
        /// 玩家猜测的结果
        player_guessing: u64,
        /// 实际结果
        protocol_result: u64,
        /// 玩家地址
        player: address,
        /// 胜利者地址
        winner: address
    }

    /// 管理员权限
    struct AdminCap has key, store, drop {}
```

```fun```函数只会在合约```publish```的时候执行一次，我们用来构造一个```Global<GasCoin>```类型的游戏配置，并把管理员权限给部署者：

```move
    fun init() {
        /// 获取模块地址签名
        let signer = module_signer<Global<GasCoin>>();
        /// 将Global<GasCoin>这个resouce存入模块地址
        move_resource_to(&signer, Global<GasCoin>{
            current_round: 0,
            coin_store: coin_store::create_coin_store<GasCoin>(),
            last_update_timestamp: now_milliseconds(),
            // 1 RGC
            minimum_stake_amount: 1 * u256::pow(10, 8),
            // 100 RGC
            maximum_stake_amount: 100 * u256::pow(10, 8),
            // 1 RGC
            minimum_bet_amount: 1 * u256::pow(10, 8),
            // 500 RGC
            maximum_bet_amount: 500 * u256::pow(10, 8),
            finger_game_record: table::new(),
            protocol_fee: DEFAULT_PROTOCOL_FEE,
            protocol_fee_store: coin_store::create_coin_store<GasCoin>(),
            is_open: true
        });
        /// 发送管理员权限给合约部署者
        let admin_cap = object::new_named_object(AdminCap {});
            transfer(admin_cap, sender())
    }
```
```public```可见性的```fun```可以被其他合约调用，加上了```entry```则可以被前端调用，```&signer```类型在前端调用时我们不需要传递
```move
    public entry fun stake<CoinType: key+store>(
        signer: &signer,
        amount: u256
    ){
        do_stake<CoinType>(signer, amount)
    }

    public fun do_stake<CoinType: key+store>(
        signer: &signer,
        amount: u256
    ){
        /// 质押前先结算上轮游戏，结算逻辑定义在后面
        settlement_finger_game<CoinType>();
        let module_signer = module_signer<Global<CoinType>>();
        /// 获取全局配置的可变引用，borrow_mut_resource在获取resource时可以修改他，borrow_resource则获取的是只读的引用
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        /// assert！方法确保游戏没有被关闭，第一个参数如果不是true，则在调用的时候会执行失败，前端返回moveabord且值为第二个参数
        assert!(global.is_open, ErrorNotOpen);
        /// 从用户账户中取出数量为amount的代币
        let stake_coin = account_coin_store::withdraw<CoinType>(signer, amount);
        let coin_value = coin::value(&stake_coin);
        assert!(coin_value>= global.minimum_stake_amount, ErrorStakeAmount);
        assert!(coin_value<= global.maximum_stake_amount, ErrorStakeAmount);
        /// 获取PFC<CoinType>类型的代币流通总量
        let total_pfc_supply = coin::supply(borrow_coin_info<CoinType>());
        /// 计算会新创建多少PFC代币，方法定义在后面
        let new_pfc_amount =  calculate_pfc_amount(coin_value, coin_store::balance(&global.coin_store), total_pfc_supply);
        global.last_update_timestamp = now_milliseconds();
        /// 将代币存入池子
        coin_store::deposit(&mut global.coin_store, stake_coin);
        /// 铸造PFC<CoinType>并发送给用户
        account_coin_store::deposit(sender(), puzzlefi_coin::mint<CoinType>(new_pfc_amount));
    }
    public entry fun redeem<CoinType: key+store>(
        signer: &signer,
        pfc_amount: u256
    ){
        do_redeem<CoinType>(signer, pfc_amount)
    }

    public fun do_redeem<CoinType: key+store>(
        signer: &signer,
        pfc_amount: u256
    ){
        /// 赎回前先结算上轮游戏，结算逻辑定义在后面
        settlement_finger_game<CoinType>();
        let total_pfc_supply = coin::supply(borrow_coin_info<CoinType>());
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        assert!(global.is_open, ErrorNotOpen);
        /// 计算要赎回多少PFC代币，方法定义在后面
        let redeem_coin_amount = calculate_coin_amount(pfc_amount, coin_store::balance(&global.coin_store), total_pfc_supply);
        let redeem_coin =  coin_store::withdraw(&mut global.coin_store, redeem_coin_amount);
        let protocol_fee = calculate_protocol_fee(redeem_coin_amount, global.protocol_fee);
        let protocol_coin = coin::extract(&mut redeem_coin, protocol_fee);
        coin_store::deposit(&mut global.protocol_fee_store, protocol_coin);
        account_coin_store::deposit(sender(), redeem_coin);
        /// 从用户账户中提出PFC<CoinType>并销毁
        puzzlefi_coin::burn(account_coin_store::withdraw<PFC<CoinType>>(signer, pfc_amount));
        global.last_update_timestamp = now_milliseconds();
    }
```
接着我们定义创建新游戏的方法和结算游戏的方法，创建新游戏只需要传递用户猜测的值以及下注的金额即可，结算游戏的方法目前只能在合约内部调用
```move
    /// the finger-guessing game,
    /// The lucky star is 0
    /// The stone is 1-3
    /// The Scissor is 4-6
    /// The paper is 7-9
    public entry fun new_finger_game<CoinType: key+store>(
        signer: &signer,
        player_guessing: u64,
        bet_amount: u256,
    ){
        settlement_finger_game<CoinType>();
        /// 确保用户猜测的值是在允许范围内
        assert!(player_guessing <= 9, ErrorGuessingNumber);
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        assert!(global.is_open, ErrorNotOpen);
        /// 如果当前轮数不存在则创建新的一轮游戏
        if (!table::contains(&global.finger_game_record, global.current_round)) {
            let bet_coin = account_coin_store::withdraw<CoinType>(signer, bet_amount);
            let coin_value = coin::value(&bet_coin);
            assert!(coin_value>= global.minimum_bet_amount, ErrorBetAmount);
            assert!(coin_value<= global.maximum_bet_amount, ErrorBetAmount);
            let protocol_coin = if (player_guessing == 0) {
            coin_store::withdraw(&mut global.coin_store, bet_amount * 8)
            }else {
                coin_store::withdraw(&mut global.coin_store, bet_amount)
            };
            let new_game = FingerGame<CoinType>{
                round: global.current_round,
                is_fininsh: false,
                coin: coin_store::create_coin_store(),
                amount: bet_amount,
                player_guessing,
                protocol_result: 10000,
                player: sender(),
                winner: @rooch_framework
            };
            coin_store::deposit(&mut new_game.coin, bet_coin);
            coin_store::deposit(&mut new_game.coin, protocol_coin);
            table::add(&mut global.finger_game_record, global.current_round, new_game);
            global.last_update_timestamp = now_milliseconds()
        }
    }
    /// 结算游戏
    fun settlement_finger_game<CoinType: key+store>(){
        let module_signer = module_signer<Global<CoinType>>();
        let global = borrow_mut_resource<Global<CoinType>>(address_of(&module_signer));
        assert!(global.is_open, ErrorNotOpen);
        /// 确保当前这轮存在才结算
        if (table::contains(&global.finger_game_record, global.current_round)){
            let game = table::borrow_mut(&mut global.finger_game_record, global.current_round);
            game.is_fininsh = true;
            let reward_amount = coin_store::balance(&game.coin);
            let reward_coin = coin_store::withdraw(&mut game.coin, reward_amount);
            /// 运用链上随机数作为随机种子来生成结果
            let protocol_result = simple_rng::rand_u64_range(0, 10);
            game.protocol_result = protocol_result;
            if (protocol_result == 0) {
                let winner = if (game.player_guessing == 0) {
                    if (account_coin_store::is_accept_coin<CoinType>(game.player)){
                        account_coin_store::deposit(game.player, reward_coin);
                    }else {
                        coin_store::deposit(&mut global.coin_store, reward_coin)
                    };
                    game.winner = game.player;
                    game.winner
                }else {
                    coin_store::deposit(&mut global.coin_store, reward_coin);
                    game.winner = @0x0;
                    game.winner
                };
                emit(SettleGameEvent{
                    round: global.current_round,
                    amount: reward_amount,
                    winner,

                })
            }else {
                let winner = if (game.player_guessing == 0){
                    // player guessing is Lucky star
                    @0x0
                }else if (game.player_guessing < 4){
                    // player guessing is stone
                    if (protocol_result < 4) {
                        @rooch_framework
                    }else if(protocol_result < 7) {
                        game.player
                    }else {
                        @0x0
                    }
                }else if (game.player_guessing < 7) {
                    // player guessing is scissors
                    if (protocol_result < 4) {
                        @0x0
                    }else if(protocol_result < 7) {
                        @rooch_framework
                    }else {
                        game.player
                    }
                }else {
                    // player guessing is paper
                    if (protocol_result < 4) {
                        game.player
                    }else if(protocol_result < 7) {
                        @0x0
                    }else {
                        @rooch_framework
                    }
                };
                game.winner = winner;
                if (winner == game.player) {
                    if (account_coin_store::is_accept_coin<CoinType>(game.player)){
                        account_coin_store::deposit(game.player, reward_coin)
                    }else {
                        coin_store::deposit(&mut global.coin_store, reward_coin)
                    }
                }else if (winner == @0x0) {
                    coin_store::deposit(&mut global.coin_store, reward_coin)
                }else {
                    if (account_coin_store::is_accept_coin<CoinType>(game.player)){
                        account_coin_store::deposit(game.player, coin::extract(&mut reward_coin, reward_amount/2));
                    };
                    coin_store::deposit(&mut global.coin_store, reward_coin)
                };
                emit(SettleGameEvent{
                    round: global.current_round,
                    amount: reward_amount,
                    winner,

                })
            };
            /// 更新游戏轮数
            global.current_round = global.current_round + 1;
            global.last_update_timestamp = now_milliseconds()
        }


    }
```

#### 4.2.2 编译 Move 合约

在发布合约前，需要编译我们的合约。这里通过 `--named-addresses` 来指定 `puzzlefi` 模块的地址为当前设备上的 `default` 地址。

```shell
rooch move build --named-addresses puzzlefi=default
```

编译结束后，如果没有错误，会在最后看到 `Success` 的提示信息。

```shell
INCLUDING DEPENDENCY MoveStdlib
INCLUDING DEPENDENCY MoveosStdlib
INCLUDING DEPENDENCY RoochFramework
BUILDING puzzlefi
Success
```

此时，项目文件夹会多出一个 `build` 目录，里面存放的就是 Move 编译器生成的合约字节码文件以及合约**完整的**源代码。

#### 4.2.3 运行 Rooch 服务器

我们再打开另外一个终端，运行下面这条命令，Rooch 服务器会在本地启动 Rooch 容器服务，用于处理并响应合约的相关行为。

```shell
rooch server start
```

当启动 Rooch 服务后，会在最后看到这两条信息，表明 Rooch 的服务已经正常启动。

```shell
2023-07-03T15:44:33.315228Z  INFO rooch_rpc_server: JSON-RPC HTTP Server start listening 0.0.0.0:6767
2023-07-03T15:44:33.315256Z  INFO rooch_rpc_server: Available JSON-RPC methods : ["wallet_accounts", "eth_blockNumber", "eth_getBalance", "eth_gasPrice", "net_version", "eth_getTransactionCount", "eth_sendTransaction", "rooch_sendRawTransaction", "rooch_getAnnotatedStates", "eth_sendRawTransaction", "rooch_getTransactions", "rooch_executeRawTransaction", "rooch_getEventsByEventHandle", "rooch_getTransactionByHash", "rooch_executeViewFunction", "eth_getBlockByNumber", "rooch_getEvents", "eth_feeHistory", "eth_getTransactionByHash", "eth_getBlockByHash", "eth_getTransactionReceipt", "rooch_getTransactionInfosByOrder", "eth_estimateGas", "eth_chainId", "rooch_getTransactionInfosByHash", "wallet_sign", "rooch_getStates"]
```

> 提示：我们在前一个终端窗口操作合约相关的逻辑（功能）时，可以观察这个终端窗口的输出。

#### 4.2.4 发布 Move 合约

```shell
rooch move publish --named-addresses puzzlefi=default
```

当你看到类似这样的输出（`status` 为 `executed`），就可以确认发布操作已经成功执行了：

```shell
{
  //...
  "execution_info": {
    //...
    "status": {
      "type": "executed"
    }
  },
  //...
}
```

在运行 Rooch 服务的终端也可以看到响应的处理信息：

```shell
2023-07-03T16:02:11.691028Z  INFO connection{remote_addr=127.0.0.1:58770 conn_id=0}: jsonrpsee_server::server: Accepting new connection 1/100
2023-07-03T16:02:13.690733Z  INFO rooch_proposer::actor::proposer: [ProposeBlock] block_number: 0, batch_size: 1
```
此时，我们的博客合约已经发布到链上了
