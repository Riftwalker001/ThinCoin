// SPDX-License-Identifier: MIT
pragma solidity =0.8.24 ^0.8.20;

// lib/openzeppelin-contracts/contracts/utils/Context.sol

// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/IERC20.sol)

/**
 * @dev Interface of the ERC-20 standard as defined in the ERC.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

// lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol

// OpenZeppelin Contracts (last updated v5.1.0) (utils/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If EIP-1153 (transient storage) is available on the chain you're deploying at,
 * consider using {ReentrancyGuardTransient} instead.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;

    uint256 private _status;

    /**
     * @dev Unauthorized reentrant call.
     */
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be NOT_ENTERED
        if (_status == ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

        // Any calls to nonReentrant after this point will fail
        _status = ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = NOT_ENTERED;
    }

    /**
     * @dev Returns true if the reentrancy guard is currently set to "entered", which indicates there is a
     * `nonReentrant` function in the call stack.
     */
    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == ENTERED;
    }
}

// lib/openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol

// OpenZeppelin Contracts (last updated v5.1.0) (interfaces/draft-IERC6093.sol)

/**
 * @dev Standard ERC-20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC-721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in ERC-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC-1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC-1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/extensions/IERC20Metadata.sol)

/**
 * @dev Interface for the optional metadata functions from the ERC-20 standard.
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}

// lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol

// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC20/ERC20.sol)

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC-20
 * applications.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata, IERC20Errors {
    mapping(address account => uint256) private _balances;

    mapping(address account => mapping(address spender => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `value`.
     */
    function transfer(address to, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `value` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 value) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, value);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Skips emitting an {Approval} event indicating an allowance update. This is not
     * required by the ERC. See {xref-ERC20-_approve-address-address-uint256-bool-}[_approve].
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `value`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `value`.
     */
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _transfer(address from, address to, uint256 value) internal {
        if (from == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        if (to == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(from, to, value);
    }

    /**
     * @dev Transfers a `value` amount of tokens from `from` to `to`, or alternatively mints (or burns) if `from`
     * (or `to`) is the zero address. All customizations to transfers, mints, and burns should be done by overriding
     * this function.
     *
     * Emits a {Transfer} event.
     */
    function _update(address from, address to, uint256 value) internal virtual {
        if (from == address(0)) {
            // Overflow check required: The rest of the code assumes that totalSupply never overflows
            _totalSupply += value;
        } else {
            uint256 fromBalance = _balances[from];
            if (fromBalance < value) {
                revert ERC20InsufficientBalance(from, fromBalance, value);
            }
            unchecked {
                // Overflow not possible: value <= fromBalance <= totalSupply.
                _balances[from] = fromBalance - value;
            }
        }

        if (to == address(0)) {
            unchecked {
                // Overflow not possible: value <= totalSupply or value <= fromBalance <= totalSupply.
                _totalSupply -= value;
            }
        } else {
            unchecked {
                // Overflow not possible: balance + value is at most totalSupply, which we know fits into a uint256.
                _balances[to] += value;
            }
        }

        emit Transfer(from, to, value);
    }

    /**
     * @dev Creates a `value` amount of tokens and assigns them to `account`, by transferring it from address(0).
     * Relies on the `_update` mechanism
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead.
     */
    function _mint(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidReceiver(address(0));
        }
        _update(address(0), account, value);
    }

    /**
     * @dev Destroys a `value` amount of tokens from `account`, lowering the total supply.
     * Relies on the `_update` mechanism.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * NOTE: This function is not virtual, {_update} should be overridden instead
     */
    function _burn(address account, uint256 value) internal {
        if (account == address(0)) {
            revert ERC20InvalidSender(address(0));
        }
        _update(account, address(0), value);
    }

    /**
     * @dev Sets `value` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address owner, address spender, uint256 value) internal {
        _approve(owner, spender, value, true);
    }

    /**
     * @dev Variant of {_approve} with an optional flag to enable or disable the {Approval} event.
     *
     * By default (when calling {_approve}) the flag is set to true. On the other hand, approval changes made by
     * `_spendAllowance` during the `transferFrom` operation set the flag to false. This saves gas by not emitting any
     * `Approval` event during `transferFrom` operations.
     *
     * Anyone who wishes to continue emitting `Approval` events on the`transferFrom` operation can force the flag to
     * true using the following override:
     *
     * ```solidity
     * function _approve(address owner, address spender, uint256 value, bool) internal virtual override {
     *     super._approve(owner, spender, value, true);
     * }
     * ```
     *
     * Requirements are the same as {_approve}.
     */
    function _approve(address owner, address spender, uint256 value, bool emitEvent) internal virtual {
        if (owner == address(0)) {
            revert ERC20InvalidApprover(address(0));
        }
        if (spender == address(0)) {
            revert ERC20InvalidSpender(address(0));
        }
        _allowances[owner][spender] = value;
        if (emitEvent) {
            emit Approval(owner, spender, value);
        }
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `value`.
     *
     * Does not update the allowance value in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Does not emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 value) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < value) {
                revert ERC20InsufficientAllowance(spender, currentAllowance, value);
            }
            unchecked {
                _approve(owner, spender, currentAllowance - value, false);
            }
        }
    }
}

