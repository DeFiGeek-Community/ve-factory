// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "src/Interfaces/IVeToken.sol";
import "src/Storage/MultiTokenFeeDistributorSchema.sol";
import "src/Storage/Storage.sol";

contract MultiTokenFeeDistributor is Initializable, ReentrancyGuardUpgradeable {
    uint256 public constant WEEK = 7 days;

    event CommitAdmin(address indexed admin);
    event ApplyAdmin(address indexed admin);
    event ToggleAllowCheckpointToken(bool toggleFlag);
    event CheckpointToken(address indexed tokenAddress, uint256 time, uint256 tokens);
    event Claimed(
        address indexed tokenAddress, address indexed recipient, uint256 amount, uint256 claimEpoch, uint256 maxEpoch
    );
    event eventTokensPerWeek(uint256 time, uint256 value);
    event eventVeSupply(uint256 time, uint256 value);
    event eventBalance(uint256 time, uint256 value);

    /**
     * @notice Initializes the contract with necessary parameters.
     * @param votingEscrow_ The address of the VotingEscrow contract.
     * @param admin_ The address of the admin.
     * @param emergencyReturn_ The address where tokens are sent if the contract is killed.
     */
    function initialize(address votingEscrow_, address admin_, address emergencyReturn_) public initializer {
        __ReentrancyGuard_init();

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        $.votingEscrow = votingEscrow_;
        $.admin = admin_;
        $.emergencyReturn = emergencyReturn_;
    }

    /**
     * @notice Internal function to update the token checkpoint.
     * @param tokenAddress_ The address of the token to checkpoint.
     */
    function _checkpointToken(address tokenAddress_) internal {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[tokenAddress_];
        uint256 _tokenBalance = IERC20(tokenAddress_).balanceOf(address(this));
        // tokenDataマッピングを使用して、トークンごとの状態を取得
        uint256 _toDistribute = _tokenBalance - $token.tokenLastBalance;
        $token.tokenLastBalance = _tokenBalance;

        uint256 _t = $token.lastTokenTime;
        uint256 _sinceLast = block.timestamp - _t;
        uint256 _currentWeek = block.timestamp / WEEK;
        uint256 _sinceLastInWeeks = _currentWeek - (_t / WEEK);

        /*
        If _sinceLast has exceeded 20 weeks,
        set _t to the beginning of the week that is 19 weeks prior to the current block time.

        |-x-|-0-|-0-|-0-|-0-|-0-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|-1-|0.5●-|-
        0   1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25    26
        x: Last checkpoint 
        ●: New checkpoint

        In this case, we start the calculation from (the beginning of) week 6. 
        No fee will be allocated to the weeks prior to week 5.
        */
        if (_sinceLastInWeeks >= 20) {
            _t = ((block.timestamp - (WEEK * 19)) / WEEK) * WEEK;
            _sinceLast = block.timestamp - _t;
        }

        $token.lastTokenTime = block.timestamp;
        uint256 _thisWeek = (_t / WEEK) * WEEK;
        uint256 _nextWeek;

        for (uint256 i; i < 20;) {
            _nextWeek = _thisWeek + WEEK;
            if (block.timestamp < _nextWeek) {
                if (_sinceLast == 0 && block.timestamp == _t) {
                    $token.tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    $token.tokensPerWeek[_thisWeek] += (_toDistribute * (block.timestamp - _t)) / _sinceLast;
                }
                emit eventTokensPerWeek(_thisWeek, $token.tokensPerWeek[_thisWeek]);
                break;
            } else {
                if (_sinceLast == 0 && _nextWeek == _t) {
                    $token.tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    $token.tokensPerWeek[_thisWeek] += (_toDistribute * (_nextWeek - _t)) / _sinceLast;
                }
                emit eventTokensPerWeek(_thisWeek, $token.tokensPerWeek[_thisWeek]);
            }
            _t = _nextWeek;
            _thisWeek = _nextWeek;
            unchecked {
                ++i;
            }
        }

        emit CheckpointToken(tokenAddress_, block.timestamp, _toDistribute);
    }

    /**
     *
     *
     * @notice Allows an external caller to checkpoint a token, subject to certain conditions.
     * @param tokenAddress_ The address of the token to checkpoint.
     * @dev Calculates the total number of tokens to be distributed in a given week.
     *      During setup for the initial distribution this function is only callable
     *      by the contract owner. Beyond initial distro, it can be enabled for anyone
     *      to call.
     */
    function checkpointToken(address tokenAddress_) external {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[tokenAddress_];

        require(
            msg.sender == $.admin || ($.canCheckpointToken && block.timestamp > $token.lastTokenTime + 1 hours),
            "Unauthorized"
        );

        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        _checkpointToken(tokenAddress_);
    }

    /**
     * @notice Finds the epoch corresponding to a given timestamp for veToken.
     * @param ve_ The address of the veToken contract.
     * @param timestamp_ The timestamp to find the epoch for.
     * @return uint256 The epoch number.
     */
    function _findTimestampEpoch(address ve_, uint256 timestamp_) internal view returns (uint256) {
        uint256 _min;
        uint256 _max = IVeToken(ve_).epoch();

        unchecked {
            for (uint256 i; i < 128; ++i) {
                if (_min >= _max) {
                    break;
                }
                uint256 _mid = (_min + _max + 2) / 2;
                FeeDistributorSchema.Point memory _pt = IVeToken(ve_).pointHistory(_mid);
                if (_pt.ts <= timestamp_) {
                    _min = _mid;
                } else {
                    _max = _mid - 1;
                }
            }
        }
        return _min;
    }

    /**
     * @notice Finds the user epoch for a given timestamp.
     * @param ve_ The address of the veToken contract.
     * @param user_ The address of the user.
     * @param timestamp_ The timestamp to find the user epoch for.
     * @param maxUserEpoch_ The maximum epoch to consider.
     * @return uint256 The user epoch.
     */
    function _findTimestampUserEpoch(address ve_, address user_, uint256 timestamp_, uint256 maxUserEpoch_)
        internal
        view
        returns (uint256)
    {
        uint256 _min;
        uint256 _max = maxUserEpoch_;

        unchecked {
            for (uint256 i; i < 128; ++i) {
                if (_min >= _max) {
                    break;
                }
                uint256 _mid = (_min + _max + 2) / 2;
                FeeDistributorSchema.Point memory _pt = IVeToken(ve_).userPointHistory(user_, _mid);
                if (_pt.ts <= timestamp_) {
                    _min = _mid;
                } else {
                    _max = _mid - 1;
                }
            }
        }
        return _min;
    }

    /**
     * @notice Get the veToken balance for a user at a specific timestamp.
     * @param user_ Address to query balance for.
     * @param timestamp_ Epoch time.
     * @return uint256 veToken balance.
     */
    function veForAt(address user_, uint256 timestamp_) external view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();

        address _ve = $.votingEscrow;
        uint256 _maxUserEpoch = IVeToken(_ve).userPointEpoch(user_);
        uint256 _epoch = _findTimestampUserEpoch(_ve, user_, timestamp_, _maxUserEpoch);
        FeeDistributorSchema.Point memory _pt = IVeToken(_ve).userPointHistory(user_, _epoch);
        int128 _balance = _pt.bias - _pt.slope * int128(int256(timestamp_ - _pt.ts));
        if (_balance < 0) {
            return 0;
        } else {
            return uint256(uint128(_balance));
        }
    }

    /**
     * @notice Internal function to update the total supply checkpoint.
     */
    function _checkpointTotalSupply() internal {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        address _ve = $.votingEscrow;
        uint256 _t = $.timeCursor;
        uint256 _roundedTimestamp = (block.timestamp / WEEK) * WEEK;
        IVeToken(_ve).checkpoint();

        uint256 _sinceLastInWeeks;
        if (_t > 0) {
            unchecked {
                _sinceLastInWeeks = (_roundedTimestamp - _t) / WEEK;
            }
        }
        /*
        If the time since the last checkpoint exceeds 20 weeks,
        set the checkpoint time to the beginning of the week that is 19 weeks prior to the current block time.
        */
        if (_sinceLastInWeeks >= 20) {
            _t = (_roundedTimestamp - WEEK * 19);
        }

        /*
        If the last checkpoint total supply time is the previous week,
        update the veSupply to ensure it reflects the latest state.
        This prevents a scenario where checkpointTotalSupply and veToken's createLock
        occur in the same block, potentially causing veSupply to not be updated with the latest value.
        */
        uint256 _previousWeek = $.timeCursor - WEEK;
        if ($.lastCheckpointTotalSupplyTime == _previousWeek) {
            _updateVeSupply($, _ve, _previousWeek);
        }

        for (uint256 i; i < 20;) {
            if (_t > _roundedTimestamp) {
                break;
            } else {
                _updateVeSupply($, _ve, _t);
                _t += WEEK;
            }
            unchecked {
                ++i;
            }
        }
        $.lastCheckpointTotalSupplyTime = block.timestamp;
        $.timeCursor = _t;
    }

    /**
     * @notice Internal function to update veSupply for a given timestamp.
     * @param $ Reference to the storage.
     * @param _ve The address of the veToken contract.
     * @param _timestamp The timestamp to update veSupply for.
     */
    function _updateVeSupply(MultiTokenFeeDistributorSchema.Storage storage $, address _ve, uint256 _timestamp)
        internal
    {
        uint256 _epoch = _findTimestampEpoch(_ve, _timestamp);
        FeeDistributorSchema.Point memory _pt = IVeToken(_ve).pointHistory(_epoch);
        int128 _dt;
        if (_timestamp > _pt.ts) {
            _dt = int128(int256(_timestamp) - int256(_pt.ts));
        }
        $.veSupply[_timestamp] = uint256(int256(_pt.bias - _pt.slope * _dt));
        emit eventVeSupply(_timestamp, $.veSupply[_timestamp]);
    }

    /**
     * @notice External function to update the total veToken supply checkpoints.
     * @dev This function iterates through the time periods since the last checkpoint, updating the total veToken supply at each weekly checkpoint. It is designed to be called externally to ensure the veToken supply is accurately recorded over time. This function plays a critical role in the fee distribution mechanism by ensuring that the veToken supply is up to date, which directly affects the calculation of fee distributions.
     */
    function checkpointTotalSupply() external {
        _checkpointTotalSupply();
    }

    /**
     * @notice Internal function to calculate and distribute claimable tokens for a user.
     * @param userAddress_ The address of the user claiming the tokens.
     * @param tokenAddress_ The address of the token being claimed.
     * @param ve_ The address of the Voting Escrow contract.
     * @param lastTokenTime_ The last time the token was checkpointed.
     * @return uint256 The amount of tokens distributed to the user.
     * @dev This function calculates the amount of tokens a user is entitled to based on their veToken balance over time. It iterates through user epochs and token distribution weeks to calculate the claimable amount. It updates the user's last claim time and epoch to prevent double claiming.
     */
    function _claim(address userAddress_, address tokenAddress_, address ve_, uint256 lastTokenTime_)
        internal
        returns (uint256)
    {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[tokenAddress_];

        // Minimal user_epoch is 0 (if user had no point)
        uint256 _userEpoch;
        uint256 _toDistribute;

        uint256 _maxUserEpoch = IVeToken(ve_).userPointEpoch(userAddress_);
        uint256 _startTime = $token.startTime;

        if (_maxUserEpoch == 0) {
            // No lock = no fees
            return 0;
        }

        uint256 _weekCursor = $token.timeCursorOf[userAddress_];
        if (_weekCursor == 0) {
            // Need to do the initial binary search
            _userEpoch = _findTimestampUserEpoch(ve_, userAddress_, _startTime, _maxUserEpoch);
        } else {
            _userEpoch = $token.userEpochOf[userAddress_];
        }

        if (_userEpoch == 0) {
            _userEpoch = 1;
        }

        FeeDistributorSchema.Point memory _userPoint = IVeToken(ve_).userPointHistory(userAddress_, _userEpoch);

        if (_weekCursor == 0) {
            _weekCursor = ((_userPoint.ts + WEEK - 1) / WEEK) * WEEK;
        }

        if (_weekCursor >= lastTokenTime_) {
            return 0;
        }

        if (_weekCursor < _startTime) {
            _weekCursor = _startTime;
        }

        FeeDistributorSchema.Point memory _oldUserPoint = FeeDistributorSchema.Point({bias: 0, slope: 0, ts: 0, blk: 0});

        // Iterate over weeks
        for (uint256 i; i < 50;) {
            if (_weekCursor >= lastTokenTime_) {
                break;
            } else if (_weekCursor >= _userPoint.ts && _userEpoch <= _maxUserEpoch) {
                ++_userEpoch;
                _oldUserPoint = FeeDistributorSchema.Point({
                    bias: _userPoint.bias,
                    slope: _userPoint.slope,
                    ts: _userPoint.ts,
                    blk: _userPoint.blk
                });
                if (_userEpoch > _maxUserEpoch) {
                    _userPoint = FeeDistributorSchema.Point({bias: 0, slope: 0, ts: 0, blk: 0});
                } else {
                    _userPoint = IVeToken(ve_).userPointHistory(userAddress_, _userEpoch);
                }
            } else {
                int256 _dt = int256(_weekCursor) - int256(_oldUserPoint.ts);
                int256 _balanceOf = int256(_oldUserPoint.bias) - _dt * int256(_oldUserPoint.slope);
                if (_balanceOf < 0) {
                    _balanceOf = 0;
                }

                if (_balanceOf == 0 && _userEpoch > _maxUserEpoch) {
                    break;
                }

                if (_balanceOf > 0 && $.veSupply[_weekCursor] > 0) {
                    emit eventTokensPerWeek(_weekCursor, $token.tokensPerWeek[_weekCursor]);
                    emit eventVeSupply(_weekCursor, $.veSupply[_weekCursor]);
                    emit eventBalance(_weekCursor, uint256(_balanceOf));
                    _toDistribute += (uint256(_balanceOf) * $token.tokensPerWeek[_weekCursor]) / $.veSupply[_weekCursor];
                }
                _weekCursor += WEEK;
            }
            unchecked {
                ++i;
            }
        }

        _userEpoch = Math.min(_maxUserEpoch, _userEpoch - 1);
        $token.userEpochOf[userAddress_] = _userEpoch;
        $token.timeCursorOf[userAddress_] = _weekCursor;

        emit Claimed(userAddress_, tokenAddress_, _toDistribute, _userEpoch, _maxUserEpoch);

        return _toDistribute;
    }

    /**
     * @notice Internal function to perform common checks and state updates before claims.
     * @param tokenAddress_ The address of the token.
     * @return $ Reference to the storage.
     * @return $token Reference to the token data.
     * @return _lastTokenTime The last token time.
     */
    function _updateClaimState(address tokenAddress_)
        internal
        returns (
            MultiTokenFeeDistributorSchema.Storage storage $,
            MultiTokenFeeDistributorSchema.TokenData storage $token,
            uint256 _lastTokenTime
        )
    {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        $ = Storage.MultiTokenFeeDistributor();
        $token = $.tokenData[tokenAddress_];

        require(!$.isKilled, "Contract is killed");

        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        _lastTokenTime = $token.lastTokenTime;

        if ($.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)) {
            _checkpointToken(tokenAddress_);
            _lastTokenTime = block.timestamp;
        }

        unchecked {
            _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        }
    }

    /**
     * @notice Claim fees for `msg.sender`.
     * @dev Each call to claim checks a maximum of 50 user veToken points.
     * @return uint256 Amount of fees claimed in the call.
     */
    function claim(address tokenAddress_) external nonReentrant returns (uint256) {
        address _userAddress = msg.sender;

        (
            MultiTokenFeeDistributorSchema.Storage storage $,
            MultiTokenFeeDistributorSchema.TokenData storage $token,
            uint256 _lastTokenTime
        ) = _updateClaimState(tokenAddress_);

        uint256 _amount = _claim(_userAddress, tokenAddress_, $.votingEscrow, _lastTokenTime);
        if (_amount != 0) {
            require(IERC20(tokenAddress_).transfer(_userAddress, _amount), "Transfer failed");
            $token.tokenLastBalance -= _amount;
        }

        return _amount;
    }

    /**
     * @notice Claim fees for `userAddress_`.
     * @dev Each call to claim checks a maximum of 50 user veToken points.
     * @param userAddress_ Address to claim fees for.
     * @return uint256 Amount of fees claimed in the call.
     */
    function claimFor(address userAddress_, address tokenAddress_) external nonReentrant returns (uint256) {
        (
            MultiTokenFeeDistributorSchema.Storage storage $,
            MultiTokenFeeDistributorSchema.TokenData storage $token,
            uint256 _lastTokenTime
        ) = _updateClaimState(tokenAddress_);

        uint256 _amount = _claim(userAddress_, tokenAddress_, $.votingEscrow, _lastTokenTime);
        if (_amount != 0) {
            require(IERC20(tokenAddress_).transfer(userAddress_, _amount), "Transfer failed");
            $token.tokenLastBalance -= _amount;
        }

        return _amount;
    }

    /**
     * @notice Make multiple fee claims in a single call.
     * @dev Used to claim for many accounts at once.
     * @param receivers_ List of addresses to claim for.
     * @return bool Success.
     */
    function claimMany(address[] memory receivers_, address tokenAddress_) external nonReentrant returns (bool) {
        (
            MultiTokenFeeDistributorSchema.Storage storage $,
            MultiTokenFeeDistributorSchema.TokenData storage $token,
            uint256 _lastTokenTime
        ) = _updateClaimState(tokenAddress_);

        uint256 _total;
        uint256 _l = receivers_.length;
        for (uint256 i; i < _l;) {
            address _userAddress = receivers_[i];
            if (_userAddress == address(0)) {
                break;
            }

            uint256 _amount = _claim(_userAddress, tokenAddress_, $.votingEscrow, _lastTokenTime);
            if (_amount != 0) {
                require(IERC20(tokenAddress_).transfer(_userAddress, _amount), "Transfer failed");
                _total += _amount;
            }
            unchecked {
                ++i;
            }
        }

        if (_total != 0) {
            $token.tokenLastBalance -= _total;
        }

        return true;
    }

    /**
     * @notice Claims fees for multiple tokens for `msg.sender`.
     * @param tokenAddresses_ An array of token addresses for which to claim fees.
     * @return bool Returns true upon success.
     */
    function claimMultipleTokens(address[] calldata tokenAddresses_) external nonReentrant returns (bool) {
        require(tokenAddresses_.length > 0, "No tokens provided");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        require(!$.isKilled, "Contract is killed");

        address userAddress = msg.sender;

        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        for (uint256 i; i < tokenAddresses_.length; ++i) {
            address tokenAddress = tokenAddresses_[i];
            require(_isTokenPresent(tokenAddress), "Token not found");

            MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[tokenAddress];

            uint256 _lastTokenTime = $token.lastTokenTime;

            if ($.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)) {
                _checkpointToken(tokenAddress);
                _lastTokenTime = block.timestamp;
            }

            // Adjust lastTokenTime to the start of the current week
            _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;

            uint256 amount = _claim(userAddress, tokenAddress, $.votingEscrow, _lastTokenTime);
            if (amount > 0) {
                require(IERC20(tokenAddress).transfer(userAddress, amount), "Transfer failed");
                $token.tokenLastBalance -= amount;
            }
        }

        return true;
    }

    /**
     * @notice Allows the burning of tokens to trigger a checkpoint.
     * @param tokenAddress_ The address of the token being burned.
     * @return bool Returns true upon success.
     * @dev This function allows tokens to be burned from the caller's balance to trigger a checkpoint for the token. It checks if the contract is not killed and if the token is present in the list of tokens. If the conditions are met, it transfers the tokens from the caller to the contract and triggers a checkpoint if allowed.
     */
    function burn(address tokenAddress_) external returns (bool) {
        require(_isTokenPresent(tokenAddress_), "Invalid token");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[tokenAddress_];

        require(!$.isKilled, "Contract is killed");

        uint256 _amount = IERC20(tokenAddress_).balanceOf(msg.sender);
        if (_amount > 0) {
            IERC20(tokenAddress_).transferFrom(msg.sender, address(this), _amount);

            if (block.timestamp >= $.timeCursor) {
                _checkpointTotalSupply();
            }

            if ($.canCheckpointToken && block.timestamp > $token.lastTokenTime + 1 hours) {
                _checkpointToken(tokenAddress_);
            }
        }
        return true;
    }

    /**
     * @notice Allows the admin to add a new token to the list of tokens eligible for checkpointing.
     * @param tokenAddress_ The address of the token to be added.
     * @param startTime_ The start time for the token's fee distribution.
     * @dev This function updates the internal list of tokens. It requires the caller to be the admin.
     * The start time is aligned to the beginning of a week based on the constant WEEK.
     */
    function addToken(address tokenAddress_, uint256 startTime_) external onlyAdmin {
        require(!_isTokenPresent(tokenAddress_), "Token already added");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[tokenAddress_];
        uint256 t = (startTime_ / WEEK) * WEEK;
        $token.lastTokenTime = t;
        $token.startTime = t;
        if ($.timeCursor == 0) {
            $.timeCursor = t;
        }
        $.tokens.push(tokenAddress_);
    }

    /**
     * @notice Allows the admin to remove a token from the list of tokens that can be checkpointed.
     * @param tokenAddress_ The address of the token to be removed.
     * @dev This function updates the internal list of tokens. It requires the caller to be the admin and the token to be present in the list.
     */
    function removeToken(address tokenAddress_) external onlyAdmin {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        int256 tokenIndex = -1;
        for (uint256 i; i < $.tokens.length; ++i) {
            if ($.tokens[i] == tokenAddress_) {
                tokenIndex = int256(i);
                break;
            }
        }

        require(tokenIndex != -1, "Token not found");

        // 最後の要素を削除するトークンの位置に移動
        if (uint256(tokenIndex) < $.tokens.length - 1) {
            $.tokens[uint256(tokenIndex)] = $.tokens[$.tokens.length - 1];
        }

        // 配列の最後の要素を削除
        $.tokens.pop();
    }

    /**
     * @notice Commits a new admin address, preparing for the admin transfer.
     * @param addr_ The address of the new admin.
     * @dev This function sets a new future admin address. The change is not applied until `applyAdmin` is called. It requires the caller to be the current admin.
     */
    function commitAdmin(address addr_) external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();

        $.futureAdmin = addr_;
        emit CommitAdmin(addr_);
    }

    /**
     * @notice Applies the admin transfer to the previously committed admin address.
     * @dev This function changes the admin to the previously committed address by `commitAdmin`. It requires the caller to be the current admin.
     */
    function applyAdmin() external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();

        require($.futureAdmin != address(0), "No admin set");
        $.admin = $.futureAdmin;
        emit ApplyAdmin($.futureAdmin);
    }

    /**
     * @notice Toggles the permission for any account to checkpoint tokens.
     * @dev This function toggles the ability for any account to call `checkpointToken`, changing it from admin-only to public or vice versa. It requires the caller to be the admin.
     */
    function toggleAllowCheckpointToken() external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();

        $.canCheckpointToken = !$.canCheckpointToken;
        emit ToggleAllowCheckpointToken($.canCheckpointToken);
    }

    /**
     * @notice Kills the contract, disabling all token claims and transfers.
     * @dev This function disables all functionality of the contract and transfers all tokens to the emergency return address. It can only be called by the admin and cannot be reversed.
     */
    function killMe() external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();

        $.isKilled = true;

        // 全てのトークンのバランスをemergencyReturnに転送
        for (uint256 i; i < $.tokens.length; ++i) {
            address tokenAddress = $.tokens[i];
            uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
            if (balance > 0) {
                require(IERC20(tokenAddress).transfer($.emergencyReturn, balance), "Transfer failed");
            }
        }
    }

    /**
     * @notice Recover ERC20 tokens from this contract.
     * @dev Tokens are sent to the emergency return address.
     * @param tokenAddress_ Token address.
     * @return bool success.
     */
    function recoverBalance(address tokenAddress_) external onlyAdmin returns (bool) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();

        require(_isTokenPresent(tokenAddress_), "Cannot recover this token");

        uint256 _amount = IERC20(tokenAddress_).balanceOf(address(this));
        require(IERC20(tokenAddress_).transfer($.emergencyReturn, _amount), "Transfer failed");
        return true;
    }

    /**
     * @notice Checks if a token is present in the list of tokens that can be checkpointed.
     * @param tokenAddress_ The address of the token to check.
     * @return bool True if the token is present, false otherwise.
     * @dev This function checks the internal list of tokens to see if a token is present. It is used internally and exposed externally for convenience.
     */
    function isTokenPresent(address tokenAddress_) external view returns (bool) {
        return _isTokenPresent(tokenAddress_);
    }

    /**
     * @notice Checks if a token is present in the list of tokens that can be checkpointed.
     * @param tokenAddress_ The address of the token to check.
     * @return bool True if the token is present, false otherwise.
     * @dev This function checks the internal list of tokens to determine if a given token is eligible for checkpointing and fee distribution. It is used to validate token addresses in various functions.
     */
    function _isTokenPresent(address tokenAddress_) internal view returns (bool) {
        require(tokenAddress_ != address(0), "Invalid token address");
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        for (uint256 i; i < $.tokens.length; ++i) {
            if ($.tokens[i] == tokenAddress_) {
                return true;
            }
        }
        return false;
    }

    modifier onlyAdmin() {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();

        require($.admin == msg.sender, "Access denied");
        _;
    }

    /**
     * @notice Returns the start time of the fee distribution.
     * @param tokenAddress_ The address of the token.
     * @return uint256 The epoch time when fee distribution starts.
     * @dev This function returns the start time for the fee distribution process. This is the time from which the contract begins to calculate and distribute fees to token holders.
     */
    function startTime(address tokenAddress_) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress_].startTime;
    }

    /**
     * @notice Returns the current time cursor for fee distribution.
     * @return uint256 The current time cursor.
     * @dev This function returns the current time cursor, indicating the point up to which fees have been distributed. This helps in managing the distribution process over time, ensuring that fees are distributed in chronological order.
     */
    function timeCursor() public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.timeCursor;
    }

    /**
     * @notice Returns the last checkpoint total supply time.
     * @return uint256 The last time the total supply was checkpointed.
     */
    function lastCheckpointTotalSupplyTime() public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.lastCheckpointTotalSupplyTime;
    }

    /**
     * @notice Returns the last token time for a given token.
     * @param tokenAddress_ The address of the token.
     * @return uint256 The last time the token was checkpointed.
     */
    function lastTokenTime(address tokenAddress_) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress_].lastTokenTime;
    }

    /**
     * @notice Returns the last known balance of a token before the last checkpoint.
     * @param tokenAddress_ The address of the token.
     * @return uint256 The token balance at the last checkpoint.
     */
    function tokenLastBalance(address tokenAddress_) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress_].tokenLastBalance;
    }

    /**
     * @notice Checks if the contract allows for tokens to be checkpointed by any account.
     * @return bool True if checkpointing by any account is allowed, false otherwise.
     */
    function canCheckpointToken() public view returns (bool) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.canCheckpointToken;
    }

    /**
     * @notice Checks if the contract is killed.
     * @return bool True if the contract is killed, false otherwise.
     */
    function isKilled() public view returns (bool) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.isKilled;
    }

    /**
     * @notice Returns the address of the Voting Escrow contract.
     * @return address The address of the Voting Escrow contract.
     */
    function votingEscrow() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.votingEscrow;
    }

    /**
     * @notice Returns the list of tokens that can be checkpointed.
     * @return address[] The list of token addresses.
     */
    function tokens() public view returns (address[] memory) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.tokens;
    }

    function admin() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.admin;
    }

    /**
     * @notice Returns the future admin address that will become admin after calling `applyAdmin`.
     * @return address The address set to become the future admin.
     */
    function futureAdmin() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.futureAdmin;
    }

    /**
     * @notice Returns the emergency return address where tokens are sent if the contract is killed.
     * @return address The emergency return address.
     */
    function emergencyReturn() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.emergencyReturn;
    }

    /**
     * @notice Returns the time cursor for a given token and user.
     * @param tokenAddress_ The address of the token.
     * @param user The address of the user.
     * @return uint256 The time cursor of the user for the specified token.
     */
    function timeCursorOf(address tokenAddress_, address user) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress_].timeCursorOf[user];
    }

    /**
     * @notice Returns the user epoch of a given token and user.
     * @param tokenAddress_ The address of the token.
     * @param user The address of the user.
     * @return uint256 The user epoch for the specified token and user.
     */
    function userEpochOf(address tokenAddress_, address user) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress_].userEpochOf[user];
    }

    /**
     * @notice Returns the number of tokens distributed per week for a given token and week.
     * @param tokenAddress_ The address of the token.
     * @param week The week number.
     * @return uint256 The number of tokens distributed for the specified week.
     */
    function tokensPerWeek(address tokenAddress_, uint256 week) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress_].tokensPerWeek[week];
    }

    /**
     * @notice Returns the total veToken supply at a given week.
     * @param week The week number.
     * @return uint256 The total veToken supply for the specified week.
     */
    function veSupply(uint256 week) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage.MultiTokenFeeDistributor();
        return $.veSupply[week];
    }
}
