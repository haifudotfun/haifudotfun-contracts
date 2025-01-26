### **Haifus.fun**

#### **What is it?**

Haifus.fun is launchpad to fundraise automated agents that moves your crypto across defi platforms to compound your capital as quickly + safely as possible(e.g. a tokenized vehicle for ETH accumulation, onchain strategies for benefiting from arbitrages, etc).

Think of Haifus.fun as platform for strategies like **MicroStrategy, but entirely onchain and transparent**. If you’re familiar with how MicroStrategy operates, you have entire platform to do that on various digital assets.

---

### **How It Works**

0. **Haifu**
   * Haifu is the automated or coordinated strategy by AI or human to operate your crypto. The profit or loss after operation is distributed pro-rata to its haifu token.
1. **Fundraising**  
   * The protocol starts with an Haifu token as a pool funded by either whitelisted depositors or $HAIFU token holders.  
   * Early backers receive Haifu token, aligning their incentives with the Haifu's growth.  
2. **Operation**  
   * Haifu is operated in a way where it can generate benefits. This includes automating a stablecoin operations by liquidating CDP positions, liquidating bad debts, trading in arbitrage, etc.
3. **Redeptions**
    * After fund expires, all operated funds are converted into $HAIFU on CLOB, and backers can claim back their profit or loss from Haifu via claiming with their haifu token to get $HAIFU.

---




## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
