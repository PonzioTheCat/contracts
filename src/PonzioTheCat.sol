// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { ERC20Rebasable } from "src/ERC20Rebasable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IStake } from "src/interfaces/IStake.sol";
import { IPonzioTheCat } from "src/interfaces/IPonzioTheCat.sol";
import { IERC20Rebasable } from "src/interfaces/IERC20Rebasable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Pair } from "src/interfaces/UniswapV2/IUniswapV2Pair.sol";
import { IERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title PonzioTheCat
 * @notice Implementation of the PONZIO token.
 * @dev PONZIO is a rebasable token, which means that the total supply can be updated. Its particularity is that
 * every 4 weeks the supply is divided by 2, and in between the supply is constantly decreasing linearly. The balances
 * stays fixed for 4 hours. Then every 4 hours, the supply is updated, and the balances are updated
 * proportionally.
 * At each rebase, 13.37% of the debased supply is sent to the feesCollector.
 */
contract PonzioTheCat is IPonzioTheCat, ERC20Rebasable, Ownable {
    using Math for uint256;
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    /// @notice The name of the token
    string internal constant NAME = "Ponzio The Cat";
    /// @notice The symbol of the token
    string internal constant SYMBOL = "Ponzio";
    /// @notice The number of decimals of the token
    uint8 internal constant DECIMALS = 18;

    /// @inheritdoc IPonzioTheCat
    uint256 public constant INITIAL_SUPPLY = 21_000_000 * 10 ** DECIMALS; // in wei
    uint256 public constant HALVING_EVERY = 4 weeks;
    /// @inheritdoc IPonzioTheCat
    uint256 public constant DEBASE_EVERY = 4 hours;
    /// @inheritdoc IPonzioTheCat
    uint256 public constant NB_DEBASE_PER_HALVING = HALVING_EVERY / DEBASE_EVERY;
    /// @inheritdoc IPonzioTheCat
    uint256 public constant MINIMUM_TOTAL_SUPPLY = 10 ** 12; // in wei
    /// @inheritdoc IPonzioTheCat
    uint256 public immutable DEPLOYED_TIME;

    /// @inheritdoc IPonzioTheCat
    uint256 public constant FEES_STAKING = 1337; // in BPS = 13.37%
    /// @inheritdoc IPonzioTheCat
    uint256 public constant FEES_BASE = 10_000; // in BPS

    /// @notice the address of the fees collector
    address internal _feesCollector;
    /// @notice boolean used to check if fees are collected
    bool internal _maxSharesReached = false;

    /// @notice the Uniswap V2 pair address
    IUniswapV2Pair internal _uniswapV2Pair;
    /// @notice true if the contract has been initialized
    bool private _initialized = false;

    /// @notice the total supply at the last update
    uint216 private _previousTotalSupply;
    /// @notice the timestamp of the last update
    uint40 private _previousUpdateTimestamp;

    constructor() ERC20Rebasable(NAME, SYMBOL, INITIAL_SUPPLY) Ownable(msg.sender) {
        DEPLOYED_TIME = block.timestamp;
        _previousTotalSupply = uint216(INITIAL_SUPPLY);
        _previousUpdateTimestamp = uint40(block.timestamp);
    }

    /* -------------------------------------------------------------------------- */
    /*                             external functions                             */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IPonzioTheCat
    function feesCollector() external view returns (address) {
        return _feesCollector;
    }

    /// @inheritdoc IPonzioTheCat
    function maxSharesReached() external view returns (bool) {
        return _maxSharesReached;
    }

    /// @inheritdoc IPonzioTheCat
    function uniswapV2Pair() external view returns (IUniswapV2Pair) {
        return _uniswapV2Pair;
    }

    /// @inheritdoc IPonzioTheCat
    function setUniswapV2Pair(address uniV2PoolAddr) external onlyOwner {
        _uniswapV2Pair = IUniswapV2Pair(uniV2PoolAddr);
        emit UniV2PoolPairSet(uniV2PoolAddr);
    }

    /// @inheritdoc IPonzioTheCat
    function setFeesCollector(address feeCollector) external onlyOwner {
        if (!_initialized) {
            revert PONZIO_notInitialized();
        } else if (feeCollector == address(0)) {
            revert PONZIO_feeCollectorZeroAddress();
        }
        updateTotalSupply();
        _feesCollector = feeCollector;

        emit FeesCollectorSet(feeCollector);
    }

    /// @inheritdoc IPonzioTheCat
    function setBlacklistForUpdateSupply(address addrToBlacklist, bool value) external onlyOwner {
        _blacklistForUpdateSupply[addrToBlacklist] = value;

        emit BlacklistForUpdateSupplySet(addrToBlacklist, value);
    }

    /// @inheritdoc IPonzioTheCat
    function initialize(address feeCollector, address uniV2PoolAddr) external onlyOwner {
        if (_initialized) {
            revert PONZIO_alreadyInitialized();
        }
        if (feeCollector == address(0)) {
            revert PONZIO_feeCollectorZeroAddress();
        }

        _initialized = true;

        _uniswapV2Pair = IUniswapV2Pair(uniV2PoolAddr);
        emit UniV2PoolPairSet(uniV2PoolAddr);

        _blacklistForUpdateSupply[uniV2PoolAddr] = true;
        emit BlacklistForUpdateSupplySet(uniV2PoolAddr, true);

        _feesCollector = feeCollector;
        emit FeesCollectorSet(feeCollector);
    }

    /// @inheritdoc IPonzioTheCat
    function realBalanceOf(address account) external view returns (uint256 balance_) {
        (uint256 newTotalShares, uint256 newTotalSupply,) = computeNewState();

        balance_ = sharesToToken(_sharesOf[account], newTotalShares, newTotalSupply);
    }

    /* -------------------------------------------------------------------------- */
    /*                              public functions                              */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc ERC20Rebasable
    function updateTotalSupply() public override(ERC20Rebasable, IERC20Rebasable) {
        if (_previousUpdateTimestamp == uint40(block.timestamp)) {
            return;
        }

        (uint256 newTotalSupply, uint256 fees) = computeSupply();
        address feeCollector = _feesCollector;

        // fees are proportional to (_previousTotalSupply - newTotalSupply),
        // so if fees == 0 then we can be sure that _previousTotalSupply == newTotalSupply
        // we then only need to update the total supply if fees != 0
        if (fees != 0 && feeCollector != address(0)) {
            // If max shares are reached, the new total supply is the
            // minimum total supply so this assignment is still valid.
            uint256 oldTotalSupply = _previousTotalSupply;
            _previousTotalSupply = newTotalSupply.toUint216();
            _previousUpdateTimestamp = uint40(block.timestamp);

            // We need to mint tokenAmount of tokens, but by minting this amount, we will influence the totalShares.
            // For this reason, sharesToToken() cannot be used. In the end, the following 2 equations have to be
            // resolved:
            //
            // new_totalShares = old_totalShares + shareToMint
            // tokenAmount = totalSupply * shareToMint / new_totalShares
            //
            // tokenAmount, totalSupply and old_totalShares are known.
            // The only unknown is shareToMint
            //
            // After resolution we have: shareToMint = totalShares * tokenAmount / (totalSupply - tokenAmount)
            uint256 oldTotalShares = _totalShares;
            if (fees >= newTotalSupply) {
                _mintShares(feeCollector, oldTotalShares);
            } else {
                _mintShares(feeCollector, oldTotalShares.mulDiv(fees, newTotalSupply - fees));
            }

            emit TotalSupplyUpdated(oldTotalSupply, newTotalSupply, oldTotalShares, _totalShares, fees);

            /// @dev This check prevents revert in case the feesCollector is an EOA
            if (address(feeCollector).code.length != 0) {
                /// @dev This try/catch prevents revert in case of feesCollector does not implement sync()
                try IStake(feeCollector).sync() { } catch { }
            }

            _uniswapV2Pair.sync();
        }
    }

    /// @inheritdoc IPonzioTheCat
    function computeSupply() public view returns (uint256 totalSupply_, uint256 fees_) {
        uint256 previousTotalSupply = _previousTotalSupply;

        // early return if max shares are reached
        if (_maxSharesReached) {
            return (previousTotalSupply, 0);
        }

        uint256 previousUpdateTimestamp = _previousUpdateTimestamp;

        if (previousTotalSupply != MINIMUM_TOTAL_SUPPLY) {
            uint256 _timeSinceDeploy = block.timestamp - DEPLOYED_TIME;
            uint256 _tsLastHalving = INITIAL_SUPPLY / (2 ** (_timeSinceDeploy / HALVING_EVERY));

            // slither-disable-next-line weak-prng
            totalSupply_ = _tsLastHalving
                - (_tsLastHalving * ((_timeSinceDeploy % HALVING_EVERY) / DEBASE_EVERY)) / NB_DEBASE_PER_HALVING / 2;

            if (totalSupply_ < MINIMUM_TOTAL_SUPPLY) {
                totalSupply_ = MINIMUM_TOTAL_SUPPLY;
            }

            fees_ = ((previousTotalSupply - totalSupply_) * FEES_STAKING) / FEES_BASE;
        } else {
            totalSupply_ = MINIMUM_TOTAL_SUPPLY;

            if (block.timestamp - previousUpdateTimestamp < HALVING_EVERY) {
                fees_ = (MINIMUM_TOTAL_SUPPLY * FEES_STAKING * (block.timestamp - previousUpdateTimestamp))
                    / HALVING_EVERY / FEES_BASE;
            } else {
                fees_ = (MINIMUM_TOTAL_SUPPLY * FEES_STAKING) / FEES_BASE;
            }
        }
    }

    /// @inheritdoc IPonzioTheCat
    function computeNewState() public view returns (uint256 totalShares_, uint256 totalSupply_, uint256 fees_) {
        uint256 totalShares = _totalShares;
        (totalSupply_, fees_) = computeSupply();

        uint256 newShares;
        if (fees_ >= totalSupply_) {
            // if fees are greater than the total supply, we mint totalShares of shares, so we double the supply of the
            // shares, the fees will be equal to half of the total supply
            newShares = totalShares;
            fees_ = totalSupply_ / 2;
        } else {
            newShares = totalShares.mulDiv(fees_, totalSupply_ - fees_);
        }

        bool success;
        (success, totalShares_) = totalShares.tryAdd(newShares);
        if (!success) {
            totalShares_ = type(uint256).max;
            fees_ = sharesToToken((type(uint256).max - totalShares), totalShares_, totalSupply_);
        }
    }

    /// @inheritdoc IERC20
    function balanceOf(address account) public view override(ERC20Rebasable, IERC20) returns (uint256) {
        return _sharesOf[account].mulDiv(_previousTotalSupply, _totalShares);
    }

    /// @inheritdoc IERC20Permit
    function nonces(address owner) public view override(ERC20Rebasable, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    /// @inheritdoc IERC20
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return _previousTotalSupply;
    }

    /* -------------------------------------------------------------------------- */
    /*                             internal functions                             */
    /* -------------------------------------------------------------------------- */

    /**
     * @notice Mint shares to an account.
     * @param account The account to mint the shares to.
     * @param shares The number of shares to mint.
     */
    function _mintShares(address account, uint256 shares) internal override {
        uint256 totalShares = _totalShares;
        (bool success,) = totalShares.tryAdd(shares);

        if (!success) {
            super._mintShares(account, type(uint256).max - totalShares);
            _maxSharesReached = true;
            emit MaxSharesReached(block.timestamp);
        } else {
            super._mintShares(account, shares);
        }
    }
}