// src/ThinPoWToken.sol

/**
 * @title ThinPoWToken (THIN)
 * @notice High-fairness Sequential-64 Keccak-256 Proof-of-Work token on Base Mainnet.
 * Features:
 *  1. Bitcoin-style 21,000,000 THIN maximum supply with 210,000-epoch halving.
 *  2. 64-step Serial Dependency Proof-of-Work algorithm (anti-ASIC / anti-GPU).
 *  3. 300-second consecutive block cooldown (Old-PC fairness window).
 *  4. Emergency Difficulty Decay (auto-decay prevents chain stall).
 *  5. Built-in Loyalty Staking Pool (3.50% drip) with `mineAndStake()` 1-tx auto-compounding.
 *  6. Golden Block 1-in-64 Rollover Jackpot (1.50% allocation).
 *  7. Dev ecosystem contribution lowered to 0.90% (94.10% goes directly to miner).
 */
contract ThinPoWToken is ERC20, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 21_000_000 ether;
    uint256 public constant MAX_GENESIS_SUPPLY = 2_100_000 ether; // Max 10%
    uint256 public constant INITIAL_REWARD = 50 ether;
    uint256 public constant HALVING_INTERVAL = 210_000;
    uint256 public constant TARGET_EPOCH_TIME = 300; // 5 minutes
    uint256 public constant ADJUSTMENT_INTERVAL = 10; // Retarget every 10 epochs
    uint256 public constant SEQUENTIAL_STEPS = 64; // Serial dependency chain depth

    // Fee & Distribution Splits (10,000 BPS = 100%)
    uint256 public constant BPS_DENOMINATOR = 10_000;
    uint256 public constant MINER_REWARD_BPS = 9_410; // 94.10% to Miner
    uint256 public constant STAKER_MINING_BPS = 350;  // 3.50% to Loyalty Staking Pool
    uint256 public constant JACKPOT_MINING_BPS = 150; // 1.50% to Golden Block Jackpot
    uint256 public constant DEV_MINING_BPS = 90;      // 0.90% to Dev Wallet

    // Golden Block Mask: bottom 6 bits == 0x3F (exact 1-in-64 chance on valid PoW)
    uint256 public constant GOLDEN_BLOCK_MASK = 0x3F;
    uint256 public constant JACKPOT_WIN_BPS = 8_000; // 80% payout / 20% rollover

    uint256 private constant ACC_PRECISION = 1e18;

    uint256 public constant MAX_TARGET = type(uint256).max >> 7;
    uint256 public constant INITIAL_TARGET = type(uint256).max >> 8;
    uint256 public constant MIN_TARGET = 1 << 160;

    address public immutable devWallet;

    bytes32 public challengeNumber;
    uint256 public miningTarget;
    uint256 public epochCount;
    uint256 public lastEpochTime;
    uint256 public intervalStartTime;
    address public lastMiner;

    // Staking & Jackpot State
    uint256 public totalStaked;
    uint256 public accRewardPerShare;
    uint256 public unallocatedRewards;
    uint256 public jackpotPot;
    uint256 public goldenBlocksMined;
    address public lastGoldenWinner;
    uint256 public lastGoldenPayout;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public claimableRewards;
    mapping(address => uint256) public lastMinedEpoch;
    mapping(address => uint256) public blocksMinedBy;
    mapping(address => uint256) public goldenBlocksWonBy;

    error GenesisSupplyTooHigh();
    error MaxSupplyReached();
    error ConsecutiveEpochCooldown(uint256 unlockTime);
    error InvalidProofOfWork(uint256 digest, uint256 target);
    error ZeroAmount();
    error InsufficientStake();

    event EpochMined(
        uint256 indexed epoch,
        address indexed miner,
        uint256 totalMinerPayout,
        uint256 jackpotWon,
        bool autoStaked,
        uint256 nonce,
        bytes32 digest,
        bytes32 newChallenge
    );
    event GoldenBlockWon(
        uint256 indexed epoch,
        address indexed winner,
        uint256 jackpotAmount,
        bytes32 digest
    );
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(address genesisRecipient, uint256 genesisSupply) ERC20("Thin PoW Coin", "THIN") {
        if (genesisSupply > MAX_GENESIS_SUPPLY) revert GenesisSupplyTooHigh();
        devWallet = genesisRecipient != address(0) ? genesisRecipient : msg.sender;

        if (genesisSupply > 0 && genesisRecipient != address(0)) {
            _mint(genesisRecipient, genesisSupply);
        }

        miningTarget = INITIAL_TARGET;
        lastEpochTime = block.timestamp;
        intervalStartTime = block.timestamp;
        bytes32 prevHash = block.number > 0 ? blockhash(block.number - 1) : bytes32(0);
        challengeNumber = keccak256(abi.encodePacked(prevHash, block.prevrandao, address(this), block.timestamp));
    }

    /// @notice Computes 64-step sequential digest for challenge, miner, and nonce.
    function computeDigest(bytes32 challenge, address miner, uint256 nonce) public pure returns (bytes32 digest) {
        digest = keccak256(abi.encodePacked(challenge, miner, nonce));
        for (uint256 i = 1; i < SEQUENTIAL_STEPS; ) {
            digest = keccak256(abi.encodePacked(digest, challenge, i));
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Checks if valid PoW digest satisfies the 1-in-64 Golden Block jackpot mask.
    function isGoldenDigest(bytes32 digest) public pure returns (bool) {
        return (uint256(digest) & GOLDEN_BLOCK_MASK) == GOLDEN_BLOCK_MASK;
    }

    /// @notice Returns active target incorporating Emergency Difficulty Decay if elapsed time > 10m.
    function effectiveTarget() public view returns (uint256 target) {
        target = miningTarget;
        uint256 elapsed = block.timestamp > lastEpochTime ? block.timestamp - lastEpochTime : 0;
        if (elapsed > TARGET_EPOCH_TIME * 2) {
            uint256 missedWindows = (elapsed / TARGET_EPOCH_TIME) - 1;
            if (missedWindows >= 244) {
                return MAX_TARGET;
            }
            uint256 decayed = target << missedWindows;
            if (decayed < target || decayed > MAX_TARGET) {
                return MAX_TARGET;
            }
            return decayed;
        }
    }

    /// @notice Current epoch block reward with halving schedule.
    function currentReward() public view returns (uint256) {
        if (totalSupply() >= MAX_SUPPLY) return 0;
        uint256 halvings = epochCount / HALVING_INTERVAL;
        if (halvings >= 64) return 0;
        uint256 reward = INITIAL_REWARD >> halvings;
        uint256 remaining = MAX_SUPPLY - totalSupply();
        return reward > remaining ? remaining : reward;
    }

    /// @notice Standard liquid mining call.
    function mine(uint256 nonce) external returns (uint256 totalMinerPayout) {
        return _mineCore(msg.sender, nonce, false);
    }

    /// @notice Auto-compounding 1-tx mine and stake.
    function mineAndStake(uint256 nonce) external returns (uint256 totalMinerPayout) {
        return _mineCore(msg.sender, nonce, true);
    }

    function _mineCore(address miner, uint256 nonce, bool autoStake) internal returns (uint256 totalMinerPayout) {
        uint256 totalEpochReward = currentReward();
        if (totalEpochReward == 0) revert MaxSupplyReached();

        // 300s consecutive-block cooldown for fairness
        if (miner == lastMiner && epochCount > 0 && block.timestamp < lastEpochTime + TARGET_EPOCH_TIME) {
            revert ConsecutiveEpochCooldown(lastEpochTime + TARGET_EPOCH_TIME);
        }

        uint256 activeTarget = effectiveTarget();
        bytes32 digest = computeDigest(challengeNumber, miner, nonce);
        if (uint256(digest) > activeTarget) {
            revert InvalidProofOfWork(uint256(digest), activeTarget);
        }

        if (activeTarget > miningTarget) {
            miningTarget = activeTarget;
        }

        unchecked {
            ++epochCount;
            ++blocksMinedBy[miner];
        }
        lastMiner = miner;
        lastMinedEpoch[miner] = epochCount;
        lastEpochTime = block.timestamp;

        if (epochCount % ADJUSTMENT_INTERVAL == 0) {
            _retarget();
        }

        challengeNumber = keccak256(abi.encodePacked(challengeNumber, digest, miner, block.timestamp));

        (uint256 payout, uint256 jackpotWon) = _processEpochRewards(miner, totalEpochReward, digest, autoStake);
        totalMinerPayout = payout;

        emit EpochMined(epochCount, miner, totalMinerPayout, jackpotWon, autoStake, nonce, digest, challengeNumber);
    }

    function _processEpochRewards(
        address miner,
        uint256 totalEpochReward,
        bytes32 digest,
        bool autoStake
    ) internal returns (uint256 totalMinerPayout, uint256 jackpotWon) {
        uint256 stakerReward = (totalEpochReward * STAKER_MINING_BPS) / BPS_DENOMINATOR;
        uint256 jackpotContribution = (totalEpochReward * JACKPOT_MINING_BPS) / BPS_DENOMINATOR;
        uint256 devReward = (totalEpochReward * DEV_MINING_BPS) / BPS_DENOMINATOR; // 0.90%
        uint256 baseMinerReward = totalEpochReward - stakerReward - jackpotContribution - devReward; // 94.10%

        if (devReward > 0) {
            _mint(devWallet, devReward);
        }

        uint256 contractMint = stakerReward + jackpotContribution;
        if (contractMint > 0) {
            _mint(address(this), contractMint);
        }
        jackpotPot += jackpotContribution;

        if (isGoldenDigest(digest) && jackpotPot > 0) {
            jackpotWon = (jackpotPot * JACKPOT_WIN_BPS) / BPS_DENOMINATOR;
            jackpotPot -= jackpotWon;
            unchecked {
                ++goldenBlocksMined;
                ++goldenBlocksWonBy[miner];
            }
            lastGoldenWinner = miner;
            lastGoldenPayout = jackpotWon;
            emit GoldenBlockWon(epochCount, miner, jackpotWon, digest);
        }

        totalMinerPayout = baseMinerReward + jackpotWon;

        if (autoStake) {
            _harvest(miner);
            if (baseMinerReward > 0) {
                _mint(address(this), baseMinerReward);
            }
            stakedBalance[miner] += totalMinerPayout;
            totalStaked += totalMinerPayout;
            if (unallocatedRewards > 0) {
                uint256 toDistribute = unallocatedRewards;
                unallocatedRewards = 0;
                accRewardPerShare += (toDistribute * ACC_PRECISION) / totalStaked;
            }
            rewardDebt[miner] = (stakedBalance[miner] * accRewardPerShare) / ACC_PRECISION;
            emit Staked(miner, totalMinerPayout);
        } else {
            if (baseMinerReward > 0) {
                _mint(miner, baseMinerReward);
            }
            if (jackpotWon > 0) {
                _transfer(address(this), miner, jackpotWon);
            }
        }

        if (stakerReward > 0) {
            _distributeStakerRewards(stakerReward);
        }
    }

    function _harvest(address user) internal {
        if (totalStaked > 0 && unallocatedRewards > 0) {
            uint256 toDistribute = unallocatedRewards;
            unallocatedRewards = 0;
            accRewardPerShare += (toDistribute * ACC_PRECISION) / totalStaked;
        }
        uint256 userStake = stakedBalance[user];
        if (userStake > 0) {
            uint256 accrued = (userStake * accRewardPerShare) / ACC_PRECISION - rewardDebt[user];
            if (accrued > 0) {
                claimableRewards[user] += accrued;
            }
        }
    }

    function _distributeStakerRewards(uint256 amount) internal {
        if (amount == 0) return;
        if (totalStaked == 0) {
            unallocatedRewards += amount;
        } else {
            uint256 totalToDistribute = amount + unallocatedRewards;
            if (unallocatedRewards > 0) {
                unallocatedRewards = 0;
            }
            accRewardPerShare += (totalToDistribute * ACC_PRECISION) / totalStaked;
        }
    }

    function _retarget() internal {
        uint256 actualTime = block.timestamp > intervalStartTime ? block.timestamp - intervalStartTime : 1;
        uint256 idealTime = TARGET_EPOCH_TIME * ADJUSTMENT_INTERVAL;

        if (actualTime < idealTime / 4) {
            actualTime = idealTime / 4;
        } else if (actualTime > idealTime * 4) {
            actualTime = idealTime * 4;
        }

        uint256 newTarget = (miningTarget / idealTime) * actualTime;
        if (newTarget < MIN_TARGET) {
            newTarget = MIN_TARGET;
        } else if (newTarget > MAX_TARGET) {
            newTarget = MAX_TARGET;
        }

        miningTarget = newTarget;
        intervalStartTime = block.timestamp;
    }

    // -------------------------------------------------------------------------
    // Public Staking & Yield Portal
    // -------------------------------------------------------------------------

    function pendingRewards(address user) external view returns (uint256) {
        uint256 userStake = stakedBalance[user];
        uint256 currentAcc = accRewardPerShare;
        if (totalStaked > 0 && unallocatedRewards > 0) {
            currentAcc += (unallocatedRewards * ACC_PRECISION) / totalStaked;
        }
        uint256 newlyAccrued = (userStake * currentAcc) / ACC_PRECISION - rewardDebt[user];
        return claimableRewards[user] + newlyAccrued;
    }

    function stake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        _harvest(msg.sender);

        _transfer(msg.sender, address(this), amount);
        stakedBalance[msg.sender] += amount;
        totalStaked += amount;

        if (unallocatedRewards > 0) {
            uint256 toDistribute = unallocatedRewards;
            unallocatedRewards = 0;
            accRewardPerShare += (toDistribute * ACC_PRECISION) / totalStaked;
        }

        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accRewardPerShare) / ACC_PRECISION;
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < amount) revert InsufficientStake();
        _harvest(msg.sender);

        stakedBalance[msg.sender] -= amount;
        totalStaked -= amount;
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        _transfer(address(this), msg.sender, amount);
        emit Unstaked(msg.sender, amount);
    }

    function claimRewards() external nonReentrant returns (uint256 reward) {
        _harvest(msg.sender);
        reward = claimableRewards[msg.sender];
        if (reward == 0) revert ZeroAmount();

        claimableRewards[msg.sender] = 0;
        rewardDebt[msg.sender] = (stakedBalance[msg.sender] * accRewardPerShare) / ACC_PRECISION;

        _transfer(address(this), msg.sender, reward);
        emit RewardsClaimed(msg.sender, reward);
    }
}
