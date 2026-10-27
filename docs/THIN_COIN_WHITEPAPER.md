# THIN COIN (THIN) TECHNICAL WHITEPAPER
### Decentralized Sequential-64 CPU Proof-of-Work with On-Chain Loyalty Staking & Automated Market Architecture

**Publication Version:** 2.1 (October 2026)  
**Consensus Engine:** Sequential-64 Keccak-256 Serial Proof-of-Work  
**Network Execution Layer:** Base Mainnet (EVM Chain ID `8453`)  
**Standard:** ERC-20 with Built-in Staking & Non-Custodial Liquidity Lock  

---

## ABSTRACT

The proliferation of Proof-of-Work cryptocurrencies has historically succumbed to two failure modes: rapid hardware monopolization by specialized Application-Specific Integrated Circuits (ASICs) and centralized graphics processing unit (GPU) mining farms, or pre-mined token allocations where venture syndicates or founding teams extract liquidity from retail market participants. 

**Thin Coin (`THIN`)** introduces an equitable Proof-of-Work token architecture deployed directly onto Coinbase’s Ethereum Layer-2 network (**Base Mainnet**). By enforcing a strictly sequential 64-step iterative Keccak-256 hash pipeline, Thin Coin eliminates the parallelization advantage of massively multi-threaded GPUs and fixed-function ASICs. Ordinary consumer hardware—including legacy laptops, standard desktop PCs, and 5-watt single-board computers like the Raspberry Pi—competes on near-parity with enterprise hardware. 

Thin Coin integrates a self-balancing game-theoretic ecosystem featuring:
1. **A Bitcoin-equivalent 21,000,000 hard supply cap** with a 210,000-epoch programmatic halving schedule.
2. **A 300-second Anti-Monopoly Fairness Cooldown** that bars consecutive block sweeping by high-performance rigs.
3. **An Autonomous Emergency Difficulty Decay** that mathematically guarantees chain vitality in the event of hashrate volatility.
4. **An On-Chain MasterChef Loyalty Staking Pool (3.50%)** with atomic 1-transaction `mineAndStake()` compounding.
5. **A Golden Block Rollover Jackpot (1.50%)** hitting at a true 1-in-64 cryptographic mask (`0x3F`).
6. **A Sub-1% Protocol Contribution (0.90%)**, guaranteeing miners keep **94.10%** of all base block emissions.

---

## 1. THE PROBLEM STATEMENT: HARDWARE MONOPOLIES & TOKEN EXTRACTION

Traditional Proof-of-Work systems (e.g., Bitcoin SHA-256, Ethereum Ethash) rely on independent hash evaluations that are trivially parallelizable across thousands of matrix cores or custom application-specific silicon. As a consequence:
* Modern home users and casual participants are permanently disenfranchised from network consensus.
* Centralized mining syndicates control majority hashrates, dictating pool policies and creating systemic 51% attack vectors.

Conversely, modern Layer-2 and Layer-1 token projects have almost entirely abandoned Proof-of-Work in favor of arbitrary genesis minting, whereby 100% of the token supply is created via a single contract deployment. These tokens rely on artificial marketing, unverified unlock schedules, and inevitable liquidity depletion.

Thin Coin synthesizes the **provable scarcity and fair issuance of Bitcoin** with the **programmable composability and sub-cent transaction finality of the Ethereum EVM ecosystem**.

---

## 2. THE SEQUENTIAL-64 KECCAK CONSENSUS SPECIFICATION

### 2.1 The Serial Dependency Chain

To neutralize the compute advantage of GPUs and ASICs, Thin Coin requires that every nonce evaluation execute an irreducible series of 64 sequential Keccak-256 transformations:

$$\text{Step}_0 = \text{Keccak-256}(\text{Challenge} \mathbin{\Vert} \text{MinerAddress} \mathbin{\Vert} \text{Nonce})$$

$$\text{Step}_i = \text{Keccak-256}(\text{Step}_{i-1} \mathbin{\Vert} \text{Challenge} \mathbin{\Vert} i) \quad \forall \; i \in [1, 63]$$

$$\text{Digest} = \text{Step}_{63}$$

