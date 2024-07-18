pragma solidity ^0.8.24;

/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * Copyright (C) 2024 DeFiGeek Community Japan
 */

//solhint-disable max-line-length
//solhint-disable no-inline-assembly

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title Token Token
 * @notice Divident. Inflatable but the rate is to be decreasing.
 */
contract TokenDistribution {
    event UpdateMiningParameters(uint256 time, uint256 rate, uint256 supply);
    event SetMinter(address tokenMinter);
    event SetAdmin(address admin);

    address public tokenAddr;
    address public tokenMinter;
    address public admin;

    // Supply parameters
    uint256 public initialRate;
    uint256 public rateReductionTime;
    uint256 public rateReductionCoefficient;
    uint256 public rateDenominator;
    uint256 public inflationDelay;

    // Supply variables
    int128 public miningEpoch;
    uint256 public startEpochTime;
    uint256 public rate;

    uint256 public startEpochSupply;
    uint256 public startTime;
    uint256 public totalMintAmount;

    constructor(
        address token_,
        uint256 initialRate_,
        uint256 rateReductionTime_,
        uint256 rateReductionCoefficient_,
        uint256 inflationDelay_,
        uint256 totalMintAmount_
    ) {
        tokenAddr = token_;
        uint256 _decimals = uint256(IERC20Metadata(token_).decimals());
        admin = msg.sender;

        initialRate = (initialRate_ * (10 ** _decimals)) / rateReductionTime_;
        rateReductionTime = rateReductionTime_;
        rateReductionCoefficient = ((100 * (10 ** _decimals)) /
            (100 - rateReductionCoefficient_));
        rateDenominator = 10 ** _decimals;
        inflationDelay = inflationDelay_;

        startEpochTime = block.timestamp + inflationDelay - rateReductionTime;
        startTime = block.timestamp;
        miningEpoch = -1;
        // rate = 0;
        // startEpochSupply = 0;
        totalMintAmount = totalMintAmount_;
        IERC20(tokenAddr).transferFrom(
            msg.sender,
            address(this),
            totalMintAmount_
        );
    }

    /**
     * @dev Update mining rate and supply at the start of the epoch
     *      Any modifying mining call must also call this
     */
    function _updateMiningParameters() internal {
        uint256 _rate = rate;
        uint256 _startEpochSupply = startEpochSupply;

        startEpochTime += rateReductionTime;
        ++miningEpoch;

        if (_rate == 0 && miningEpoch < 1) {
            _rate = initialRate;
        } else {
            _startEpochSupply += _rate * rateReductionTime;
            startEpochSupply = _startEpochSupply;
            _rate = (_rate * rateDenominator) / rateReductionCoefficient;
        }

        rate = _rate;

        emit UpdateMiningParameters(block.timestamp, _rate, _startEpochSupply);
    }

    /**
     * @notice Update mining rate and supply at the start of the epoch
     * @dev Callable by any address, but only once per epoch
     *      Total supply becomes slightly larger if(this function is called late
     */
    function updateMiningParameters() external {
        require(
            block.timestamp >= startEpochTime + rateReductionTime,
            "dev: too soon!"
        ); // dev: too soon!
        _updateMiningParameters();
    }

    /**
     * @notice Get timestamp of the current mining epoch start
     *         while simultaneously updating mining parameters
     * @return Timestamp of the epoch
     */
    function startEpochTimeWrite() external returns (uint256) {
        uint256 _startEpochTime = startEpochTime;
        if (block.timestamp >= _startEpochTime + rateReductionTime) {
            _updateMiningParameters();
            return startEpochTime;
        } else {
            return _startEpochTime;
        }
    }

    /**
     * @notice Get timestamp of the next mining epoch start
     *         while simultaneously updating mining parameters
     * @return Timestamp of the next epoch
     */
    function futureEpochTimeWrite() external returns (uint256) {
        uint256 _startEpochTime = startEpochTime;
        if (block.timestamp >= _startEpochTime + rateReductionTime) {
            _updateMiningParameters();
            return startEpochTime + rateReductionTime;
        } else {
            return _startEpochTime + rateReductionTime;
        }
    }

    function _availableSupply() internal view returns (uint256) {
        return startEpochSupply + (block.timestamp - startEpochTime) * rate;
    }

    // @notice Current number of tokens in existence (claimed or unclaimed)
    function availableSupply() external view returns (uint256) {
        return _availableSupply();
    }

    /**
     * @notice How much supply is mintable from start timestamp till end timestamp
     * @param start Start of the time interval (timestamp)
     * @param end End of the time interval (timestamp)
     * @return Tokens mintable from `start` till `end`
     */
    function mintableInTimeframe(
        uint256 start,
        uint256 end
    ) external view returns (uint256) {
        require(start <= end, "dev: start > end"); // dev: start > end
        uint256 to_mint;
        uint256 currentEpochTime = startEpochTime;
        uint256 currentRate = rate;

        // Special case if(end is in future (not yet minted) epoch
        if (end > currentEpochTime + rateReductionTime) {
            currentEpochTime += rateReductionTime;
            currentRate =
                (currentRate * rateDenominator) /
                rateReductionCoefficient;
        }

        require(
            end <= currentEpochTime + rateReductionTime,
            "dev: too far in future"
        ); // dev: too far in future

        // Curve will not work in 1000 years. Darn!
        for (uint i; i < 999; ) {
            if (end >= currentEpochTime) {
                uint256 currentEnd = end;
                if (currentEnd > currentEpochTime + rateReductionTime) {
                    currentEnd = currentEpochTime + rateReductionTime;
                }

                uint256 currentStart = start;
                if (currentStart >= currentEpochTime + rateReductionTime) {
                    break; // We should never get here but what if...
                } else if (currentStart < currentEpochTime) {
                    currentStart = currentEpochTime;
                }
                to_mint += currentRate * (currentEnd - currentStart);
                if (start >= currentEpochTime) {
                    break;
                }
            }

            currentEpochTime -= rateReductionTime;
            currentRate =
                (currentRate * rateReductionCoefficient) /
                rateDenominator; // double-division with rounding made rate a bit less => good
            require(currentRate <= initialRate, "This should never happen"); // This should never happen

            unchecked {
                ++i;
            }
        }

        return to_mint;
    }

    /**
     * @notice Set the tokenMinter address
     * @dev Only callable once, when tokenMinter has not yet been set
     * @param _tokenMinter Address of the tokenMinter
     */
    function setMinter(address _tokenMinter) external onlyAdmin {
        require(
            _tokenMinter != address(0),
            "dev: can set the tokenMinter only once, at creation"
        ); // dev: can set the tokenMinter only once, at creation
        tokenMinter = _tokenMinter;
        emit SetMinter(_tokenMinter);
    }

    /**
     * @notice Set the new admin.
     * @dev After all is set up, admin only can change the token name
     * @param _admin New admin address
     */
    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
        emit SetAdmin(_admin);
    }

    /**
     * @notice Mint `_value` tokens and assign them to `_to`
     * @dev Emits a Transfer event originating from 0x00
     * @param _to The account that will receive the created tokens
     * @param _value The amount that will be created
     * @return bool success
     */
    function mint(address _to, uint256 _value) external returns (bool) {
        require(msg.sender == tokenMinter, "dev: tokenMinter only"); // dev: tokenMinter only
        require(_to != address(0), "dev: zero address"); // dev: zero address

        if (block.timestamp >= startEpochTime + rateReductionTime) {
            _updateMiningParameters();
        }
        require(
            IERC20(tokenAddr).balanceOf(address(this)) + _value <=
                _availableSupply(),
            "dev: exceeds allowable mint amount"
        );

        IERC20(tokenAddr).transferFrom(address(this), _to, _value);

        return true;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "dev: admin only");
        _;
    }
}
