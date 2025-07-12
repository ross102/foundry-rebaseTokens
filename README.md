# Cross-Chain Rebase Token with Chainlink CCIP

This project implements a cross-chain rebasing ERC20 token architecture using [Chainlink CCIP](https://chain.link/ccip) for secure token transfers between EVM-compatible chains.

It includes:

- **RebaseToken** – A custom ERC20 token that supports per-user interest rates and rebasing logic.
- **RebaseTokenPool** – A CCIP-compatible pool that handles token transfers across chains.
- **Vault** – A local contract that mints and burns tokens based on user activity.

---

## 🔧 Contracts

### ✅ RebaseToken

An ERC20-compatible token with additional features:
- Supports **rebasing** – balances grow over time based on interest.
- Tracks **user-specific interest rates**.
- Provides:
  - `mint(address to, uint256 amount, uint256 userInterestRate)`
  - `burn(address from, uint256 amount)`

---

### ✅ RebaseTokenPool

Extends Chainlink’s `TokenPool` and overrides key CCIP lifecycle methods:
- `lockOrBurn()`:
  - Validates input and **burns tokens** on the source chain.
  - Encodes the sender’s interest rate for cross-chain transmission.
- `releaseOrMint()`:
  - Decodes interest rate on the destination chain.
  - **Mints tokens** to the receiver using the provided interest rate.

This allows users’ rebasing logic to be preserved across chains.

---

### ✅ Vault

A simple utility contract that:
- Holds and manages `RebaseToken` balances.
- Can **mint or burn tokens** based on internal logic.
- Useful for staking, deposits, or any mechanism that controls minting.

---

## 🔁 Cross-Chain Token Flow

1. User calls `lockOrBurn()` on **source chain pool**.
2. Tokens are burned and **interest rate is encoded** in `destPoolData`.
3. CCIP transmits data to destination chain.
4. Destination pool calls `releaseOrMint()`, **minting tokens** with the original interest rate.

---

## 🧪 Local Testing

Uses [Foundry](https://book.getfoundry.sh/) and [Chainlink Local Simulator](https://github.com/smartcontractkit/chainlink-local) for testing cross-chain behavior.

### Example Test Environment:
- Source chain: Sepolia (Fork)
- Destination chain: Arbitrum Sepolia (Fork)
- Simulator provides mock router, registry, and token proxy contracts.

---

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