$$\text{Condition:} \quad \text{uint256}(\text{Digest}) \le \text{EffectiveTarget}$$

```
+-----------+     +------------+     +-------+
| Challenge | +   | Miner Addr | +   | Nonce |
+-----+-----+     +-----+------+     +---+---+
      |                 |                |
      +-----------------+----------------+
                        |
                 [ Keccak-256 ]
                        |
                        v
                    ( Step 0 )
                        |
                 +------+------+
                 |             |
           [ Step 0 ] + [ Challenge ] + [ 1 ]
                 |
           [ Keccak-256 ]
                 |
                 v
             ( Step 1 )
                 |
                 .
                 .  (64 Serial Steps)
                 .
                 v
            ( Step 63 ) ──> uint256(Digest) <= Target ? ──> [ SOLVED ]
```

### 2.2 Mathematical Proof of ASIC Resistance

Because each iterative step $i$ strictly requires the 32-byte digest produced by step $i-1$, **it is mathematically impossible to compute step 63 in parallel across shader threads or matrix arrays**. 

A GPU with 10,000 CUDA cores is forced to run each thread sequentially down the 64-step pipeline at its single-core clock speed (typically 1.5–2.2 GHz). A modern desktop CPU running at 3.5–4.5 GHz executes serial Keccak operations with lower memory bus latency than a GPU. Consequently, home CPUs match or exceed GPU power efficiency on Thin Coin.

---

## 3. GAME-THEORETIC GUARDRAILS & NETWORK STABILITY

### 3.1 The 300-Second Anti-Monopoly Cooldown
To prevent a single multi-threaded workstation from monopolizing consecutive epochs, `ThinPoWToken.sol` enforces an on-chain lockout:

$$\text{If } (\text{Miner} == \text{LastMiner} \;\land\; \text{BlockTimestamp} < \text{LastEpochTime} + 300) \implies \mathbf{REVERT}$$

The moment an entity solves a block, they are locked out for 300 seconds (5 minutes) unless a distinct miner solves a subsequent block. This creates an exclusive, guaranteed execution window for lower-power CPUs, older laptops, and single-board computers.

### 3.2 Self-Healing Emergency Difficulty Decay
If network hashrate temporarily declines or network difficulty spikes, mining cannot stall. If the elapsed duration since the last solved epoch exceeds $2 \times \text{TARGET\_EPOCH\_TIME}$ (10 minutes), the smart contract dynamically halves the mining difficulty every 5 minutes elapsed:

$$\text{MissedWindows} = \left\lfloor \frac{\text{Elapsed}}{\text{TARGET\_EPOCH\_TIME}} \right\rfloor - 1$$

$$\text{EffectiveTarget} = \text{MiningTarget} \ll \text{MissedWindows}$$

Target values double with each missed window, ensuring that any single CPU can clear the epoch and restore normal difficulty progression.

---

## 4. TOKENOMICS & PROGRAMMATIC HALVING SCHEDULE

Thin Coin strictly enforces a 21,000,000 THIN maximum hard cap.

```
Total Max Supply: 21,000,000 THIN (100.0%)
│
├── Genesis Mint: 100,000 THIN (0.476%)
│   ├── Pool 1 (THIN/WETH): 35,000 THIN (80% Locked in ThinLPLocker)
│   ├── Pool 2 (THIN/FRAC): 35,000 THIN (80% Locked in ThinLPLocker)
│   ├── Dev Staking Vault:  20,000 THIN (Locked in ThinStakingLocker)
│   └── Community Reserve:  10,000 THIN (Unrestricted Liquid Dev Transferable)
│
└── Proof-of-Work Mining: 20,900,000 THIN (99.524%)
    ├── Miner Base Reward:  94.10% (47.05 THIN / block)
    ├── Loyalty Staking:     3.50% ( 1.75 THIN / block)
    ├── Golden Jackpot Pot:  1.50% ( 0.75 THIN / block)
    └── Protocol Dev Fee:    0.90% ( 0.45 THIN / block)
```

### 4.1 Halving Trajectory

$$\text{Reward}(n) = \frac{50 \times 10^{18}}{2^{\lfloor n / 210,000 \rfloor}} \quad \text{wei}$$

* **Epochs 0 – 209,999:** 50.00 THIN / epoch (~2 years)
* **Epochs 210,000 – 419,999:** 25.00 THIN / epoch
* **Epochs 420,000 – 629,999:** 12.50 THIN / epoch
* **Terminal Emission:** Supply ceiling reached at 21,000,000 THIN.

### 4.2 Mining Distribution Split

Every block emission is divided on-chain into four programmatic streams:

| Allocation | Basis Points | % Split | Purpose |
| :--- | :--- | :--- | :--- |
| **Miner Base Reward** | `9,410` | **94.10%** | Direct reward to the hardware solver. |
| **Loyalty Staking Pool** | `350` | **3.50%** | Passive dividend distributed to token stakers. |
| **Golden Block Jackpot** | `150` | **1.50%** | Feeds the 1-in-64 rollover lottery pot. |
| **Protocol Ecosystem** | `90` | **0.90%** | Ongoing development and infrastructure maintenance. |

---

## 5. DUAL-POOL AMM LIQUIDITY & TRIANGULAR ARBITRAGE

Thin Coin utilizes an automated two-pool Automated Market Maker (AMM) structure on Uniswap V2 on Base:

1. **Pool 1 (THIN / WETH):** The Primary Cash Gateway. Connects Thin Coin to Ethereum Layer-2 capital, allowing DEX aggregators and traders to acquire THIN with ETH.
2. **Pool 2 (THIN / FRAC):** The Proof-of-Work Ecosystem Bridge. Pairs THIN directly with FractalCoin (`FRAC`) at a 1:1 genesis parity.

### 5.1 The Triangular Arbitrage Mechanism

The existence of both pools creates an automated triangular price-stabilization circuit:

$$\text{WETH} \overset{\text{Uniswap V2}}{\longleftrightarrow} \text{THIN} \overset{\text{Uniswap V2}}{\longleftrightarrow} \text{FRAC} \overset{\text{Uniswap V2}}{\longleftrightarrow} \text{WETH}$$

When trading activity occurs on either token, decentralized arbitrage bots execute simultaneous rebalancing swaps across all three pairs. Because Uniswap V2 levies a **0.30% liquidity fee** on every swap, both pools continuously accumulate trading fees for liquidity providers, ensuring that backing reserves compound organically over time.

---

## 6. SMART CONTRACT ARCHITECTURE & SECURITY AUDIT SUMMARY

### 6.1 Audit & DEX Scanner Compatibility

The Thin Coin contract suite is engineered to achieve a **100% Green Score** across automated vulnerability analyzers (GoPlus, QuickIntel, TokenSniffer, DexScreener):

* **Honeypot Evaluation:** Passes. ERC-20 `transfer` and `transferFrom` functions contain zero transfer fees, zero hidden balance deductions, and no blacklisting logic.
* **Mint Authority:** Passes. There is **no owner mint function**. The internal `_mint` mechanism is cryptographically gated to `_mineCore()` upon submission of a valid PoW solution.
* **No Owner Pause / Freeze:** The contract contains no emergency stop or pause functions. Trading and mining cannot be halted by any administrator.
* **Non-Custodial Time-Locks:**
  * `contracts/src/ThinLPLocker.sol`: Zero-fee, strictly extend-only LP locker protecting pool depth.
  * `contracts/src/ThinStakingLocker.sol`: Extend-only timelock for developer loyalty staking positions.
* **Reentrancy Protection:** All state modifications follow the Checks-Effects-Interactions pattern reinforced by OpenZeppelin's `ReentrancyGuard`.

---

## 7. VERIFICATION AND DEPLOYMENT SPECIFICATIONS

* **EVM Target:** Base Mainnet (`8453`)
* **Solidity Compiler:** Solc `0.8.24` (Optimizer: 200 runs, Cancun EVM target)
* **Token Address:** Generated post-broadcast via `contracts/deploy_mainnet.sh`
* **Single-File Flattened Source:** Available in `contracts/src/ThinPoWToken_flat.sol` for instant BaseScan block explorer verification.

---

*Thin Coin represents an open, permissionless, CPU-friendly standard for fair Proof-of-Work issuance on modern Layer-2 infrastructure.*
